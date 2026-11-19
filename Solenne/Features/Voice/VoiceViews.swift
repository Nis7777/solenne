import SwiftUI

struct VoicesView: View {
    @Environment(AppModel.self) private var model
    @State private var personalVoiceDenied = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Choose your *narrator*")
            ScrollView {
                VStack(spacing: 10) {
                    cloneCard
                    if let cloned = model.data.clonedVoice {
                        voiceRow(id: Voices.cloneID, name: "My voice",
                                 blurb: cloned.remoteVoiceID == nil ? "saved · narrates once the voice service is connected" : "cloned from your sample") {
                            VoicePreviewer.shared.play(url: URL.documentsDirectory.appending(path: cloned.sampleFile))
                        }
                    }
                    voiceRow(id: Voices.personalID, name: "My Personal Voice",
                             blurb: "the Personal Voice you made in iOS Settings, on device") {
                        VoicePreviewer.shared.preview(Voices.onDevice(for: Voices.personalID), name: model.data.profile.firstName)
                    }
                    EyebrowLabel("Curated voices")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 14)
                    ForEach(Voices.all) { voice in
                        voiceRow(id: voice.id, name: voice.name, blurb: voice.blurb) {
                            VoicePreviewer.shared.preview(voice, name: model.data.profile.firstName)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .solenneBackground()
        .onDisappear { VoicePreviewer.shared.stop() }
        .alert("Personal Voice isn't available", isPresented: $personalVoiceDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Create a Personal Voice in Settings → Accessibility → Personal Voice, and allow Solenne to use it.")
        }
    }

    private var cloneCard: some View {
        Button {
            if model.isPro { model.push(.voiceClone) } else { model.showPaywall = true }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Orb(size: 54, breathing: false)
                    Image(systemName: "mic.fill").foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Clone your own voice").font(.sans(15.5, .semibold))
                        if !model.isPro {
                            Text("PRO").font(.sans(9, .bold)).tracking(1)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Palette.rose)).foregroundStyle(.white)
                        }
                    }
                    Text("Hear your future told in your own voice.")
                        .font(.sans(12.5))
                        .foregroundStyle(Palette.inkSoft)
                }
                .foregroundStyle(Palette.ink)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Palette.inkFaint)
            }
            .padding(16)
            .glass(radius: 24, opacity: 0.8)
        }
        .buttonStyle(.plain)
    }

    private func voiceRow(id: String, name: String, blurb: String, preview: @escaping () -> Void) -> some View {
        let selected = model.data.voiceID == id
        return HStack(spacing: 14) {
            Button(action: preview) {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.plum)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white))
            }
            .accessibilityLabel("Preview \(name)")
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.sans(15, .semibold)).foregroundStyle(Palette.ink)
                Text(blurb).font(.sans(12)).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(selected ? Palette.plum : Palette.inkFaint)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(selected ? 0.85 : 0.55)))
        .contentShape(Rectangle())
        .onTapGesture { select(id) }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private func select(_ id: String) {
        guard id == Voices.personalID else {
            model.data.voiceID = id
            return
        }
        Task {
            if await Voices.requestPersonalVoice(), Voices.systemVoice(for: Voices.onDevice(for: id)) != nil {
                model.data.voiceID = id
            } else {
                personalVoiceDenied = true
            }
        }
    }
}

// MARK: - Voice cloning

