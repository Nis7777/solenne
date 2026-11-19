import SwiftUI

struct PlayerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let story: Story

    @State private var narrator: Narrator?
    @State private var introProgress: Double = 0
    @State private var inIntro = true
    @State private var loop = false
    @State private var showFeedback = false
    @State private var showReading = false
    @State private var showShare = false
    @State private var scrubbing: Double?
    @State private var listened = false

    var body: some View {
        ZStack {
            background
            if inIntro {
                intro
                    .transition(.opacity)
            } else if let narrator {
                content(narrator)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: inIntro)
        .task { await start() }
        .onDisappear { narrator?.stop() }
        .sheet(isPresented: $showFeedback) {
            FeedbackSheet(title: "Something sound *off?*",
                          subtitle: "Tell Solenne what to change in your future stories so they feel more like you.",
                          placeholder: "e.g. Don't mention iced lattes",
                          button: "Send to Solenne")
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showReading) {
            ReadingView(story: story)
        }
        .sheet(isPresented: $showShare) {
            ShareCardSheet(story: story)
        }
    }

    private var background: some View {
        ZStack {
            story.cover
                .scaleEffect(1.3)
                .blur(radius: 26)
            Color.black.opacity(0.42)
        }
        .ignoresSafeArea()
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading) {
            HStack {
                Spacer()
                CircleIconButton(systemName: "xmark", label: "Close", dark: true) { dismiss() }
            }
            Spacer()
            Text(story.lines.first ?? story.title)
                .font(.serif(38))
                .foregroundStyle(.white)
                .lineSpacing(2)
            Spacer()
            HStack {
                Text(introCaption)
                    .font(.sans(12))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(Int(introProgress * 100))%")
                    .font(.sans(12, .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.8))
            }
            ThinProgressBar(value: introProgress, tint: Color(hex: 0xF4C6D5))
        }
        .padding(24)
    }

    private var introCaption: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let moment = hour < 12 ? "this morning's" : hour < 18 ? "today's" : "tonight's"
        return "Stepping into \(moment) story…"
    }

    private func start() async {
        let voice = Voices.onDevice(for: model.data.voiceID)
        let pronunciation = model.data.namePronunciation.isEmpty ? nil
            : (name: model.data.profile.firstName, spoken: model.data.namePronunciation)
        let n = Narrator(story: story, voice: voice, ambientOn: model.data.ambientOn, pronunciation: pronunciation)
        n.onFinish = { [weak n] in
            markListened()
            if loop, let n {
                n.seek(to: 0)
                n.play()
            }
        }
        narrator = n
        AudioSession.activate()
        AmbientPlayer.shared.set(on: model.data.ambientOn)
        for step in 1...25 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            introProgress = Double(step) / 25
        }
        inIntro = false
        n.play()
    }

    private func markListened() {
        guard !listened else { return }
        listened = true
        model.recordListen(story)
    }

    // MARK: Player

    private func content(_ narrator: Narrator) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                CircleIconButton(systemName: "chevron.down", label: "Close", dark: true) { dismiss() }
                Spacer()
                Text("Solenne").font(.serifItalic(24)).foregroundStyle(.white)
                Spacer()
                CircleIconButton(systemName: "slider.horizontal.3", label: "Something sound off?", dark: true) { showFeedback = true }
            }

            Spacer()
            KaraokeLine(text: narrator.lines[narrator.currentLine], progress: narrator.lineProgress)
                .id(narrator.currentLine)
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 12)), removal: .opacity))
                .animation(.easeOut(duration: 0.4), value: narrator.currentLine)
            Spacer()

            Button { showReading = true } label: {
                Label("Read the full story", systemImage: "book")
                    .font(.sans(12.5, .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
            }
            .padding(.bottom, 18)

            HStack(spacing: 12) {
                TranscriptStrip(lines: narrator.lines, current: narrator.currentLine)
                Button { loop.toggle() } label: {
                    Image(systemName: "repeat")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(loop ? Palette.ink : .white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(loop ? Color.white : Color.white.opacity(0.15)))
                }
                .accessibilityLabel(loop ? "Repeat on" : "Repeat off")
            }
            .padding(.bottom, 18)

            scrubber(narrator)

            HStack {
                HeartButton(story: story, dark: true)
                Spacer()
                Button { narrator.skip(by: -10) } label: {
                    Image(systemName: "gobackward.10").font(.system(size: 24))
                }
                .accessibilityLabel("Back 10 seconds")
                Spacer()
                Button { narrator.toggle() } label: {
                    Image(systemName: narrator.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(.white))
                }
                .accessibilityLabel(narrator.isPlaying ? "Pause" : "Play")
                Spacer()
                Button { narrator.skip(by: 10) } label: {
                    Image(systemName: "goforward.10").font(.system(size: 24))
                }
                .accessibilityLabel("Forward 10 seconds")
                Spacer()
                Button {
                    model.data.ambientOn.toggle()
                    narrator.ambientOn = model.data.ambientOn
                } label: {
                    Image(systemName: model.data.ambientOn ? "music.note" : "speaker.slash")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel(model.data.ambientOn ? "Background music on" : "Background music off")
            }
            .foregroundStyle(.white)
            .padding(.top, 14)

            Button { showShare = true } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.sans(13.5, .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 42)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .onChange(of: narrator.elapsed) { _, elapsed in
            // Counts as a listen once most of the story has played.
            if narrator.duration > 0, elapsed / narrator.duration > 0.6 { markListened() }
        }
    }

    private func scrubber(_ narrator: Narrator) -> some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { scrubbing ?? narrator.elapsed },
                    set: { scrubbing = $0 }
                ),
                in: 0...max(narrator.duration, 1),
                onEditingChanged: { editing in
                    if !editing, let target = scrubbing {
                        narrator.seek(to: target)
                        scrubbing = nil
                    }
                }
            )
            .tint(.white)
            HStack {
                Text(format(scrubbing ?? narrator.elapsed))
                Spacer()
                Text("-" + format(max(0, narrator.duration - (scrubbing ?? narrator.elapsed))))
            }
            .font(.sans(11, .medium))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.75))
        }
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

