import AVFoundation
import NaturalLanguage
import Observation

enum Narration {
    /// Splits story text into the lines shown karaoke-style in the player.
    static func lines(from text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { sentences.append(s) }
            return true
        }
        // Long sentences read better split at a comma.
        return sentences.flatMap { sentence -> [String] in
            let words = sentence.split(separator: " ")
            guard words.count > 20, let comma = sentence.range(of: ", ", range: sentence.index(sentence.startIndex, offsetBy: sentence.count / 3)..<sentence.endIndex) else {
                return [sentence]
            }
            return [String(sentence[..<comma.lowerBound]) + ",", String(sentence[comma.upperBound...])]
        }
    }

    static let wordsPerSecond = 2.3
    static let linePause: TimeInterval = 0.35

    static func estimatedDuration(of line: String, rateScale: Double = 1) -> TimeInterval {
        let words = Double(line.split(whereSeparator: \.isWhitespace).count)
        return words / (wordsPerSecond * rateScale) + linePause
    }
}

/// Plays a story. Uses the story's narrated audio when it has one, otherwise narrates
/// on device with AVSpeechSynthesizer. Exposes the current line and how much of it
/// has been spoken so the player can render it karaoke-style.
@Observable
final class Narrator {
    let lines: [String]
    private(set) var currentLine = 0
    /// 0...1 — how much of the current line has been spoken.
    private(set) var lineProgress: Double = 0
    private(set) var isPlaying = false
    private(set) var finished = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval
    var ambientOn: Bool {
        didSet { AmbientPlayer.shared.set(on: ambientOn && isPlaying) }
    }
    var onFinish: () -> Void = {}

    @ObservationIgnored private let audioURL: URL?
    @ObservationIgnored private let voice: VoiceOption
    @ObservationIgnored private let replacements: [(String, String)]
    @ObservationIgnored private var lineStarts: [TimeInterval] = []
    @ObservationIgnored private var lineDurations: [TimeInterval] = []
    @ObservationIgnored private var charOffsets: [Int] = []

    // Speech
    @ObservationIgnored private let synth = AVSpeechSynthesizer()
    @ObservationIgnored private let speechDelegate = SpeechDelegate()
    @ObservationIgnored private var utteranceLines: [ObjectIdentifier: Int] = [:]
    @ObservationIgnored private var clockStart: Date?
    @ObservationIgnored private var clockAccum: TimeInterval = 0
    @ObservationIgnored private var ticker: Timer?

    // Audio file
    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?

    init(story: Story, voice: VoiceOption, ambientOn: Bool, pronunciation: (name: String, spoken: String)?) {
        let storyLines = story.lines.isEmpty ? [story.title] : story.lines
        let scale = Double(voice.rate / 0.45)
        let durations = storyLines.map { Narration.estimatedDuration(of: $0, rateScale: scale) }
        var starts: [TimeInterval] = []
        var t: TimeInterval = 0
        for d in durations {
            starts.append(t)
            t += d
        }
        var offsets: [Int] = []
        var c = 0
        for line in storyLines {
            offsets.append(c)
            c += line.count + 1
        }

        lines = storyLines
        lineDurations = durations
        lineStarts = starts
        charOffsets = offsets
        duration = t
        audioURL = story.audioURL
        self.voice = voice
        self.ambientOn = ambientOn
        if let pronunciation, !pronunciation.name.isEmpty, !pronunciation.spoken.isEmpty {
            replacements = [(pronunciation.name, pronunciation.spoken)]
        } else {
            replacements = []
        }

        speechDelegate.owner = self
        synth.delegate = speechDelegate
        if audioURL != nil { setUpPlayer() }
    }

