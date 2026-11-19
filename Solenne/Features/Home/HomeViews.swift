import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var wish = ""
    @State private var showMaking = false
    @AppStorage("home.hideChallengeBanner") private var hideBanner = false
    @FocusState private var focused: Bool

    private let suggestions = ["$10k months on repeat", "A love that feels easy", "My dream body", "A home by the sea", "Calm, every day"]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                Orb(size: 110)
                    .padding(.top, 8)
                SerifHeading("\(model.data.profile.firstName.isEmpty ? "So" : model.data.profile.firstName), what do you want to *manifest?*", size: 32)
                    .padding(.horizontal, 24)
                manifestField
                challengeCard
                forYouSection
                Button {
                    model.push(.explore)
                } label: {
                    Label("Explore your visions", systemImage: "sparkles")
                }
                .buttonStyle(.secondary)
            }
            .padding(.bottom, 120)
        }
        .scrollDismissesKeyboard(.interactively)
        .solenneBackground()
        .fullScreenCover(isPresented: $showMaking) {
            MakingStoriesView(title: "Calling it *in*", subtitle: "writing a story just for you…")
        }
    }

    private var header: some View {
        HStack {
            Text("Solenne")
                .font(.serif(30))
                .foregroundStyle(Palette.ink)
            Spacer()
            Button {
                model.push(.voices)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                    Text(voiceName).lineLimit(1)
                }
                .font(.sans(12.5, .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Capsule().fill(Color.white.opacity(0.75)))
            }
            .accessibilityLabel("Narrator voice: \(voiceName)")
            Button {
                model.push(model.data.challengeStart == nil ? .challenge : .challengeProgress)
            } label: {
                HStack(spacing: 5) {
                    Flame(size: 15, lit: model.currentStreak > 0)
                    Text("\(model.currentStreak)")
                        .contentTransition(.numericText())
                }
                .font(.sans(12.5, .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Capsule().fill(Color.white.opacity(0.75)))
            }
            .accessibilityLabel("Streak: \(model.currentStreak) days")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var voiceName: String {
        switch model.data.voiceID {
        case Voices.cloneID: "My voice"
        case Voices.personalID: "Personal Voice"
        default: Voices.find(model.data.voiceID)?.name ?? "Solenne"
        }
    }

    private var manifestField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField(suggestions[Calendar.current.component(.day, from: .now) % suggestions.count], text: $wish, axis: .vertical)
                    .font(.serifItalic(19))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1...3)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(submit)
                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Palette.plum))
                }
                .disabled(wish.trimmingCharacters(in: .whitespaces).isEmpty || model.isGenerating)
                .accessibilityLabel("Make a story")
            }
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .glass(radius: 30, opacity: 0.8)
        }
        .padding(.horizontal, 20)
    }

    private func submit() {
        let text = wish
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        focused = false
        guard model.canCreateNow else {
            model.showPaywall = true
            return
        }
        showMaking = true
        Task {
            let started = Date.now
            let story = await model.manifest(text)
            let wait = 2.5 - Date.now.timeIntervalSince(started)
            if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            showMaking = false
            if let story {
                wish = ""
                try? await Task.sleep(nanoseconds: 400_000_000)
                model.play(story)
            }
        }
    }

    @ViewBuilder
    private var challengeCard: some View {
        if model.data.challengeStart != nil {
            Button { model.push(.challengeProgress) } label: {
                HStack(spacing: 14) {
                    Flame(size: 30, lit: model.listenedToday)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day \(model.challengeDay) of 21")
                            .font(.sans(14, .semibold))
                            .foregroundStyle(Palette.ink)
                        Text(model.listenedToday ? "today's flame is lit ✦" : "listen today to keep the flame")
                            .font(.sans(12.5))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Palette.inkFaint)
                }
                .padding(16)
                .glass(radius: 20, opacity: 0.75)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        } else if !hideBanner {
            Button { model.push(.challenge) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkle")
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Palette.rose))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Solenne").font(.sans(13, .semibold))
                            Spacer()
                            Text("now").font(.sans(11)).foregroundStyle(Palette.inkFaint)
                        }
                        Text("the 21-day challenge is waiting for you ✦").font(.sans(13))
                    }
                    .foregroundStyle(Palette.ink)
                    Button {
                        withAnimation { hideBanner = true }
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                    }
                    .accessibilityLabel("Dismiss")
                }
                .padding(14)
                .glass(radius: 20, opacity: 0.85)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
    }

    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { model.push(.forYou) } label: {
                    Text("For you").font(.serif(28)).foregroundStyle(Palette.ink)
                }
                .buttonStyle(.plain)
                Spacer()
                Button { model.push(.desires) } label: {
                    Label("Edit desires", systemImage: "pencil")
                }
                .buttonStyle(.secondary)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if model.forYou.isEmpty {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 26)
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 230, height: 320)
                                .overlay { if model.isGenerating { ProgressView() } }
                        }
                    } else {
                        ForEach(model.forYou) { story in
                            StoryCard(story: story)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
        }
    }
}

