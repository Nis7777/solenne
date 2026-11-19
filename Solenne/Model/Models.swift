import Foundation

enum CoverTheme: String, Codable, CaseIterable {
    case dawn, ocean, golden, rose, midnight, forest, city, desert
}

struct Person: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var relation: String
}

/// Everything the user has told Solenne. This is the context for every story.
struct Profile: Codable, Equatable {
    var name = ""
    var city = ""
    var age = ""
    var gender = ""
    var sexuality = ""
    var hasKids = ""
    var hopingChanges = ""
    var whyNow = ""
    var obstacle = ""
    var relationship = ""
    var work = ""
    var workFeeling = ""
    var about = ""
    var past = ""
    var dreamLocation = ""
    var homeType = ""
    var partner = ""
    var dreamCareer = ""
    var dreamMoney = ""
    var dreamBody = ""
    var dreamDay = ""
    var people: [Person] = []
    var kids: [Person] = []
    var lifestyleTags: [String] = []
    var neverInclude: [String] = []
    /// Free-form notes from "Something sound off?" and "Anything Solenne should know?".
    var notes: [String] = []
    var referralCode = ""

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}

struct Desire: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
    var theme: CoverTheme
    var createdAt = Date()
}

enum StoryKind: String, Codable {
    case vision, affirmation, sleep
}

struct Story: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var text: String
    var theme: CoverTheme
    var kind: StoryKind = .vision
    var desireID: UUID? = nil
    var createdAt = Date()
    /// Narrated audio (e.g. ElevenLabs, cached in storage). Without it the app narrates on device.
    var audioURL: URL? = nil

    var lines: [String] { Narration.lines(from: text) }

    var minutes: Int {
        let words = text.split(whereSeparator: \.isWhitespace).count
        return max(1, Int((Double(words) / 140).rounded()))
    }
}

struct Listen: Codable, Hashable {
    var storyID: UUID
    var date: Date
}

struct GratitudeEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var text: String
}

struct Manifestation: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var title: String
    var note: String
    var imageFile: String? = nil
}

struct ReminderTime: Codable, Hashable {
    var hour: Int
    var minute: Int

    var label: String {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? .now
        return date.formatted(date: .omitted, time: .shortened).lowercased()
    }
}

struct ClonedVoice: Codable, Hashable {
    /// Local recording of the sample.
    var sampleFile: String
    /// ElevenLabs voice id once the backend has cloned it.
    var remoteVoiceID: String?
    var createdAt = Date()
}

/// Persisted app state. Local-first: saved as JSON in Documents.
struct AppData: Codable {
    var onboarded = false
    var profile = Profile()
    var desires: [Desire] = []
    var stories: [Story] = []
    var forYouDay = ""
    var listens: [Listen] = []
    var favorites: [UUID: Date] = [:]
    var bookmarks: Set<UUID> = []
    var savedAffirmations: [String] = []
    var affirmationDay = ""
    var affirmationIndex = 0
    var gratitude: [GratitudeEntry] = []
    var manifestations: [Manifestation] = []
    var challengeStart: Date? = nil
    var voiceID = "solenne"
    var clonedVoice: ClonedVoice? = nil
    var cloneAttempts = 0
    var reminder: ReminderTime? = nil
    var namePronunciation = ""
    var ambientOn = true
    var appleUserID: String? = nil
    var freeCreateDay = ""
    /// Stories a free user can play: the first of each daily batch and their on-demand ones.
    var freeStoryIDs: Set<UUID> = []
}

// MARK: - Day helpers

enum Day {
    static func key(_ date: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func nextMidnight(after date: Date = .now) -> Date {
        Calendar.current.startOfDay(for: date).addingTimeInterval(86_400)
    }
}

extension UUID {
    /// Deterministic UUID for bundled content, so favourites survive relaunches.
    static func stable(_ seed: String) -> UUID {
        var h1: UInt64 = 0xcbf29ce484222325
        var h2: UInt64 = 0x84222325cbf29ce4
        for byte in seed.utf8 {
            h1 = (h1 ^ UInt64(byte)) &* 0x100000001b3
            h2 = (h2 ^ UInt64(byte)) &* 0x1000193
        }
        let b1: [UInt8] = withUnsafeBytes(of: h1.bigEndian) { Array($0) }
        let b2: [UInt8] = withUnsafeBytes(of: h2.bigEndian) { Array($0) }
        let b = b1 + b2
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
}