    deinit {
        ticker?.invalidate()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    // MARK: Controls

    func play() {
        AudioSession.activate()
        if finished { seek(to: 0) }
        isPlaying = true
        finished = false
        AmbientPlayer.shared.set(on: ambientOn)

        if let player {
            player.play()
            return
        }
        if synth.isPaused {
            synth.continueSpeaking()
            clockStart = .now
        } else {
            speak(from: currentLine)
        }
        startTicker()
    }

    func pause() {
        isPlaying = false
        AmbientPlayer.shared.set(on: false)
        if let player {
            player.pause()
            return
        }
        synth.pauseSpeaking(at: .word)
        if let start = clockStart { clockAccum += Date.now.timeIntervalSince(start) }
        clockStart = nil
        ticker?.invalidate()
    }

    func toggle() { isPlaying ? pause() : play() }

    func stop() {
        isPlaying = false
        ticker?.invalidate()
        synth.stopSpeaking(at: .immediate)
        player?.pause()
        AmbientPlayer.shared.set(on: false)
    }

    func skip(by seconds: TimeInterval) {
        seek(to: min(max(elapsed + seconds, 0), duration - 0.5))
    }

    func seek(to time: TimeInterval) {
        finished = false
        if let player {
            player.seek(to: CMTime(seconds: time, preferredTimescale: 600))
            elapsed = time
            updateLineFromTime(time)
            return
        }
        let index = lineStarts.lastIndex(where: { $0 <= time }) ?? 0
        currentLine = index
        lineProgress = 0
        elapsed = lineStarts[index]
        clockAccum = 0
        clockStart = isPlaying ? .now : nil
        utteranceLines.removeAll()
        synth.stopSpeaking(at: .immediate)
        if isPlaying { speak(from: index) }
    }

    // MARK: Speech

    private func speak(from index: Int) {
        guard index < lines.count else { return }
        utteranceLines.removeAll()
        let systemVoice = Voices.systemVoice(for: voice)
        for i in index..<lines.count {
            var text = lines[i]
            for (from, to) in replacements {
                text = text.replacingOccurrences(of: from, with: to)
            }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = systemVoice
            utterance.rate = voice.rate
            utterance.pitchMultiplier = voice.pitch
            utterance.postUtteranceDelay = Narration.linePause
            utteranceLines[ObjectIdentifier(utterance)] = i
            synth.speak(utterance)
        }
    }

    fileprivate func didStart(_ utterance: AVSpeechUtterance) {
        guard let i = utteranceLines[ObjectIdentifier(utterance)] else { return }
        currentLine = i
        lineProgress = 0
        clockAccum = 0
        clockStart = .now
    }

    fileprivate func willSpeak(_ range: NSRange, of utterance: AVSpeechUtterance) {
        guard utteranceLines[ObjectIdentifier(utterance)] == currentLine else { return }
        let length = max(1, (utterance.speechString as NSString).length)
        lineProgress = Double(range.location + range.length) / Double(length)
    }

    fileprivate func didFinish(_ utterance: AVSpeechUtterance) {
        guard let i = utteranceLines[ObjectIdentifier(utterance)] else { return }
        lineProgress = 1
        if i == lines.count - 1 { complete() }
    }

    private func complete() {
        isPlaying = false
        finished = true
        elapsed = duration
        ticker?.invalidate()
        AmbientPlayer.shared.set(on: false)
        onFinish()
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying, self.currentLine < self.lineStarts.count else { return }
            let running = self.clockAccum + (self.clockStart.map { Date.now.timeIntervalSince($0) } ?? 0)
            self.elapsed = self.lineStarts[self.currentLine] + min(running, self.lineDurations[self.currentLine])
        }
    }

    // MARK: Audio file

    private func setUpPlayer() {
        guard let audioURL else { return }
        let player = AVPlayer(url: audioURL)
        self.player = player
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self else { return }
            if let d = player.currentItem?.duration.seconds, d.isFinite, d > 0 { self.duration = d }
            self.elapsed = time.seconds
            self.updateLineFromTime(time.seconds)
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { [weak self] _ in
            self?.complete()
        }
    }

    /// With a single audio file we only know the time, so map it onto text proportionally.
    private func updateLineFromTime(_ time: TimeInterval) {
        guard duration > 0, let total = charOffsets.last.map({ $0 + (lines.last?.count ?? 0) }), total > 0 else { return }
        let position = Int(Double(total) * min(time / duration, 1))
        let index = charOffsets.lastIndex(where: { $0 <= position }) ?? 0
        currentLine = index
        lineProgress = Double(position - charOffsets[index]) / Double(max(lines[index].count, 1))
    }
}

/// AVSpeechSynthesizerDelegate needs an NSObject; this forwards events to the Narrator on the main queue.
private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    weak var owner: Narrator?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.owner?.didStart(utterance) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.owner?.willSpeak(characterRange, of: utterance) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.owner?.didFinish(utterance) }
    }
}

enum AudioSession {
    static func activate() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
    }
}

/// Soft looping music bed under the narration.
final class AmbientPlayer {
    static let shared = AmbientPlayer()
    private var player: AVAudioPlayer?
    private let volume: Float = 0.22

    private init() {
        if let url = Bundle.main.url(forResource: "ambient", withExtension: "m4a") {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = 0
            player?.prepareToPlay()
        }
    }

    func set(on: Bool) {
        guard let player else { return }
        if on {
            if !player.isPlaying { player.play() }
            player.setVolume(volume, fadeDuration: 1.2)
        } else if player.isPlaying {
            player.setVolume(0, fadeDuration: 0.6)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
                guard let self, let p = self.player, p.volume == 0 else { return }
                p.pause()
            }
        }
    }
}
