import SwiftUI

@main
struct SolenneApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Fonts.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Palette.plum)
                .preferredColorScheme(.light)
                .task { await model.purchases.load() }
                .onOpenURL { url in
                    // solenne://story/<uuid>
                    guard url.host() == "story", let id = UUID(uuidString: url.lastPathComponent),
                          let story = model.story(id: id) else { return }
                    model.play(story)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model.saveNow() }
            if phase == .active { Task { await model.refreshForYouIfNeeded() } }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            if model.data.onboarded {
                MainTabsView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: model.data.onboarded)
        .fullScreenCover(item: $model.nowPlaying) { story in
            PlayerView(story: story)
        }
        .sheet(isPresented: $model.showPaywall) {
            PaywallView()
        }
    }
}

struct MainTabsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .bottom) {
            Group {
                switch model.tab {
                case .home:
                    NavigationStack(path: $model.homePath) {
                        HomeView().withRoutes()
                    }
                case .library:
                    NavigationStack(path: $model.libraryPath) {
                        LibraryView().withRoutes()
                    }
                case .affirmations:
                    NavigationStack(path: $model.affirmationsPath) {
                        AffirmationsView().withRoutes()
                    }
                case .profile:
                    NavigationStack(path: $model.profilePath) {
                        ProfileView().withRoutes()
                    }
                }
            }

            if model.currentPathIsEmpty {
                FloatingTabBar(selection: $model.tab)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.currentPathIsEmpty)
        .ignoresSafeArea(.keyboard)
        .task { await model.refreshForYouIfNeeded() }
        .sheet(item: $model.sharing) { story in
            ShareCardSheet(story: story)
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab

    private func icon(_ tab: AppTab) -> (String, String) {
        switch tab {
        case .home: (selection == tab ? "house.fill" : "house", "Home")
        case .library: (selection == tab ? "book.fill" : "book", "Library")
        case .affirmations: (selection == tab ? "star.fill" : "star", "Affirmations")
        case .profile: (selection == tab ? "person.fill" : "person", "Profile")
        }
    }

    var body: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let (symbol, label) = icon(tab)
                Button {
                    selection = tab
                } label: {
                    Image(systemName: symbol)
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(selection == tab ? Palette.plum : Palette.inkSoft)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .glass(radius: 32, opacity: 0.7)
        .padding(.horizontal, 24)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

extension View {
    /// Registers every pushed screen in the app on a NavigationStack.
    func withRoutes() -> some View {
        navigationDestination(for: Route.self) { route in
            Group {
                switch route {
                case .forYou: ForYouView()
                case .explore: ExploreView()
                case .desires: DesiresView()
                case .challenge: ChallengeIntroView()
                case .challengeProgress: ChallengeProgressView()
                case .reminders: RemindersView()
                case .voices: VoicesView()
                case .voiceClone: VoiceCloneView()
                case .favorites: StoryListView(mode: .favorites)
                case .recent: StoryListView(mode: .recent)
                case .journal: JournalView()
                case .settings: SettingsView()
                case .savedAffirmations: SavedAffirmationsView()
                case .collection(let kind): CollectionView(kind: kind)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Standard top bar for pushed screens: back button, optional title and trailing content.
struct ScreenHeader<Trailing: View>: View {
    var title: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            BackButton()
            if let title {
                SerifHeading(title, size: 28, alignment: .leading)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String? = nil) {
        self.title = title
        self.trailing = { EmptyView() }
    }
}

/// Keeps the swipe-back gesture working even though the navigation bar is hidden.
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
