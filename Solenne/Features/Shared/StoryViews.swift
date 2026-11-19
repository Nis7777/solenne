import SwiftUI

/// Tall cover card with an italic title, duration and a play button ("For you" carousel).
struct StoryCard: View {
    @Environment(AppModel.self) private var model
    let story: Story
    var width: CGFloat = 230
    var height: CGFloat = 320

    var body: some View {
        Button { model.play(story) } label: {
            ZStack(alignment: .bottomLeading) {
                story.cover
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 10) {
                    Text(story.title)
                        .font(.serifItalic(22))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    HStack {
                        Text("\(story.minutes) MIN")
                            .font(.sans(10, .semibold))
                            .tracking(1.2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(.black.opacity(0.3)))
                        Spacer()
                        Image(systemName: model.isLocked(story) ? "lock.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(.white))
                    }
                }
                .padding(16)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(alignment: .topTrailing) {
                HeartButton(story: story).padding(12)
            }
            .shadow(color: Palette.plum.opacity(0.18), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { model.sharing = story } label: { Label("Share", systemImage: "square.and.arrow.up") }
            Button { model.toggleFavorite(story) } label: {
                Label(model.isFavorite(story) ? "Remove from favorites" : "Add to favorites", systemImage: "heart")
            }
        }
        .accessibilityLabel("\(story.title), \(story.minutes) minutes")
        .accessibilityHint(model.isLocked(story) ? "Unlock with Pro" : "Plays the story")
    }
}

struct HeartButton: View {
    @Environment(AppModel.self) private var model
    let story: Story
    var dark = false

    var body: some View {
        let liked = model.isFavorite(story)
        Button {
            model.toggleFavorite(story)
        } label: {
            Image(systemName: liked ? "heart.fill" : "heart")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(liked ? Palette.rose : (dark ? .white : Palette.ink))
                .frame(width: 36, height: 36)
                .background(Circle().fill(dark ? Color.white.opacity(0.15) : Color.white.opacity(0.8)))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: liked)
        .accessibilityLabel(liked ? "Remove from favorites" : "Add to favorites")
    }
}

/// Compact row: thumbnail, title, subtitle, play button.
struct StoryRow: View {
    @Environment(AppModel.self) private var model
    let story: Story
    var subtitle: String

    var body: some View {
        Button { model.play(story) } label: {
            HStack(spacing: 14) {
                story.cover
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(story.title)
                        .font(.sans(14.5, .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.sans(12))
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                Image(systemName: model.isLocked(story) ? "lock.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Palette.plum))
            }
            .padding(12)
            .glass(radius: 22, opacity: 0.7)
        }
        .buttonStyle(.plain)
    }
}

/// "Making your stories…" loader with the orb.
struct MakingStoriesView: View {
    var title = "Making your *stories*"
    var subtitle = "your visions are taking shape…"

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Orb(size: 120)
            VStack(spacing: 10) {
                SerifHeading(title, size: 34)
                Text(subtitle)
                    .font(.sans(14))
                    .foregroundStyle(Palette.inkSoft)
            }
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    ShimmerBar(delay: Double(i) * 0.2)
                        .frame(width: CGFloat(240 - i * 40), height: 12)
                }
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .solenneBackground()
    }
}

private struct ShimmerBar: View {
    var delay: Double
    @State private var on = false

    var body: some View {
        Capsule()
            .fill(Color.white.opacity(on ? 0.85 : 0.4))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever().delay(delay)) { on = true }
            }
    }
}

/// Favorites and Recently played.
struct StoryListView: View {
    enum Mode { case favorites, recent }
    @Environment(AppModel.self) private var model
    let mode: Mode

    private var items: [StoryEntry] {
        switch mode {
        case .favorites: model.favoriteEntries
        case .recent: model.recentlyPlayed
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: mode == .favorites ? "Favorites" : "Recently *played*")
            if items.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: mode == .favorites ? "heart" : "clock")
                        .font(.system(size: 28))
                        .foregroundStyle(Palette.mauve)
                    Text(mode == .favorites ? "Tap the heart on any story to keep it here." : "Stories you listen to will show up here.")
                        .font(.sans(14))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { entry in
                            StoryRow(story: entry.story, subtitle: entry.date.formatted(.dateTime.month(.wide).day().year()))
                        }
                    }
                    .padding(20)
                }
            }
        }
        .solenneBackground()
    }
}

/// "See all" for a library row.
struct CollectionView: View {
    let kind: StoryKind

    private var title: String {
        switch kind {
        case .vision: "Trending"
        case .affirmation: "Affirmations"
        case .sleep: "Sleep *tracks*"
        }
    }

    private var stories: [Story] {
        switch kind {
        case .vision: LibraryContent.trending
        case .affirmation: LibraryContent.affirmationTracks
        case .sleep: LibraryContent.sleepTracks
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: title)
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(stories) { story in
                        StoryRow(story: story, subtitle: "\(kind == .affirmation ? "Affirmations" : kind == .sleep ? "Sleep" : "Vision") · \(story.minutes) min")
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .solenneBackground()
    }
}