// MARK: - For you

struct ForYouView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "For you") {
                Button { model.push(.desires) } label: { Label("Edit desires", systemImage: "pencil") }
                    .buttonStyle(.secondary)
            }
            TabView {
                ForEach(model.forYou) { story in
                    StoryCard(story: story, width: 280, height: 400)
                        .padding(.vertical, 20)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 470)
            .padding(.top, 20)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let next = Day.nextMidnight(after: context.date)
                let remaining = max(0, Int(next.timeIntervalSince(context.date)))
                let dayFraction = 1 - Double(remaining) / 86_400
                VStack(spacing: 12) {
                    EyebrowLabel("Daily refresh in")
                    Text(String(format: "%02d:%02d:%02d", remaining / 3600, (remaining % 3600) / 60, remaining % 60))
                        .font(.serif(46))
                        .tracking(6)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                    ThinProgressBar(value: dayFraction)
                        .frame(width: 230)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.top, 16)
            Spacer()
        }
        .solenneBackground()
    }
}

// MARK: - Explore

struct ExploreView: View {
    @Environment(AppModel.self) private var model
    @State private var page = 0

    private var visions: [Story] {
        let mine = model.data.stories.filter { $0.kind == .vision }
        return Array((mine + LibraryContent.trending).prefix(12))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader()
            Orb(size: 70).padding(.top, 8)
            SerifHeading("Swipe to the vision\nyou want to *step into…*", size: 28)
                .padding(.top, 18)
            TabView(selection: $page) {
                ForEach(Array(visions.enumerated()), id: \.element.id) { index, story in
                    VisionCard(story: story)
                        .padding(.horizontal, 40)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 380)
            .padding(.top, 24)

            HStack(spacing: 6) {
                ForEach(0..<min(visions.count, 8), id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Palette.plum : Palette.plum.opacity(0.25))
                        .frame(width: i == page ? 18 : 6, height: 6)
                }
            }
            .animation(.easeInOut, value: page)
            .padding(.top, 10)
            Text("‹  SWIPE  ›")
                .font(.sans(10, .semibold))
                .tracking(2)
                .foregroundStyle(Palette.inkFaint)
                .padding(.top, 10)
            Spacer()
        }
        .solenneBackground()
    }
}

private struct VisionCard: View {
    @Environment(AppModel.self) private var model
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            story.cover
                .frame(height: 170)
                .overlay(alignment: .topLeading) {
                    Text("VISION · \(story.minutes) MIN")
                        .font(.sans(9.5, .semibold))
                        .tracking(1.5)
                        .foregroundStyle(.white)
                        .padding(14)
                }
            VStack(alignment: .leading, spacing: 18) {
                Text(story.title)
                    .font(.sans(17, .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(3)
                Spacer(minLength: 0)
                Button { model.play(story) } label: {
                    Image(systemName: model.isLocked(story) ? "lock.fill" : "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(Circle().fill(Palette.mauve))
                }
                .accessibilityLabel("Play \(story.title)")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.paper)
        }
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Palette.plum.opacity(0.15), radius: 18, y: 10)
    }
}

// MARK: - Library

struct LibraryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("Library")
                    .font(.serif(34))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(LibraryContent.trending) { story in
                            LibraryHeroCard(story: story)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                shelf("Affirmations", kind: .affirmation, stories: LibraryContent.affirmationTracks)
                shelf("Sleep tracks", kind: .sleep, stories: LibraryContent.sleepTracks)
                if !model.data.stories.isEmpty {
                    shelf("Your stories", kind: nil, stories: Array(model.data.stories.prefix(10)))
                }
            }
            .padding(.bottom, 120)
        }
        .solenneBackground()
    }

    private func shelf(_ title: String, kind: StoryKind?, stories: [Story]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EyebrowLabel(title)
                Spacer()
                if let kind {
                    Button("See all") { model.push(.collection(kind)) }
                        .font(.sans(12, .medium))
                        .foregroundStyle(Palette.ink)
                }
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stories) { story in
                        StoryCard(story: story, width: 170, height: 230)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
        }
    }
}

private struct LibraryHeroCard: View {
    @Environment(AppModel.self) private var model
    let story: Story

    var body: some View {
        Button { model.play(story) } label: {
            ZStack(alignment: .bottomLeading) {
                story.cover
                LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    EyebrowLabel("Trending", color: .white.opacity(0.85))
                    Text(story.title)
                        .font(.serifItalic(26))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    HStack {
                        Text("\(story.minutes) MIN").font(.sans(10, .semibold)).tracking(1.2).foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "play.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(.white))
                    }
                }
                .padding(18)
            }
            .frame(width: 310, height: 340)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Palette.plum.opacity(0.18), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
    }
}
