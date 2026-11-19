import Foundation
import Observation
import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case home, library, affirmations, profile
}

struct StoryEntry: Identifiable {
    let story: Story
    let date: Date
    var id: UUID { story.id }
}

enum Route: Hashable {
    case forYou
    case explore
    case desires
    case challenge
    case challengeProgress
    case reminders
    case voices
    case voiceClone
    case favorites
    case recent
    case journal
    case settings
    case savedAffirmations
    case collection(StoryKind)
}

@Observable
final class AppModel {
    var data: AppData {
        didSet { scheduleSave() }
    }

    // Transient UI state
    var tab: AppTab = .home
    var homePath: [Route] = []
    var libraryPath: [Route] = []
    var affirmationsPath: [Route] = []
    var profilePath: [Route] = []
    var nowPlaying: Story?
    var sharing: Story?
    var showPaywall = false
    var isGenerating = false
    var generationError: String?

    let purchases = PurchaseManager()

    @ObservationIgnored private var saveWork: DispatchWorkItem?

    init() {
        data = AppModel.load() ?? AppData()
    }

    // MARK: Persistence

    private static var fileURL: URL {
        URL.documentsDirectory.appending(path: "solenne.json")
    }

    static var imagesDirectory: URL {
        let url = URL.documentsDirectory.appending(path: "images", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func load() -> AppData? {
        guard let raw = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(AppData.self, from: raw)
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let snapshot = data
        let work = DispatchWorkItem {
            if let raw = try? JSONEncoder().encode(snapshot) {
                try? raw.write(to: AppModel.fileURL, options: .atomic)
            }
        }
        saveWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        if let raw = try? JSONEncoder().encode(data) {
            try? raw.write(to: AppModel.fileURL, options: .atomic)
        }
    }

    func deleteEverything() {
        Notifications.cancelReminder()
        try? FileManager.default.removeItem(at: AppModel.imagesDirectory)
        data = AppData()
        saveNow()
        homePath = []
        libraryPath = []
        affirmationsPath = []
        profilePath = []
        tab = .home
    }

    // MARK: Navigation helpers

    func push(_ route: Route) {
        switch tab {
        case .home: homePath.append(route)
        case .library: libraryPath.append(route)
        case .affirmations: affirmationsPath.append(route)
        case .profile: profilePath.append(route)
        }
    }

    var currentPathIsEmpty: Bool {
        switch tab {
        case .home: homePath.isEmpty
        case .library: libraryPath.isEmpty
        case .affirmations: affirmationsPath.isEmpty
        case .profile: profilePath.isEmpty
        }
    }

    // MARK: Stories

    var isPro: Bool { purchases.isPro }

    /// The current daily batch, newest first.
    var forYou: [Story] {
        let days: Set<String> = [data.forYouDay, Day.key()]
        let today = data.stories.filter { days.contains(Day.key($0.createdAt)) }
        let list = today.isEmpty ? Array(data.stories.prefix(3)) : today
        return list.sorted { $0.createdAt > $1.createdAt }
    }

    func story(id: UUID) -> Story? {
        data.stories.first { $0.id == id } ?? LibraryContent.all.first { $0.id == id }
    }

    /// Free users can play the first story of each batch and the ones they create; the rest open the paywall.
    func isLocked(_ story: Story) -> Bool {
        guard !isPro, story.kind == .vision else { return false }
        if LibraryContent.all.contains(where: { $0.id == story.id }) { return false }
        return !data.freeStoryIDs.contains(story.id)
    }

    func play(_ story: Story) {
        if isLocked(story) {
            showPaywall = true
        } else {
            nowPlaying = story
        }
    }

    /// Called at the end of onboarding: seeds desires and tags, and makes the first stories.
    @MainActor
    func completeOnboarding() async {
        if data.desires.isEmpty { data.desires = DesireSeeder.desires(from: data.profile) }
        data.profile.lifestyleTags = await StoryEngine.lifestyleTags(for: data.profile)
        await generateDailyBatch()
    }

    /// Generates the day's stories once every 24h (the "daily refresh"). Keeps cost fixed per user.
    @MainActor
    func refreshForYouIfNeeded() async {
        guard data.onboarded, data.forYouDay != Day.key() else { return }
        await generateDailyBatch()
    }

    @MainActor
    private func generateDailyBatch() async {
        let today = Day.key()
        guard data.forYouDay != today, !isGenerating else { return }
        if data.desires.isEmpty { data.desires = DesireSeeder.desires(from: data.profile) }
        guard !data.desires.isEmpty else { return }

        isGenerating = true
        defer { isGenerating = false }

        // Rotate through desires so each day covers different ones.
        let offset = (Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0) % data.desires.count
        let rotated = Array(data.desires[offset...] + data.desires[..<offset])
        let chosen = Array(rotated.prefix(StoryEngine.dailyCount))
        let profile = data.profile
        let voiceID = narrationVoiceID
        let batch: [Story] = await withTaskGroup(of: (Int, Story).self) { group in
            for (index, desire) in chosen.enumerated() {
                group.addTask { (index, await StoryEngine.story(for: desire, profile: profile, voiceID: voiceID)) }
            }
            var results: [(Int, Story)] = []
            for await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
        data.stories.insert(contentsOf: batch, at: 0)
        if let first = batch.first { data.freeStoryIDs.insert(first.id) }
        data.forYouDay = today
        trimHistory()
    }

    /// "What do you want to manifest?" — adds a desire and makes a story for it right away.
    @MainActor
    func manifest(_ wish: String) async -> Story? {
        let trimmed = wish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !canCreateNow {
            showPaywall = true
            return nil
        }
        let desire = DesireSeeder.desire(fromWish: trimmed)
        data.desires.insert(desire, at: 0)
        return await makeStory(for: desire)
    }

    /// Free users get one on-demand story a day; Pro is unlimited.
    var canCreateNow: Bool { isPro || data.freeCreateDay != Day.key() }

    @MainActor
    func makeStory(for desire: Desire) async -> Story? {
        guard canCreateNow else {
            showPaywall = true
            return nil
        }
        isGenerating = true
        defer { isGenerating = false }
        var story = await StoryEngine.story(for: desire, profile: data.profile, voiceID: narrationVoiceID)
        story.createdAt = .now
        data.stories.insert(story, at: 0)
        data.freeStoryIDs.insert(story.id)
        if !isPro { data.freeCreateDay = Day.key() }
        return story
    }

    private func trimHistory() {
        // Keep favourites forever, otherwise the last 120 stories.
        if data.stories.count > 120 {
            data.stories = data.stories.enumerated().filter { index, story in
                index < 120 || data.favorites[story.id] != nil
            }.map(\.element)
        }
    }

    var narrationVoiceID: String {
        if data.voiceID == Voices.cloneID, let remote = data.clonedVoice?.remoteVoiceID { return remote }
        return Voices.find(data.voiceID)?.elevenLabsID ?? Voices.all[0].elevenLabsID
    }

    // MARK: Favourites & listens

    func isFavorite(_ story: Story) -> Bool { data.favorites[story.id] != nil }

    func toggleFavorite(_ story: Story) {
        if data.favorites[story.id] == nil {
            data.favorites[story.id] = .now
        } else {
            data.favorites[story.id] = nil
        }
    }

    func recordListen(_ story: Story) {
        let today = Day.key()
        if data.listens.contains(where: { $0.storyID == story.id && Day.key($0.date) == today }) { return }
        data.listens.append(Listen(storyID: story.id, date: .now))
    }

    var favoriteEntries: [StoryEntry] {
        data.favorites
            .sorted { $0.value > $1.value }
            .compactMap { entry in story(id: entry.key).map { StoryEntry(story: $0, date: entry.value) } }
    }

    var recentlyPlayed: [StoryEntry] {
        var seen = Set<UUID>()
        var result: [StoryEntry] = []
        for listen in data.listens.reversed() where !seen.contains(listen.storyID) {
            seen.insert(listen.storyID)
            if let s = story(id: listen.storyID) { result.append(StoryEntry(story: s, date: listen.date)) }
        }
        return result
    }

    // MARK: Streaks

    var listenDays: Set<String> { Set(data.listens.map { Day.key($0.date) }) }

    var listenedToday: Bool { listenDays.contains(Day.key()) }

    var currentStreak: Int {
        let days = listenDays
        let cal = Calendar.current
        var cursor = Date.now
        if !days.contains(Day.key(cursor)) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var count = 0
        while days.contains(Day.key(cursor)) {
            count += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }

    var longestStreak: Int {
        let dates = listenDays.compactMap(Day.date(fromKey:)).sorted()
        var best = 0, run = 0
        var previous: Date?
        for date in dates {
            if let previous, Calendar.current.dateComponents([.day], from: previous, to: date).day == 1 {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = date
        }
        return best
    }

    var daysThisMonth: Int {
        let cal = Calendar.current
        return listenDays.compactMap(Day.date(fromKey:)).filter {
            cal.isDate($0, equalTo: .now, toGranularity: .month)
        }.count
    }

    /// Distinct listening days since the 21-day challenge started.
    var challengeDaysDone: Int {
        guard let start = data.challengeStart else { return 0 }
        let startKey = Day.key(start)
        return min(21, listenDays.filter { $0 >= startKey }.count)
    }

    /// The day number the user is on now (1...21).
    var challengeDay: Int {
        min(21, challengeDaysDone + (listenedToday ? 0 : 1))
    }
}
