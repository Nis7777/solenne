import PhotosUI
import SwiftUI

struct JournalView: View {
    enum JournalTab: String, CaseIterable { case gratitude = "Gratitude", manifestations = "Manifestations" }
    @State private var tab: JournalTab = .gratitude

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Journal")
            HStack(spacing: 4) {
                ForEach(JournalTab.allCases, id: \.self) { t in
                    Button { withAnimation(.easeInOut(duration: 0.2)) { tab = t } } label: {
                        Text(t.rawValue)
                            .font(.sans(13.5, .semibold))
                            .foregroundStyle(tab == t ? .white : Palette.ink)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(Capsule().fill(tab == t ? Palette.plum : .clear))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(tab == t ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Capsule().fill(Color.white.opacity(0.6)))
            .padding(.horizontal, 20)
            .padding(.top, 14)

            switch tab {
            case .gratitude: GratitudeTab()
            case .manifestations: ManifestationsTab()
            }
        }
        .solenneBackground()
    }
}

// MARK: - Gratitude

private struct GratitudeTab: View {
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @FocusState private var focused: Bool

    private var todayEntry: GratitudeEntry? {
        model.data.gratitude.first { Day.key($0.date) == Day.key() }
    }

    private var streak: Int {
        let days = Set(model.data.gratitude.map { Day.key($0.date) })
        var cursor = Date.now
        if !days.contains(Day.key(cursor)) { cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor }
        var n = 0
        while days.contains(Day.key(cursor)) {
            n += 1
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return n
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Flame(size: 26, lit: streak > 0)
                    Text(streak == 1 ? "1 day of gratitude" : "\(streak) days of gratitude")
                        .font(.sans(14, .semibold))
                        .foregroundStyle(Palette.ink)
                }
                VStack(alignment: .leading, spacing: 12) {
                    SerifHeading("What are you *grateful* for today?", size: 26, alignment: .leading)
                    TextAreaField(placeholder: "Three small things is plenty…", text: $text)
                        .focused($focused)
                    Button(todayEntry == nil ? "Save today's entry" : "Update today's entry") {
                        save()
                    }
                    .buttonStyle(.primary)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(18)
                .glass(radius: 24, opacity: 0.6)

                if !model.data.gratitude.isEmpty {
                    SectionLabel(title: "History", icon: "clock")
                    ForEach(model.data.gratitude) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            EyebrowLabel(entry.date.formatted(.dateTime.weekday(.wide).month().day()))
                            Text(entry.text).font(.serif(19, relativeTo: .body)).foregroundStyle(Palette.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .glass(radius: 20, opacity: 0.5)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { text = todayEntry?.text ?? "" }
    }

    private func save() {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = model.data.gratitude.firstIndex(where: { Day.key($0.date) == Day.key() }) {
            model.data.gratitude[i].text = clean
        } else {
            model.data.gratitude.insert(GratitudeEntry(text: clean), at: 0)
        }
        focused = false
    }
}

// MARK: - Manifestations

private struct ManifestationsTab: View {
    @Environment(AppModel.self) private var model
    @State private var adding = false
    @State private var celebrating: Manifestation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button { adding = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Palette.rose))
                        VStack(alignment: .leading, spacing: 2) {
                            SerifHeading("What have you *manifested?*", size: 22, alignment: .leading)
                            Text("Big or small, it all counts.").font(.sans(12.5)).foregroundStyle(Palette.inkSoft)
                        }
                        Spacer()
                        Image(systemName: "plus").foregroundStyle(Palette.ink)
                    }
                    .padding(16)
                    .glass(radius: 24, opacity: 0.7)
                }
                .buttonStyle(.plain)

                if model.data.manifestations.isEmpty {
                    Text("Your wall of manifestations will grow here.")
                        .font(.sans(13.5))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    SectionLabel(title: "Wall of manifestations", icon: "sparkle")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        ForEach(model.data.manifestations) { item in
                            Button { celebrating = item } label: {
                                ManifestationTile(item: item)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    model.data.manifestations.removeAll { $0.id == item.id }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $adding) {
            AddManifestationSheet { item in
                model.data.manifestations.insert(item, at: 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { celebrating = item }
            }
        }
        .sheet(item: $celebrating) { item in
            ShareActionsSheet(card: ManifestedCard(item: item), text: "I manifested this ✨ \(item.title)")
        }
    }
}

private func loadImage(_ file: String?) -> UIImage? {
    guard let file else { return nil }
    return UIImage(contentsOfFile: AppModel.imagesDirectory.appending(path: file).path(percentEncoded: false))
}

private struct ManifestationTile: View {
    let item: Manifestation

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .overlay {
                if let image = loadImage(item.imageFile) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    CoverArt(theme: .golden, seed: item.id)
                }
            }
            .overlay(alignment: .bottomLeading) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.serifItalic(18)).foregroundStyle(.white).lineLimit(2)
                        Text(item.date.formatted(.dateTime.month().day().year())).font(.sans(10.5)).foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(12)
                }
            }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// "I manifested this ✨" — the shareable achievement card.
struct ManifestedCard: View {
    let item: Manifestation

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let image = loadImage(item.imageFile) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    CoverArt(theme: .golden, seed: item.id)
                }
            }
            .frame(width: 320, height: 330)
            .clipped()
            VStack(spacing: 10) {
                Text("I manifested this ✨")
                    .font(.serifItalic(30))
                    .foregroundStyle(Palette.ink)
                Text(item.title)
                    .font(.sans(15, .semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Text(item.date.formatted(.dateTime.month(.wide).day().year()).uppercased())
                    .font(.sans(9.5, .semibold))
                    .tracking(2)
                    .foregroundStyle(Palette.inkSoft)
                Text("Solenne").font(.serif(15)).foregroundStyle(Palette.mauve).padding(.top, 4)
            }
            .padding(20)
            .frame(width: 320, height: 190)
            .background(Palette.paper)
        }
        .frame(width: 320, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct AddManifestationSheet: View {
    var onSave: (Manifestation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var note = ""
    @State private var pick: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SheetHeader(title: "What have you\n*manifested?*", subtitle: "Celebrate it. Proof makes the next one easier to believe.")
                PhotosPicker(selection: $pick, matching: .images) {
                    ZStack {
                        if let imageData, let image = UIImage(data: imageData) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus").font(.system(size: 26))
                                Text("Add a photo").font(.sans(13.5, .medium))
                            }
                            .foregroundStyle(Palette.mauve)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.8)))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .onChange(of: pick) { _, item in
                    Task { imageData = try? await item?.loadTransferable(type: Data.self) }
                }
                TextField("The promotion, the apartment, the call…", text: $title)
                    .fieldStyle()
                TextAreaField(placeholder: "How it happened, how it feels…", text: $note, minHeight: 90)
                Button("Add to my wall ✦") { save() }
                    .buttonStyle(.primary)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(24)
        }
        .background(Palette.paper)
    }

    private func save() {
        var file: String?
        if let imageData, let image = UIImage(data: imageData), let jpeg = image.jpegData(compressionQuality: 0.82) {
            let name = "\(UUID().uuidString).jpg"
            try? jpeg.write(to: AppModel.imagesDirectory.appending(path: name))
            file = name
        }
        onSave(Manifestation(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                             note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                             imageFile: file))
        dismiss()
    }
}
