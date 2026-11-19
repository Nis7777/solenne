import SwiftUI

// MARK: - Daily reminders

struct RemindersView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private struct Preset: Identifiable {
        let id: String
        let icon: String
        let time: ReminderTime
    }

    private let presets = [
        Preset(id: "morning", icon: "sunrise", time: ReminderTime(hour: 8, minute: 0)),
        Preset(id: "lunch", icon: "sun.max", time: ReminderTime(hour: 12, minute: 30)),
        Preset(id: "golden hour", icon: "sun.horizon", time: ReminderTime(hour: 18, minute: 30)),
        Preset(id: "before sleep", icon: "moon.stars", time: ReminderTime(hour: 21, minute: 30)),
    ]

    @State private var selected = ReminderTime(hour: 21, minute: 30)
    @State private var custom = false
    @State private var customDate = Date.now
    @State private var denied = false

    private var chosen: ReminderTime {
        if custom {
            let c = Calendar.current.dateComponents([.hour, .minute], from: customDate)
            return ReminderTime(hour: c.hour ?? 9, minute: c.minute ?? 0)
        }
        return selected
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader()
            ScrollView {
                VStack(spacing: 18) {
                    SerifHeading("when should I\n*remind you?*", size: 36)
                        .padding(.top, 12)
                    notificationPreview
                    VStack(spacing: 10) {
                        ForEach(presets) { preset in
                            option(icon: preset.icon, title: preset.id, detail: preset.time.label,
                                   isOn: !custom && selected == preset.time) {
                                custom = false
                                selected = preset.time
                            }
                        }
                        option(icon: "clock", title: "pick a time", detail: custom ? chosen.label : "", isOn: custom) {
                            custom = true
                        }
                        if custom {
                            DatePicker("Time", selection: $customDate, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            Button("remind me every day") {
                Task {
                    let time = chosen
                    if await Notifications.scheduleDaily(at: time, name: model.data.profile.firstName) {
                        model.data.reminder = time
                        dismiss()
                    } else {
                        denied = true
                    }
                }
            }
            .buttonStyle(.primary)
            .padding(.horizontal, 24)
            if model.data.reminder != nil {
                Button("turn off reminders") {
                    Notifications.cancelReminder()
                    model.data.reminder = nil
                }
                .font(.sans(13))
                .foregroundStyle(Palette.inkSoft)
                .padding(.vertical, 12)
            } else {
                Spacer().frame(height: 16)
            }
        }
        .solenneBackground()
        .onAppear {
            if let r = model.data.reminder {
                if presets.contains(where: { $0.time == r }) {
                    selected = r
                } else {
                    custom = true
                    customDate = Calendar.current.date(from: DateComponents(hour: r.hour, minute: r.minute)) ?? .now
                }
            }
        }
        .alert("Notifications are off", isPresented: $denied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Turn on notifications for Solenne in Settings so your daily reminder can reach you.")
        }
    }

    private var notificationPreview: some View {
        HStack(alignment: .top, spacing: 12) {
            Orb(size: 34, breathing: false)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Solenne").font(.sans(13, .semibold))
                    Spacer()
                    Text(chosen.label).font(.sans(11)).foregroundStyle(Palette.inkFaint)
                }
                Text("\(model.data.profile.firstName.isEmpty ? "Hey" : model.data.profile.firstName), your story for today is ready. Keep the flame.")
                    .font(.sans(13))
            }
            .foregroundStyle(Palette.ink)
        }
        .padding(14)
        .glass(radius: 22, opacity: 0.85)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notification preview")
    }

    private func option(icon: String, title: String, detail: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 24)
                Text(title).font(.sans(15, .medium))
                Spacer()
                Text(detail).font(.sans(14)).foregroundStyle(isOn ? .white.opacity(0.85) : Palette.inkSoft)
            }
            .foregroundStyle(isOn ? .white : Palette.ink)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isOn ? Palette.plum : Color.white.opacity(0.7)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Desires

struct DesiresView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Desire?
    @State private var adding = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Your *desires*")
            ScrollView {
                VStack(spacing: 12) {
                    Text("Your daily stories rotate through these.")
                        .font(.sans(13.5))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(model.data.desires) { desire in
                        DesireRow(desire: desire) {
                            editing = desire
                        } onDelete: {
                            withAnimation { model.data.desires.removeAll { $0.id == desire.id } }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 80)
            }
            Button { adding = true } label: { Label("Add desire", systemImage: "plus") }
                .buttonStyle(.primary)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .solenneBackground()
        .sheet(isPresented: $adding) {
            CallingInSheet(existing: nil).presentationDetents([.large])
        }
        .sheet(item: $editing) { desire in
            CallingInSheet(existing: desire).presentationDetents([.large])
        }
    }
}

private struct DesireRow: View {
    let desire: Desire
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            CoverArt(theme: desire.theme, seed: desire.id)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(desire.title).font(.sans(15, .semibold)).foregroundStyle(Palette.ink).lineLimit(2)
                if !desire.detail.isEmpty {
                    Text(desire.detail).font(.sans(12.5)).foregroundStyle(Palette.inkSoft).lineLimit(2)
                }
            }
            Spacer()
            Menu {
                Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Palette.ink)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Options for \(desire.title)")
        }
        .padding(12)
        .glass(radius: 22, opacity: 0.7)
    }
}