/// The current sentence in large serif type; words already spoken are bright.
private struct KaraokeLine: View {
    let text: String
    let progress: Double

    var body: some View {
        Text(attributed)
            .font(.serif(34))
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeOut(duration: 0.2), value: progress)
            .accessibilityLabel(text)
    }

    private var attributed: AttributedString {
        // Snap the split to a word boundary.
        var cut = Int(Double(text.count) * min(max(progress, 0), 1))
        let chars = Array(text)
        while cut < chars.count && chars[cut] != " " && cut > 0 { cut += 1 }
        var spoken = AttributedString(String(chars.prefix(cut)))
        spoken.foregroundColor = .white
        var rest = AttributedString(String(chars.dropFirst(cut)))
        rest.foregroundColor = .white.opacity(0.45)
        return spoken + rest
    }
}

private struct TranscriptStrip: View {
    let lines: [String]
    let current: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(lines.indices, id: \.self) { i in
                        Text(lines[i])
                            .font(.serif(17))
                            .foregroundStyle(.white.opacity(i == current ? 0.95 : 0.4))
                            .lineLimit(1)
                            .id(i)
                    }
                }
            }
            .mask(LinearGradient(colors: [.clear, .black, .black, .clear], startPoint: .leading, endPoint: .trailing))
            .onChange(of: current) { _, i in
                withAnimation(.easeInOut(duration: 0.6)) { proxy.scrollTo(i, anchor: .leading) }
            }
        }
        .frame(height: 28)
        .accessibilityHidden(true)
    }
}

// MARK: - Reading view

struct ReadingView: View {
    @Environment(AppModel.self) private var model
    let story: Story

    private var bookmarked: Bool { model.data.bookmarks.contains(story.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                story.cover
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text(story.title)
                    .font(.serifItalic(30))
                    .foregroundStyle(Palette.ink)
                Rectangle().fill(Color(hex: 0xC9A27A)).frame(width: 36, height: 1.5)
                ForEach(Array(story.text.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(.serif(19, relativeTo: .body))
                        .foregroundStyle(Palette.ink.opacity(0.85))
                        .lineSpacing(5)
                }
            }
            .padding(24)
            .padding(.top, 20)
        }
        .background(Color(hex: 0xEFE6E2))
        .overlay(alignment: .topTrailing) {
            Button {
                if bookmarked { model.data.bookmarks.remove(story.id) } else { model.data.bookmarks.insert(story.id) }
            } label: {
                Image(systemName: bookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Palette.ink))
            }
            .padding(16)
            .accessibilityLabel(bookmarked ? "Remove bookmark" : "Bookmark")
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Feedback sheet (shared by player + profile)

struct FeedbackSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let title: String
    let subtitle: String
    let placeholder: String
    let button: String
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SheetHeader(title: title, subtitle: subtitle)
            TextAreaField(placeholder: placeholder, text: $text)
            Button {
                model.data.profile.notes.append(text.trimmingCharacters(in: .whitespacesAndNewlines))
                dismiss()
            } label: {
                Label(button, systemImage: "sparkle")
            }
            .buttonStyle(.mauve)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Spacer(minLength: 0)
        }
        .padding(24)
        .background(Palette.paper)
    }
}
