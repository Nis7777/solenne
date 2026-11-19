import AuthenticationServices
import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var showManage = false
    @State private var confirmDelete = false
    @State private var troubleshooting: String?
    @State private var signInError: String?

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            ScreenHeader(title: "Settings")
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    group("Narration") {
                        row("My voice", detail: currentVoiceName) { model.push(.voices) }
                        line
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name pronunciation").font(.sans(15)).foregroundStyle(Palette.ink)
                            HStack {
                                TextField("How should Solenne say \(model.data.profile.firstName.isEmpty ? "your name" : model.data.profile.firstName)?", text: $model.data.namePronunciation)
                                    .font(.sans(14))
                                    .foregroundStyle(Palette.ink)
                                Button {
                                    let spoken = model.data.namePronunciation.isEmpty ? model.data.profile.firstName : model.data.namePronunciation
                                    VoicePreviewer.shared.preview(Voices.onDevice(for: model.data.voiceID), name: spoken)
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(Palette.plum)
                                }
                                .accessibilityLabel("Hear it")
                            }
                            Text("Spell it the way it sounds, e.g. \"Shiv-awn\" for Siobhan.")
                                .font(.sans(11.5))
                                .foregroundStyle(Palette.inkSoft)
                        }
                        .padding(16)
                        line
                        row("Daily reminder", detail: model.data.reminder?.label ?? "Off") { model.push(.reminders) }
                    }

                    group("Account") {
                        if model.data.appleUserID != nil {
                            HStack {
                                Image(systemName: "apple.logo")
                                Text("Signed in with Apple").font(.sans(15))
                                Spacer()
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.plum)
                            }
                            .foregroundStyle(Palette.ink)
                            .padding(16)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                SignInWithAppleButton(.signIn) { request in
                                    request.requestedScopes = [.fullName]
                                } onCompletion: { result in
                                    switch result {
                                    case .success(let auth):
                                        if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                                            model.data.appleUserID = credential.user
                                        }
                                    case .failure(let error):
                                        signInError = error.localizedDescription
                                    }
                                }
                                .signInWithAppleButtonStyle(.black)
                                .frame(height: 48)
                                .clipShape(Capsule())
                                Text("Keeps your stories safe if you switch phones.")
                                    .font(.sans(11.5))
                                    .foregroundStyle(Palette.inkSoft)
                                if let signInError {
                                    Text(signInError).font(.sans(11.5)).foregroundStyle(.red)
                                }
                            }
                            .padding(16)
                        }
                    }

                    group("Subscription") {
                        if model.isPro {
                            row("Manage subscription") { showManage = true }
                        } else {
                            row("Upgrade to Solenne Pro") { model.showPaywall = true }
                        }
                        line
                        row("Restore purchases") { Task { await model.purchases.restore() } }
                        #if DEBUG
                        line
                        Toggle(isOn: Binding(get: { model.isPro }, set: { model.purchases.setDebugPro($0) })) {
                            Text("Pro (debug only)").font(.sans(15)).foregroundStyle(Palette.ink)
                        }
                        .tint(Palette.plum)
                        .padding(16)
                        #endif
                    }

                    group("About") {
                        row("Version", detail: version, chevron: false) {}
                        line
                        row("Terms of use") { openURL(Config.termsURL) }
                        line
                        row("Privacy policy") { openURL(Config.privacyURL) }
                        line
                        row("Contact us") {
                            if let url = URL(string: "mailto:\(Config.supportEmail)?subject=Solenne%20\(version.replacingOccurrences(of: " ", with: "%20"))") {
                                openURL(url)
                            }
                        }
                        line
                        row("Share troubleshooting info") { troubleshooting = diagnostics() }
                    }

                    Button(role: .destructive) { confirmDelete = true } label: {
                        Text("Delete account")
                            .font(.sans(15, .semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .glass(radius: 22, opacity: 0.6)
                    }
                    .buttonStyle(.plain)

                    #if DEBUG
                    Button("Replay onboarding (debug)") {
                        model.data.onboarded = false
                        model.profilePath = []
                    }
                    .font(.sans(13))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity)
                    #endif
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .solenneBackground()
        .manageSubscriptionsSheet(isPresented: $showManage)
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { model.deleteEverything() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your profile, stories, journal and voice sample from this device. Active subscriptions are managed by Apple and must be cancelled separately.")
        }
        .sheet(isPresented: Binding(get: { troubleshooting != nil }, set: { if !$0 { troubleshooting = nil } })) {
            ActivityView(items: [troubleshooting ?? ""])
                .presentationDetents([.medium])
        }
    }

    private var currentVoiceName: String {
        switch model.data.voiceID {
        case Voices.cloneID: "My voice"
        case Voices.personalID: "Personal Voice"
        default: Voices.find(model.data.voiceID)?.name ?? "Solenne"
        }
    }

    private func diagnostics() -> String {
        """
        Solenne \(version)
        iOS \(UIDevice.current.systemVersion), \(UIDevice.current.model)
        Pro: \(model.isPro)
        Stories: \(model.data.stories.count), desires: \(model.data.desires.count), listens: \(model.data.listens.count)
        Voice: \(model.data.voiceID)
        Backend configured: \(Backend.isConfigured)
        On-device model: \(OnDeviceModel.isAvailable)
        Reminder: \(model.data.reminder?.label ?? "off")
        """
    }

    private var line: some View {
        Rectangle().fill(Palette.ink.opacity(0.06)).frame(height: 1).padding(.leading, 16)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(title).padding(.leading, 4)
            VStack(spacing: 0, content: content)
                .glass(radius: 22, opacity: 0.6)
        }
    }

    private func row(_ title: String, detail: String? = nil, chevron: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.sans(15)).foregroundStyle(Palette.ink)
                Spacer()
                if let detail { Text(detail).font(.sans(14)).foregroundStyle(Palette.inkSoft) }
                if chevron {
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.inkFaint)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Paywall

struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selectedID = "solenne.pro.yearly"
    @State private var purchasing = false

    private var products: [Product] { model.purchases.products }
    private var selected: Product? { products.first { $0.id == selectedID } ?? products.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
                    Spacer()
                    Button("Restore") { Task { await model.purchases.restore(); if model.isPro { dismiss() } } }
                        .font(.sans(13, .medium))
                        .foregroundStyle(Palette.inkSoft)
                }
                Orb(size: 96)
                SerifHeading("Unlock *Solenne Pro*", size: 36)
                VStack(alignment: .leading, spacing: 14) {
                    benefit("sparkles", "Every daily story, written for your life")
                    benefit("wand.and.stars", "Call in anything, any time, with unlimited new stories")
                    benefit("mic.fill", "Hear it all in your own cloned voice")
                    benefit("flame.fill", "The full 21-day challenge, affirmations and sleep tracks")
                }
                .padding(20)
                .glass(radius: 24, opacity: 0.6)

                if products.isEmpty {
                    VStack(spacing: 6) {
                        ProgressView()
                        Text("Loading plans…").font(.sans(13)).foregroundStyle(Palette.inkSoft)
                        if let error = model.purchases.lastError {
                            Text(error).font(.sans(11)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 10) {
                        ForEach(products.reversed(), id: \.id) { product in
                            planRow(product)
                        }
                    }
                }

                Button {
                    guard let selected else { return }
                    purchasing = true
                    Task {
                        let ok = await model.purchases.purchase(selected)
                        purchasing = false
                        if ok { dismiss() }
                    }
                } label: {
                    if purchasing { ProgressView().tint(.white) } else { Text(ctaTitle) }
                }
                .buttonStyle(.primary)
                .disabled(selected == nil || purchasing)

                if let selected {
                    Text(footnote(for: selected))
                        .font(.sans(11.5))
                        .foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 18) {
                    Button("Terms") { openURL(Config.termsURL) }
                    Button("Privacy") { openURL(Config.privacyURL) }
                }
                .font(.sans(11.5))
                .foregroundStyle(Palette.inkSoft)
            }
            .padding(24)
        }
        .solenneBackground()
        .task { if model.purchases.products.isEmpty { await model.purchases.load() } }
    }

    private var ctaTitle: String {
        guard let selected, let trial = trialText(selected) else { return "Continue" }
        return "Start my \(trial)"
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Palette.rose).frame(width: 22)
            Text(text).font(.sans(14.5)).foregroundStyle(Palette.ink)
        }
    }

    private func planRow(_ product: Product) -> some View {
        let isSelected = product.id == selected?.id
        let yearly = product.subscription?.subscriptionPeriod.unit == .year
        return Button { selectedID = product.id } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(yearly ? "Yearly" : "Weekly").font(.sans(15.5, .semibold))
                        if yearly {
                            Text("BEST VALUE").font(.sans(9, .bold)).tracking(1)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(Palette.rose)).foregroundStyle(.white)
                        }
                    }
                    Text(trialText(product).map { "\($0), then \(product.displayPrice)" } ?? product.displayPrice)
                        .font(.sans(12.5))
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Palette.plum : Palette.inkFaint)
            }
            .foregroundStyle(Palette.ink)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(isSelected ? 0.9 : 0.55)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(isSelected ? Palette.plum : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func trialText(_ product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let unit: String
        switch offer.period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "day"
        }
        return "\(offer.period.value)-\(unit) free trial"
    }

    private func footnote(for product: Product) -> String {
        let period = product.subscription?.subscriptionPeriod.unit == .year ? "year" : "week"
        let start = trialText(product).map { "\($0), then " } ?? ""
        return "\(start)\(product.displayPrice) per \(period). Cancel anytime in Settings at least 24 hours before renewal."
    }
}