/// "What are you calling in?" — create or edit a desire, optionally make a story right away.
struct CallingInSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let existing: Desire?

    @State private var title = ""
    @State private var detail = ""
    @State private var theme: CoverTheme = .ocean
    @State private var makingStory = false

    var body: some View {
        if makingStory {
            MakingStoriesView(title: "Calling it *in*", subtitle: "writing a story just for you…")
        } else {
            form
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SheetHeader(title: existing == nil ? "What are you\n*calling in?*" : "Edit *desire*",
                            subtitle: "Be specific. The more detail, the more real your stories will feel.")
                TextField("A home by the sea", text: $title)
                    .fieldStyle()
                TextAreaField(placeholder: "Describe it as if it's already yours…", text: $detail)
                EyebrowLabel("Mood")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CoverTheme.allCases, id: \.self) { t in
                            Button { theme = t } label: {
                                CoverArt(theme: t, seed: UUID.stable(t.rawValue))
                                    .frame(width: 56, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme == t ? Palette.plum : .clear, lineWidth: 2.5))
                            }
                            .accessibilityLabel(t.rawValue)
                            .accessibilityAddTraits(theme == t ? .isSelected : [])
                        }
                    }
                }
                Button(existing == nil ? "Save & make my story ✦" : "Save") { save(makeStory: existing == nil) }
                    .buttonStyle(.primary)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.top, 8)
                if existing == nil {
                    Button("Just save it") { save(makeStory: false) }
                        .font(.sans(13.5, .medium))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(24)
        }
        .background(Palette.paper)
        .onAppear {
            if let existing {
                title = existing.title
                detail = existing.detail
                theme = existing.theme
            } else {
                theme = .ocean
            }
        }
    }

    private func save(makeStory: Bool) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if var desire = existing, let i = model.data.desires.firstIndex(where: { $0.id == desire.id }) {
            desire.title = cleanTitle
            desire.detail = cleanDetail
            desire.theme = theme
            model.data.desires[i] = desire
            dismiss()
            return
        }
        let desire = Desire(title: cleanTitle, detail: cleanDetail, theme: theme)
        model.data.desires.insert(desire, at: 0)
        guard makeStory else {
            dismiss()
            return
        }
        guard model.canCreateNow else {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { model.showPaywall = true }
            return
        }
        makingStory = true
        Task {
            let story = await model.makeStory(for: desire)
            dismiss()
            if let story {
                try? await Task.sleep(nanoseconds: 500_000_000)
                model.play(story)
            }
        }
    }
}
