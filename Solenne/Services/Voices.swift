import AVFoundation

struct VoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let blurb: String
    /// ElevenLabs voice used when stories are narrated by the backend.
    /// Replace with the voices you pick in your ElevenLabs library.
    let elevenLabsID: String
    // On-device fallback (AVSpeechSynthesizer)
    let language: String
    let gender: AVSpeechSynthesisVoiceGender
    let pitch: Float
    let rate: Float
}

enum Voices {
    static let cloneID = "my-voice"
    static let personalID = "personal-voice"

    static let all: [VoiceOption] = [
        VoiceOption(id: "solenne", name: "Solenne", blurb: "warm, unhurried, close", elevenLabsID: "EXAVITQu4vr4xnSDxMaL",
                    language: "en-US", gender: .female, pitch: 1.0, rate: 0.44),
        VoiceOption(id: "maeve", name: "Maeve", blurb: "soft Irish lilt", elevenLabsID: "XrExE9yKIg1WjnnlVkGX",
                    language: "en-IE", gender: .female, pitch: 1.02, rate: 0.45),
        VoiceOption(id: "isla", name: "Isla", blurb: "bright and encouraging", elevenLabsID: "pFZP5JQG7iQjIQuC4Bku",
                    language: "en-GB", gender: .female, pitch: 1.08, rate: 0.47),
        VoiceOption(id: "noor", name: "Noor", blurb: "low, velvety, calm", elevenLabsID: "XB0fDUnXU5powFXDhCwa",
                    language: "en-AU", gender: .female, pitch: 0.92, rate: 0.43),
        VoiceOption(id: "theo", name: "Theo", blurb: "grounded and gentle", elevenLabsID: "onwK4e9ZLuTAKqWW03F9",
                    language: "en-GB", gender: .male, pitch: 0.95, rate: 0.44),
        VoiceOption(id: "river", name: "River", blurb: "easygoing, warm", elevenLabsID: "TX3LPaxmHKxFdv7VOQHJ",
                    language: "en-US", gender: .male, pitch: 1.0, rate: 0.46),
        VoiceOption(id: "dusk", name: "Dusk", blurb: "slow, made for bedtime", elevenLabsID: "N2lVS1w4EtoT3dr4eOWO",
                    language: "en-US", gender: .male, pitch: 0.88, rate: 0.40),
    ]

    static func find(_ id: String) -> VoiceOption? {
        all.first { $0.id == id }
    }

    /// The option used to narrate on device for the user's current choice.
    static func onDevice(for id: String) -> VoiceOption {
        if id == personalID {
            return VoiceOption(id: personalID, name: "My Personal Voice", blurb: "", elevenLabsID: "",
                               language: "", gender: .unspecified, pitch: 1, rate: 0.46)
        }
        return find(id) ?? all[0]
    }

    /// Picks the best installed system voice for an option (enhanced / premium first).
    static func systemVoice(for option: VoiceOption) -> AVSpeechSynthesisVoice? {
        let installed = AVSpeechSynthesisVoice.speechVoices()
        if option.id == personalID {
            return installed.first { $0.voiceTraits.contains(.isPersonalVoice) }
        }
        let usable = installed.filter {
            !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice)
        }
        let sameLanguage = usable.filter { $0.language == option.language }
        let pool = sameLanguage.isEmpty ? usable.filter { $0.language.hasPrefix("en") } : sameLanguage
        let gendered = pool.filter { $0.gender == option.gender }
        let candidates = gendered.isEmpty ? pool : gendered
        return candidates.max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: option.language)
    }

    static func requestPersonalVoice() async -> Bool {
        await withCheckedContinuation { continuation in
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

/// Speaks a short preview line with a voice option.
final class VoicePreviewer {
    static let shared = VoicePreviewer()
    private let synth = AVSpeechSynthesizer()

    func preview(_ option: VoiceOption, name: String) {
        AudioSession.activate()
        synth.stopSpeaking(at: .immediate)
        let greeting = name.isEmpty ? "" : "\(name), "
        let utterance = AVSpeechUtterance(string: "\(greeting)close your eyes. Your new life is already unfolding.")
        utterance.voice = Voices.systemVoice(for: option)
        utterance.rate = option.rate
        utterance.pitchMultiplier = option.pitch
        synth.speak(utterance)
    }

    func play(url: URL) {
        AudioSession.activate()
        synth.stopSpeaking(at: .immediate)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        player?.stop()
    }

    private var player: AVAudioPlayer?
}
