import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    @State private var index = 0
    @State private var history: [Int] = []
    @State private var typed = false
    @State private var input = ""
    @State private var reflection: String?
    @State private var showAddPerson = false
    @State private var enteringCode = false
    @State private var finishing = false
    @FocusState private var fieldFocused: Bool

    private let steps = OnboardingScript.steps
    private var step: OnboardingStep { steps[index] }

    var body: some View {
        if finishing {
            MakingStoriesView()
                .task { await finish() }
        } else {
            questionScreen
        }
    }

    // MARK: Layout

    private var questionScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    promptView
                        .id(index)
                    if typed { accessory.transition(.opacity.combined(with: .move(edge: .bottom))) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 72)
            }
            .scrollDismissesKeyboard(.never)
            if typed, let bar = inputBar { bar.transition(.opacity) }
        }
        .animation(.easeOut(duration: 0.3), value: typed)
        .solenneBackground()
        .sheet(isPresented: $showAddPerson) {
            AddPersonSheet { person in model.data.profile.people.append(person) }
                .presentationDetents([.height(360)])
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button(action: goBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 36, height: 36)
            }
            .opacity(history.isEmpty ? 0 : 1)
            .disabled(history.isEmpty)
            .accessibilityLabel("Back")

            ThinProgressBar(value: Double(index) / Double(steps.count - 1))
            if isSkippable {
                Button("Skip") { advance() }
                    .font(.sans(14, .medium))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var promptView: some View {
        if case .reflect(let key) = step.kind {
            if let reflection {
                TypewriterText(text: reflection) { typed = true }
            } else {
                TypingDots()
                    .padding(.vertical, 12)
                    .task(id: index) {
                        let answer = model.data.profile[keyPath: key]
                        let question = steps[max(index - 1, 0)].prompt(model.data.profile)
                        reflection = await StoryEngine.reflection(question: question, answer: answer, name: model.data.profile.firstName)
                    }
            }
        } else {
            TypewriterText(text: step.prompt(model.data.profile)) {
                typed = true
                if case .text = step.kind { fieldFocused = true }
            }
        }
    }

    // MARK: Per-step accessories

    @ViewBuilder
    private var accessory: some View {
        switch step.kind {
        case .notifications:
            VStack(alignment: .leading, spacing: 18) {
                Text("A soft reminder at the time you choose, so your daily story is never missed.")
                    .font(.sans(15))
                    .foregroundStyle(Palette.inkSoft)
                VStack(spacing: 12) {
                    Button("Turn on reminders") {
                        Task {
                            await Notifications.requestPermission()
                            advance()
                        }
                    }
                    .buttonStyle(.primary)
                    Button("Not now") { advance() }
                        .font(.sans(14, .medium))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 140)
            }

        case .referral:
            VStack(spacing: 12) {
                if enteringCode {
                    EmptyView()
                } else {
                    Button {
                        if let pasted = UIPasteboard.general.string, !pasted.isEmpty {
                            model.data.profile.referralCode = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                            advance()
                        } else {
                            enteringCode = true
                        }
                    } label: { Label("Paste code", systemImage: "doc.on.clipboard") }
                        .buttonStyle(.primary)
                    Button {
                        enteringCode = true
                        fieldFocused = true
                    } label: { Text("Enter it manually") }
                        .buttonStyle(.mauve)
                    Button("I don't have a code") { advance() }
                        .font(.sans(14, .medium))
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.top, 6)
                }
            }
            .padding(.top, 140)

        case .message, .reflect:
            HStack {
                Spacer()
                Button(action: advance) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Palette.plum))
                }
                .accessibilityLabel("Continue")
            }
            .padding(.top, 40)

        case .choice(let key, let options, _, _):
            let isGrid = options.count > 4
            VStack(alignment: .leading, spacing: 20) {
                if isGrid {
                    FlowLayout(spacing: 10) {
                        ForEach(options, id: \.self) { option in
                            Chip(title: option, selected: model.data.profile[keyPath: key] == option) {
                                model.data.profile[keyPath: key] = option
                            }
                        }
                    }
                    Button("Continue", action: advance)
                        .buttonStyle(.primary)
                        .disabled(model.data.profile[keyPath: key].isEmpty)
                        .padding(.top, 20)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(options, id: \.self) { option in
                            Chip(title: option, selected: model.data.profile[keyPath: key] == option) {
                                model.data.profile[keyPath: key] = option
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { advance() }
                            }
                        }
                    }
                }
            }

        case .people:
            VStack(alignment: .leading, spacing: 12) {
                ForEach(model.data.profile.people) { person in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.name).font(.sans(15, .semibold)).foregroundStyle(Palette.ink)
                            Text(person.relation).font(.sans(13)).foregroundStyle(Palette.inkSoft)
                        }
                        Spacer()
                        Button {
                            model.data.profile.people.removeAll { $0.id == person.id }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkSoft)
                        }
                        .accessibilityLabel("Remove \(person.name)")
                    }
                    .padding(16)
                    .glass(radius: 18, opacity: 0.7)
                }
                Button {
                    showAddPerson = true
                } label: {
                    Label("Add person", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary)
                Button(model.data.profile.people.isEmpty ? "Skip for now" : "Continue", action: advance)
                    .buttonStyle(.primary)
                    .padding(.top, 24)
            }

        case .text:
            EmptyView()
        }
    }

    /// The answer field with a send arrow, sitting just above the keyboard.
    private var inputBar: AnyView? {
        var placeholder = ""
        var keyboard = UIKeyboardType.default
        switch step.kind {
        case let .text(_, p, k, _):
            placeholder = p
            keyboard = k
        case let .choice(_, _, allowsText, p) where allowsText:
            placeholder = p
        case .referral where enteringCode:
            placeholder = "Invite code"
        default:
            return nil
        }
        return AnyView(
            HStack(spacing: 10) {
                TextField(placeholder, text: $input, axis: .vertical)
                    .font(.sans(15))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1...4)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(keyboard == .default ? TextInputAutocapitalization.sentences : TextInputAutocapitalization.never)
                    .focused($fieldFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(canSend ? Palette.plum : Palette.mauve.opacity(0.4)))
                }
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.85)))
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        )
    }

    // MARK: Logic

    private var canSend: Bool { !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var isSkippable: Bool {
        switch step.kind {
        case .referral: true
        case .text(_, _, _, let optional): optional
        default: false
        }
    }

    private func send() {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        switch step.kind {
        case let .text(key, _, _, _), let .choice(key, _, _, _):
            model.data.profile[keyPath: key] = value
        case .referral:
            model.data.profile.referralCode = value
        default:
            break
        }
        advance()
    }

    private func advance() {
        var next = index + 1
        while next < steps.count && !steps[next].isIncluded(model.data.profile) { next += 1 }
        guard next < steps.count else {
            fieldFocused = false
            finishing = true
            return
        }
        history.append(index)
        moveTo(next)
    }

    private func goBack() {
        guard var previous = history.popLast() else { return }
        // Don't replay reflections when stepping back.
        while case .reflect = steps[previous].kind, let earlier = history.popLast() { previous = earlier }
        moveTo(previous)
    }

    private func moveTo(_ newIndex: Int) {
        typed = false
        reflection = nil
        enteringCode = false
        index = newIndex
        input = prefill(for: steps[newIndex])
    }

    private func prefill(for step: OnboardingStep) -> String {
        switch step.kind {
        case let .text(key, _, _, _): model.data.profile[keyPath: key]
        default: ""
        }
    }

    private func finish() async {
        let started = Date.now
        await model.completeOnboarding()
        // Let the loader breathe for a moment even when generation is instant.
        let remaining = 3.5 - Date.now.timeIntervalSince(started)
        if remaining > 0 { try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
        model.data.onboarded = true
        if !model.isPro { model.showPaywall = true }
    }
}

struct AddPersonSheet: View {
    var title = "Add *person*"
    var placeholder = "Mum, best friend, sister, supportive, I miss them…"
    var onAdd: (Person) -> Void
    @State private var name = ""
    @State private var relation = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(title: title)
            TextField("Name", text: $name)
                .fieldStyle()
                .textInputAutocapitalization(.words)
            TextAreaField(placeholder: placeholder, text: $relation, minHeight: 80)
            Button("Add") {
                onAdd(Person(name: name.trimmingCharacters(in: .whitespaces), relation: relation.trimmingCharacters(in: .whitespacesAndNewlines)))
                dismiss()
            }
            .buttonStyle(.primary)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            Spacer(minLength: 0)
        }
        .padding(24)
        .background(Palette.paper)
    }
}
