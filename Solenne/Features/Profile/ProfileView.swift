import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var model

    private struct EditTarget: Identifiable {
        let title: String
        let key: WritableKeyPath<Profile, String>
        var id: String { title }
    }

    private enum ListTarget: String, Identifiable {
        case lifestyle, never
        var id: String { rawValue }
    }

    @State private var editing: EditTarget?
    @State private var draft = ""
    @State private var addingPerson = false
    @State private var addingKid = false
    @State private var addingTag: ListTarget?
    @State private var tagDraft = ""
    @State private var showFeedback = false
    @State private var refreshingTags = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                section("My library") {
                    navRow("Favorites") { model.push(.favorites) }
                    divider
                    navRow("Recently played") { model.push(.recent) }
                    divider
                    navRow("My desires") { model.push(.desires) }
                }
                section("The basics") {
                    basicRow("Name", \.name)
                    divider
                    basicRow("Age", \.age)
                    divider
                    basicRow("City", \.city)
                    divider
                    basicRow("Career", \.work)
                    divider
                    basicRow("Gender", \.gender)
                    divider
                    basicRow("Sexuality", \.sexuality)
                }
                peopleSection(title: "My people", icon: "heart", people: \.people, empty: "Add the people who matter most to you.", addLabel: "Add person") {
                    addingPerson = true
                }
                peopleSection(title: "My kids", icon: "figure.and.child.holdinghands", people: \.kids, empty: "Add your children to personalize your stories.", addLabel: "Add child") {
                    addingKid = true
                }
                tagSection(title: "My lifestyle", icon: "circle.lefthalf.filled", values: model.data.profile.lifestyleTags, target: .lifestyle, refresh: true)
                tagSection(title: "Never include", icon: "xmark", values: model.data.profile.neverInclude, target: .never, refresh: false)
                section("Archive", icon: "archivebox") {
                    navRow("Gratitude & manifestations") { model.push(.journal) }
                    divider
                    navRow("21-day challenge") { model.push(model.data.challengeStart == nil ? .challenge : .challengeProgress) }
                    divider
                    navRow("Daily reminder") { model.push(.reminders) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 130)
        }
        .solenneBackground()
        .overlay(alignment: .bottomTrailing) {
            Button { showFeedback = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Palette.mauve))
                    .shadow(color: Palette.plum.opacity(0.3), radius: 12, y: 6)
            }
            .padding(.trailing, 22)
            .padding(.bottom, 96)
            .accessibilityLabel("Tell Solenne something")
        }
        .alert(editing?.title ?? "", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField(editing?.title ?? "", text: $draft)
            Button("Save") {
                if let editing { model.data.profile[keyPath: editing.key] = draft.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(addingTag == .never ? "Never include" : "Add to my lifestyle", isPresented: Binding(get: { addingTag != nil }, set: { if !$0 { addingTag = nil } })) {
            TextField(addingTag == .never ? "e.g. iced lattes, my ex" : "e.g. Dog lover", text: $tagDraft)
            Button("Add") {
                let value = tagDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return }
                if addingTag == .never { model.data.profile.neverInclude.append(value) } else { model.data.profile.lifestyleTags.append(value) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if addingTag == .never { Text("Solenne will leave this out of every story.") }
        }
        .sheet(isPresented: $addingPerson) {
            AddPersonSheet { model.data.profile.people.append($0) }
                .presentationDetents([.height(360)])
        }
        .sheet(isPresented: $addingKid) {
            AddPersonSheet(title: "Add *child*", placeholder: "Son, 6, loves dinosaurs…") { model.data.profile.kids.append($0) }
                .presentationDetents([.height(360)])
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackSheet(title: "Anything Solenne\nshould *know?*",
                          subtitle: "It goes straight into your profile and shapes every story from now on.",
                          placeholder: "A new job, a person, a feeling…",
                          button: "Tell Solenne")
                .presentationDetents([.medium])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Orb(size: 44, breathing: false)
                Text(model.data.profile.name.isEmpty ? "You" : model.data.profile.name)
                    .font(.serifItalic(30))
                    .foregroundStyle(Palette.ink)
                Spacer()
                CircleIconButton(systemName: "gearshape.fill", label: "Settings") { model.push(.settings) }
            }
            Text("The more Solenne knows, the realer it feels")
                .font(.sans(13))
                .foregroundStyle(Palette.inkSoft)
        }
        .padding(.top, 8)
    }

    // MARK: Building blocks

    private var divider: some View {
        Rectangle().fill(Palette.ink.opacity(0.06)).frame(height: 1).padding(.leading, 16)
    }

    private func section<Content: View>(_ title: String, icon: String = "sparkle", @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: title, icon: icon)
            VStack(spacing: 0, content: content)
                .glass(radius: 22, opacity: 0.6)
        }
    }

    private func navRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.sans(15)).foregroundStyle(Palette.ink)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func basicRow(_ title: String, _ key: WritableKeyPath<Profile, String>) -> some View {
        Button {
            draft = model.data.profile[keyPath: key]
            editing = EditTarget(title: title, key: key)
        } label: {
            HStack {
                Text(title).font(.sans(15)).foregroundStyle(Palette.inkSoft)
                Spacer()
                Text(model.data.profile[keyPath: key].isEmpty ? "Add" : model.data.profile[keyPath: key])
                    .font(.sans(15, .semibold))
                    .foregroundStyle(model.data.profile[keyPath: key].isEmpty ? Palette.inkFaint : Palette.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Edit \(title)")
    }

    private func peopleSection(title: String, icon: String, people: WritableKeyPath<Profile, [Person]>, empty: String, addLabel: String, add: @escaping () -> Void) -> some View {
        let list = model.data.profile[keyPath: people]
        return section(title, icon: icon) {
            if list.isEmpty {
                Text(empty)
                    .font(.sans(13))
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
            }
            ForEach(list) { person in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name).font(.sans(15, .semibold)).foregroundStyle(Palette.ink)
                        if !person.relation.isEmpty {
                            Text(person.relation).font(.sans(12.5)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                        }
                    }
                    Spacer()
                    Button {
                        model.data.profile[keyPath: people].removeAll { $0.id == person.id }
                    } label: {
                        Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(Palette.inkFaint)
                    }
                    .accessibilityLabel("Remove \(person.name)")
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                divider
            }
            Button(action: add) {
                Label(addLabel, systemImage: "plus")
                    .font(.sans(14, .medium))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
        }
    }

    private func tagSection(title: String, icon: String, values: [String], target: ListTarget, refresh: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(title: title, icon: icon)
                Spacer()
                if refresh {
                    Button {
                        refreshingTags = true
                        Task {
                            model.data.profile.lifestyleTags = await StoryEngine.lifestyleTags(for: model.data.profile)
                            refreshingTags = false
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft)
                            .rotationEffect(.degrees(refreshingTags ? 360 : 0))
                            .animation(refreshingTags ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: refreshingTags)
                    }
                    .accessibilityLabel("Refresh lifestyle tags from your profile")
                }
            }
            FlowLayout(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    HStack(spacing: 6) {
                        Text(value).font(.sans(13.5)).foregroundStyle(Palette.ink)
                        Button {
                            if target == .never {
                                model.data.profile.neverInclude.removeAll { $0 == value }
                            } else {
                                model.data.profile.lifestyleTags.removeAll { $0 == value }
                            }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.inkFaint)
                        }
                        .accessibilityLabel("Remove \(value)")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.white.opacity(0.6)))
                }
                Button {
                    tagDraft = ""
                    addingTag = target
                } label: {
                    Text("+ Add")
                        .font(.sans(13.5))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .overlay(Capsule().strokeBorder(Palette.mauve, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
