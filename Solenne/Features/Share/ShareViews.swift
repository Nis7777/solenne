import SwiftUI

/// The image people share: a line from the story over its blurred cover.
struct StoryShareCard: View {
    let story: Story

    var body: some View {
        ZStack {
            story.cover.blur(radius: 6).scaleEffect(1.1)
            Color.black.opacity(0.25)
            VStack(spacing: 18) {
                Spacer()
                Text("“\(story.title)”")
                    .font(.serifItalic(34))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Spacer()
                HStack(spacing: 8) {
                    Orb(size: 18, breathing: false)
                    Text("Solenne").font(.serif(18)).foregroundStyle(.white)
                }
                .padding(.bottom, 26)
            }
        }
        .frame(width: 320, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct ShareCardSheet: View {
    let story: Story
    var body: some View {
        ShareActionsSheet(card: StoryShareCard(story: story), link: ShareHelper.link(for: story), text: "“\(story.title)” — my vision on Solenne")
    }
}

/// Preview of a share card plus the share destinations.
struct ShareActionsSheet<Card: View>: View {
    let card: Card
    var link: URL? = nil
    var text: String

    @Environment(\.dismiss) private var dismiss
    @State private var activityItems: [Any]?
    @State private var toast: String?

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Spacer()
                CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
            }
            card
                .shadow(color: Palette.plum.opacity(0.25), radius: 24, y: 12)
                .scaleEffect(0.86)
                .frame(height: 450)
            HStack(alignment: .top, spacing: 18) {
                if let link {
                    action("link", "Copy link") {
                        UIPasteboard.general.string = "\(text)\n\(link.absoluteString)"
                        flash("Link copied")
                    }
                }
                action("camera", "Stories") {
                    guard let image = render() else { return }
                    if !ShareHelper.shareToInstagramStories(image) { activityItems = [image] }
                }
                action("message", "Messages") {
                    activityItems = shareItems()
                }
                action("arrow.down.to.line", "Save image") {
                    guard let image = render() else { return }
                    ShareHelper.saveToPhotos(image)
                    flash("Saved to Photos")
                }
                action("ellipsis", "More") {
                    activityItems = shareItems()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .solenneBackground()
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.sans(13, .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Palette.plum))
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: toast)
        .sheet(isPresented: Binding(get: { activityItems != nil }, set: { if !$0 { activityItems = nil } })) {
            ActivityView(items: activityItems ?? [])
                .presentationDetents([.medium, .large])
        }
    }

    @MainActor
    private func shareItems() -> [Any] {
        var items: [Any] = [text]
        if let image = render() { items.insert(image, at: 0) }
        return items
    }

    @MainActor
    private func render() -> UIImage? {
        ShareHelper.render(card, width: 320)
    }

    private func flash(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { toast = nil }
    }

    private func action(_ icon: String, _ label: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(Color.white.opacity(0.85)))
                Text(label)
                    .font(.sans(11, .medium))
                    .foregroundStyle(Palette.ink)
            }
        }
        .buttonStyle(.plain)
    }
}