struct VoiceCloneView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    enum Stage { case intro, tips, record, review, uploading, ready }
    static let maxAttempts = 3

    @State private var stage: Stage = .intro
    @State private var recorder = VoiceRecorder()
    @State private var micDenied = false
    @State private var errorText: String?

    private var attemptsLeft: Int { max(0, Self.maxAttempts - model.data.cloneAttempts) }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader()
            Group {
                switch stage {
                case .intro: intro
                case .tips: tips
                case .record: record
                case .review: review
                case .uploading: MakingStoriesView(title: "Learning your *voice*", subtitle: "this takes a few seconds…")
                case .ready: ready
                }
            }
            .frame(maxHeight: .infinity)
            .transition(.opacity)
        }
        .animation(.easeInOut, value: stage)
        .solenneBackground()
        .onDisappear { VoicePreviewer.shared.stop() }
        .alert("Microphone is off", isPresented: $micDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Allow microphone access for Solenne to record your voice sample.")
        }
    }

    private var intro: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Orb(size: 130)
                Image(systemName: "mic.fill").font(.system(size: 34)).foregroundStyle(.white)
            }
            SerifHeading("Hear your future in\n*your own voice*", size: 34)
            Text("Record about 10 seconds. Solenne learns how you sound and narrates your stories with it.")
                .font(.sans(14.5))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Spacer()
            Button("Allow microphone") {
                Task {
                    if await VoiceRecorder.requestPermission() { stage = .tips } else { micDenied = true }
                }
            }
            .buttonStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 18) {
            SerifHeading("A few *tips*", size: 34, alignment: .leading)
                .padding(.top, 20)
            tip("speaker.slash", "Find a quiet room with no music or echo.")
            tip("iphone", "Hold your phone about a hand's length from your mouth.")
            tip("face.smiling", "Speak warmly, like you're sharing good news with a friend.")
            tip("text.quote", "Read the short passage on the next screen, at your natural pace.")
            Spacer()
            Button("I'm ready") { stage = .record }
                .buttonStyle(.primary)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Palette.plum)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.8)))
            Text(text).font(.sans(14.5)).foregroundStyle(Palette.ink)
        }
    }

    private var record: some View {
        VStack(spacing: 26) {
            EyebrowLabel("Read this aloud")
                .padding(.top, 16)
            Text("“I wake up slowly, sunlight warm across my face. Everything I asked for is here. I feel calm, I feel proud, and I am so grateful for this life.”")
                .font(.serifItalic(25))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
            LevelBars(level: recorder.level, active: recorder.isRecording)
                .frame(height: 50)
            ZStack {
                Circle().stroke(Palette.mauve.opacity(0.25), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: recorder.elapsed / VoiceRecorder.sampleSeconds)
                    .stroke(Palette.plum, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: recorder.elapsed)
                Button {
                    recorder.isRecording ? recorder.stop() : recorder.start()
                } label: {
                    RoundedRectangle(cornerRadius: recorder.isRecording ? 10 : 40)
                        .fill(Palette.rose)
                        .frame(width: recorder.isRecording ? 36 : 70, height: recorder.isRecording ? 36 : 70)
                        .animation(.spring(duration: 0.3), value: recorder.isRecording)
                }
                .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")
            }
            .frame(width: 96, height: 96)
            Text(recorder.isRecording ? String(format: "0:%02d / 0:10", Int(recorder.elapsed)) : "tap to record")
                .font(.sans(12.5, .medium))
                .monospacedDigit()
                .foregroundStyle(Palette.inkSoft)
                .padding(.bottom, 24)
        }
        .onChange(of: recorder.isRecording) { _, isRecording in
            if !isRecording, recorder.recordingURL != nil {
                model.data.cloneAttempts += 1
                stage = .review
            }
        }
    }

    private var review: some View {
        VStack(spacing: 20) {
            Spacer()
            SerifHeading("How does it *sound?*", size: 34)
            Button {
                if let url = recorder.recordingURL { VoicePreviewer.shared.play(url: url) }
            } label: {
                Label("Play my sample", systemImage: "play.fill")
            }
            .buttonStyle(.secondary)
            if let errorText {
                Text(errorText).font(.sans(12.5)).foregroundStyle(.red).multilineTextAlignment(.center).padding(.horizontal, 30)
            }
            Spacer()
            Button("Sounds like me") { Task { await upload() } }
                .buttonStyle(.primary)
            if attemptsLeft > 0 {
                Button("Record again (\(attemptsLeft) left)") {
                    VoicePreviewer.shared.stop()
                    stage = .record
                }
                .font(.sans(13.5, .medium))
                .foregroundStyle(Palette.inkSoft)
                .padding(.vertical, 12)
            } else {
                Text("That was your last attempt for now.")
                    .font(.sans(12.5))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 24)
    }

    private func upload() async {
        guard let url = recorder.recordingURL else { return }
        VoicePreviewer.shared.stop()
        // Keep a copy of the sample in Documents.
        let fileName = "my-voice-\(UUID().uuidString.prefix(8)).m4a"
        let saved = URL.documentsDirectory.appending(path: fileName)
        try? FileManager.default.copyItem(at: url, to: saved)

        var remoteID: String?
        if Backend.isConfigured {
            stage = .uploading
            do {
                remoteID = try await Backend.cloneVoice(sample: saved, name: model.data.profile.firstName.isEmpty ? "Solenne listener" : model.data.profile.firstName)
            } catch {
                errorText = "We couldn't clone your voice just now. \(error.localizedDescription)"
                stage = .review
                return
            }
        }
        model.data.clonedVoice = ClonedVoice(sampleFile: fileName, remoteVoiceID: remoteID)
        model.data.voiceID = Voices.cloneID
        stage = .ready
    }

    private var ready: some View {
        VStack(spacing: 22) {
            Spacer()
            Orb(size: 120)
            SerifHeading("Your voice is *ready*", size: 34)
            Text(model.data.clonedVoice?.remoteVoiceID == nil
                 ? "Your sample is saved. Stories will be narrated in your voice as soon as the voice service is connected."
                 : "From now on, your stories will be told in your own voice.")
                .font(.sans(14.5))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            if let file = model.data.clonedVoice?.sampleFile {
                Button {
                    VoicePreviewer.shared.play(url: URL.documentsDirectory.appending(path: file))
                } label: { Label("Hear it", systemImage: "play.fill") }
                    .buttonStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct LevelBars: View {
    let level: Double
    let active: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<24, id: \.self) { i in
                let wave = abs(sin(Double(i) * 0.7)) * 0.6 + 0.4
                Capsule()
                    .fill(Palette.plum.opacity(active ? 0.8 : 0.25))
                    .frame(width: 4, height: max(4, 50 * (active ? level * wave : 0.1)))
            }
        }
        .animation(.easeOut(duration: 0.08), value: level)
        .accessibilityHidden(true)
    }
}
