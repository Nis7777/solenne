import Foundation

/// Offline story writer. Builds a personal, first-person, present-tense vision story
/// from the profile using hand-written sentence pools. Used when neither the backend
/// nor the on-device model is available, so the app works everywhere.
enum StoryComposer {
    enum Category: CaseIterable {
        case love, money, career, home, body, confidence, peace, travel, family, general

        var theme: CoverTheme {
            switch self {
            case .love: .rose
            case .money: .golden
            case .career: .city
            case .home: .dawn
            case .body: .forest
            case .confidence: .desert
            case .peace: .midnight
            case .travel: .ocean
            case .family: .dawn
            case .general: .ocean
            }
        }

        var keywords: [String] {
            switch self {
            case .love: ["love", "partner", "boyfriend", "girlfriend", "husband", "wife", "relationship", "soulmate", "romance", "marry", "dating"]
            case .money: ["money", "rich", "wealth", "abundance", "income", "$", "debt", "financial", "millions", "salary", "paid"]
            case .career: ["career", "job", "work", "business", "promotion", "founder", "client", "company", "boss", "startup", "brand"]
            case .home: ["home", "house", "apartment", "penthouse", "villa", "loft", "cottage", "mansion", "farmhouse", "cabin"]
            case .body: ["body", "health", "fit", "weight", "skin", "strong", "glow", "energy", "healthy"]
            case .confidence: ["confidence", "confident", "worthy", "self-love", "believe", "courage", "bold"]
            case .peace: ["peace", "calm", "anxiety", "stress", "rest", "sleep", "quiet", "healing", "heal"]
            case .travel: ["travel", "trip", "abroad", "beach", "island", "paris", "bali", "italy", "adventure"]
            case .family: ["family", "kids", "children", "baby", "pregnant", "mom", "dad", "sister", "brother", "friends"]
            case .general: []
            }
        }
    }

    static func category(for text: String) -> Category {
        let lower = " " + text.lowercased() + " "
        var best: (Category, Int) = (.general, 0)
        for category in Category.allCases {
            let hits = category.keywords.filter { lower.contains($0) }.count
            if hits > best.1 { best = (category, hits) }
        }
        return best.0
    }

    // MARK: Compose

    static func compose(desire: Desire, profile p: Profile, date: Date = .now) -> (title: String, text: String) {
        var rng = SeededRandom(seed: desire.id.uuidString + Day.key(date))
        let cat = category(for: desire.title + " " + desire.detail)
        let slots = Slots(profile: p)
        let blocked = p.neverInclude.map { $0.lowercased() }.filter { !$0.isEmpty }

        func pick(_ pool: [String], _ count: Int) -> [String] {
            let usable = pool
                .filter { slots.canFill($0) }
                .map { slots.fill($0) }
                .filter { line in !blocked.contains { line.lowercased().contains($0) } }
            return Array(rng.shuffled(usable).prefix(count))
        }

        var paragraphs: [[String]] = []
        paragraphs.append(pick(Pools.openings, 3))

        var middle = pick(Pools.byCategory[cat] ?? [], 4)
        if cat != .general { middle += pick(Pools.generalMiddle, 1) }
        if let line = slots.desireEcho(desire) { middle.insert(line, at: min(1, middle.count)) }
        paragraphs.append(middle)

        var people = pick(Pools.people, 2)
        if people.isEmpty { people = pick(Pools.solitude, 2) }
        paragraphs.append(people)

        var closing = pick(Pools.closings, 2)
        if let obstacle = slots.obstacleLine { closing.insert(obstacle, at: 0) }
        closing.append(slots.fill(rng.pick(Pools.finalLines)))
        paragraphs.append(closing)

        let text = paragraphs
            .filter { !$0.isEmpty }
            .map { $0.joined(separator: " ") }
            .joined(separator: "\n\n")
        let titlePool = (Pools.titles[cat] ?? Pools.titles[.general] ?? []).filter { slots.canFill($0) }
        let title = slots.fill(rng.pick(titlePool.isEmpty ? ["Everything I asked for is here"] : titlePool))
        return (title, text)
    }

    // MARK: Reflection

    static func reflection(answer: String, name: String, question: String) -> String {
        let short = answer.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let words = short.split(separator: " ").count
        let lowerQuestion = question.lowercased()
        let n = name.isEmpty ? "" : ", \(name)"
        if lowerQuestion.contains("hoping") {
            if words > 0 && words <= 5 {
                return "That desire for \(short.lowercased()) is so important\(n). Naming it is the first step toward living it."
            }
            return "Thank you for being so honest\(n). What you're hoping for is already starting to take shape."
        }
        if lowerQuestion.contains("why") {
            return "That makes so much sense\(n). Wanting this for yourself isn't too much. It's exactly enough."
        }
        return "I hear you\(n). Thank you for trusting me with that."
    }

    // MARK: Lifestyle tags

    static func lifestyleTags(for p: Profile) -> [String] {
        var tags: [String] = []
        let about = (p.about + " " + p.workFeeling).lowercased()
        let traits: [(String, String)] = [
            ("introvert", "Introvert"), ("extrovert", "Extrovert"), ("creative", "Creative soul"),
            ("small circle", "Small social circle"), ("ambitious", "Ambitious"), ("anxious", "Working on calm"),
            ("dog", "Dog lover"), ("cat", "Cat lover"), ("gym", "Gym regular"), ("yoga", "Yoga"),
            ("travel", "Loves to travel"), ("read", "Reader"), ("music", "Music lover"), ("cook", "Home cook"),
            ("building something", "Side project builder"), ("ready for something new", "Ready for a change"),
        ]
        for (needle, tag) in traits where about.contains(needle) { tags.append(tag) }
        if !p.work.isEmpty { tags.append(p.work.prefix(1).uppercased() + p.work.dropFirst()) }
        if !p.city.isEmpty { tags.append("\(p.city) resident") }
        if p.hasKids.lowercased() == "yes" { tags.append("Parent") }
        if !p.relationship.isEmpty { tags.append(p.relationship) }
        var seen = Set<String>()
        return tags.filter { seen.insert($0.lowercased()).inserted }
    }
}

// MARK: - Slots

private struct Slots {
    let values: [String: String]
    let obstacleLine: String?
    let money: String

    init(profile p: Profile) {
        func clean(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "."))) }
        var v: [String: String] = [:]
        v["name"] = p.firstName
        let place = clean(p.dreamLocation).isEmpty ? clean(p.city) : clean(p.dreamLocation)
        if !place.isEmpty { v["place"] = place }
        if !clean(p.homeType).isEmpty { v["home"] = clean(p.homeType).lowercased() }
        let work = clean(p.dreamCareer).isEmpty ? clean(p.work) : clean(p.dreamCareer)
        if !work.isEmpty, work.split(separator: " ").count <= 5 {
            let lower = work.lowercased()
            v["work"] = lower
            v["a_work"] = ("aeiou".contains(lower.first ?? "x") ? "an " : "a ") + lower
        }
        if let person = p.people.first {
            v["person"] = person.name
            v["relation"] = person.relation.lowercased()
        }
        if p.people.count > 1 { v["person2"] = p.people[1].name }
        if let kid = p.kids.first { v["kid"] = kid.name }

        let hasPartner = !clean(p.partner).isEmpty || ["relationship", "married", "engaged", "partner"].contains { p.relationship.lowercased().contains($0) }
        if hasPartner {
            v["love"] = "my love"
            let pronouns = Slots.partnerPronouns(gender: p.gender, sexuality: p.sexuality)
            v["their"] = pronouns.possessive
            v["them"] = pronouns.object
        }
        values = v

        let obstacle = clean(p.obstacle).lowercased()
        let words = obstacle.split(separator: " ").count
        obstacleLine = (words > 0 && words <= 4) ? "The \(obstacle) that used to stand in my way feels so far behind me now." : nil
        money = clean(p.dreamMoney)
    }

    /// Writes romance correctly from the user's gender and sexuality; falls back to "they".
    static func partnerPronouns(gender: String, sexuality: String) -> (object: String, possessive: String) {
        let g = gender.lowercased(), s = sexuality.lowercased()
        let isWoman = g.contains("woman") || g.contains("female") || g == "f"
        let isMan = !isWoman && (g.contains("man") || g.contains("male") || g == "m")
        let likesSame = s.contains("gay") || s.contains("lesbian") || s.contains("homo")
        let likesOther = s.contains("straight") || s.contains("hetero")
        switch (isWoman, isMan, likesSame, likesOther) {
        case (true, _, true, _): return ("her", "her")
        case (true, _, _, true): return ("him", "his")
        case (_, true, true, _): return ("him", "his")
        case (_, true, _, true): return ("her", "her")
        default: return ("them", "their")
        }
    }

    func canFill(_ template: String) -> Bool {
        var rest = template[...]
        while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
            let key = String(rest[rest.index(after: open)..<close])
            if values[key] == nil { return false }
            rest = rest[rest.index(after: close)...]
        }
        return true
    }

    func fill(_ template: String) -> String {
        var out = template
        for (key, value) in values {
            out = out.replacingOccurrences(of: "{\(key)}", with: value)
        }
        // Capitalise "my love" when it starts a sentence.
        if out.hasPrefix("my love") { out = "My love" + out.dropFirst("my love".count) }
        return out
    }

    func desireEcho(_ desire: Desire) -> String? {
        let detail = desire.detail.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        if !money.isEmpty, StoryComposer.category(for: desire.title + " " + detail) == .money {
            return "I remember writing down \"\(money)\" and thinking it was a fantasy. Now it is simply my life."
        }
        let words = detail.split(separator: " ").count
        guard words >= 2, words <= 14 else { return nil }
        return "I once wrote down \"\(detail)\" and wondered if it was too much to ask for. It wasn't."
    }
}

// MARK: - Seeded randomness (stable per desire per day)

private struct SeededRandom {
    private var state: UInt64

    init(seed: String) {
        var h: UInt64 = 0xcbf29ce484222325
        for byte in seed.utf8 { h = (h ^ UInt64(byte)) &* 0x100000001b3 }
        state = h
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func pick<T>(_ items: [T]) -> T {
        items[Int(next() % UInt64(items.count))]
    }

    mutating func shuffled<T>(_ items: [T]) -> [T] {
        var a = items
        guard a.count > 1 else { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            let j = Int(next() % UInt64(i + 1))
            a.swapAt(i, j)
        }
        return a
    }
}

// MARK: - Sentence pools

private enum Pools {
    static let openings = [
        "It's early morning in {place}, and the light comes in soft and gold through the windows.",
        "I wake before my alarm, rested in a way I used to only dream about.",
        "The air smells like salt and fresh coffee, and somewhere outside a bird is singing.",
        "I pad barefoot across warm floors and open the doors to let the morning in.",
        "Evening settles over {place}, and the sky slowly turns the color of peaches.",
        "I stand at the window of my {home} with a warm cup between my hands.",
        "Everything in this room is something I chose, and every corner of it feels like me.",
        "There's music playing low in the kitchen, and nothing in my body is in a hurry.",
        "Sunlight spills across the bed, and I stretch slowly, smiling before I even open my eyes.",
        "Outside, {place} is waking up, and I get to watch it from my favorite spot.",
        "A soft breeze moves the curtains, and I can hear the world going gently about its day.",
    ]

    static let generalMiddle = [
        "I notice how light I feel, as if I set down something heavy a long time ago.",
        "Life feels easy in the best way, full and unhurried.",
        "I keep catching myself smiling for no particular reason.",
    ]

    static let byCategory: [StoryComposer.Category: [String]] = [
        .love: [
            "{love} comes up behind me and wraps both arms around my waist, resting a chin on my shoulder.",
            "I feel completely chosen, not for who I pretend to be, but for exactly who I am.",
            "We laugh about something small, and the sound fills the whole kitchen.",
            "There's no guessing anymore, no waiting by my phone, no shrinking myself to be easier to love.",
            "I catch {love} looking at me across the table like I'm the best part of the day.",
            "Being loved like this feels calm. It feels safe. It feels like coming home.",
            "We plan the weekend together, and I notice how easy it is to ask for what I want.",
            "I reach for {their} hand without thinking, and {their} fingers close around mine.",
            "Every day with {them} feels like a quiet yes.",
        ],
        .money: [
            "I open my banking app out of habit and smile, because the number there no longer frightens me.",
            "Money arrives easily now, from places I expected and places I didn't.",
            "I pay every bill the moment it lands and still have more than enough left over.",
            "Earlier today I booked the trip I kept saying someday about, and I didn't check the price twice.",
            "I give generously, and it feels just as good as receiving.",
            "There's a calm in my chest where the money worries used to live.",
            "I say yes to the things I love without doing math in my head first.",
        ],
        .career: [
            "Working as {a_work} feels like a natural extension of who I am.",
            "This morning's meeting went better than I imagined, and people leaned in when I spoke.",
            "An email lands in my inbox with an offer I would once have called impossible.",
            "I close my laptop at a reasonable hour, proud of what I made today.",
            "I'm respected for my ideas, and I'm paid beautifully for them.",
            "The thing I used to build quietly on the side now supports my whole life.",
            "Clients find me easily, and they're exactly the people I love working with.",
        ],
        .home: [
            "I walk through my {home} and still can't quite believe it's mine.",
            "Light pours across the floors, and the space is quiet, clean and full of things I love.",
            "My keys sit in a little dish by the door, and every time I see them I feel a flutter of gratitude.",
            "I curl into my favorite chair by the window and look out at the view I used to save as my wallpaper.",
            "Fresh flowers stand on the counter, and the whole place smells like home.",
            "I finally have room for everything, including room to breathe.",
        ],
        .body: [
            "I move through my morning in a body that feels strong, light and completely mine.",
            "I catch my reflection on the way past the mirror and smile at what I see.",
            "My skin is clear, my breath is deep, and my energy lasts the whole day.",
            "I eat food that loves me back, and I move because it feels good.",
            "My muscles are warm from a morning walk, and my mind is clear.",
            "I feel at home in my body, and I treat it with so much kindness.",
        ],
        .confidence: [
            "I walk into the room and I don't make myself smaller.",
            "When I speak, my voice is steady, and I mean every word.",
            "I say no without apologizing and yes without hesitating.",
            "Other people's opinions pass through me like weather. I stay rooted.",
            "I trust myself completely now, and it shows in everything I do.",
            "I wear what I love, say what I think, and take up the space that's mine.",
        ],
        .peace: [
            "My mind is quiet in a way I used to only feel on holiday.",
            "Nothing is pulling at me. I'm not bracing for anything.",
            "I breathe in slowly and notice that my shoulders are soft and low.",
            "I have time. I have space. I have enough.",
            "My days have a gentle rhythm now, and I protect it without guilt.",
            "When something hard comes up, I meet it calmly and let it pass.",
        ],
        .travel: [
            "I step outside and the warm air of {place} wraps around me like a hug.",
            "My passport is full of stamps from places I once only pinned to a board.",
            "Tonight I'll eat dinner by the water and watch the sky go pink.",
            "I wander streets I've never walked before, and everything feels like an adventure.",
            "I travel because I want to, and I come home because I love my life there too.",
        ],
        .family: [
            "The people I love are healthy, happy and close.",
            "The house is full of laughter, and I soak in every second of it.",
            "We sit around the table for a long, lazy breakfast with nowhere else to be.",
            "I feel so supported, and I know they feel supported by me.",
        ],
        .general: [
            "I look around and realize I'm living the life I used to write about in my journal.",
            "Things that once felt out of reach are simply part of my days now.",
            "I trust the timing of my life, and it keeps proving me right.",
            "Every choice I make comes from love instead of fear.",
        ],
    ]

    static let people = [
        "Later, {person} stops by, and we hug a little longer than usual.",
        "{person} looks at me and says, \"{name}, look at you,\" and this time I let myself hear it.",
        "I send a voice note to {person}, my {relation}, just to say thank you for always believing in me.",
        "{person} and I sit outside until the stars come out, talking about everything and nothing.",
        "My phone lights up with a message from {person}: \"So proud of you.\"",
        "I hear {kid} laughing in the next room, and my whole heart softens.",
        "{person} and {person2} are coming over tonight, and the table is already set for everyone.",
    ]

    static let solitude = [
        "I spend the afternoon exactly how I want, and I enjoy my own company completely.",
        "I call someone I love just to hear their voice, and we laugh like no time has passed.",
    ]

    static let closings = [
        "This is my life now. I don't have to chase it. I only have to keep saying yes.",
        "I am exactly where I'm meant to be.",
        "Everything I asked for is already on its way to me, and so much of it is already here.",
        "I close my eyes and feel it fully: I did it. I'm living it.",
        "I don't need to hold on tightly. It's mine, and it's staying.",
        "The version of me I used to dream about is simply who I am today.",
    ]

    static let finalLines = [
        "Thank you, I whisper, to no one and to everything.",
        "And it all feels so natural, because it was always meant for me.",
        "I smile, {name}, because this is only the beginning.",
        "I take a slow breath and let the gratitude settle all the way in.",
    ]

    static let titles: [StoryComposer.Category: [String]] = [
        .love: ["I am loved exactly as I am", "My love holds me close", "We laugh in the kitchen"],
        .money: ["Money flows to me with ease", "I book it without a second thought", "The number no longer scares me"],
        .career: ["I'm paid beautifully for work I love", "The offer I always wanted", "They lean in when I speak"],
        .home: ["I wake up in my {home}", "The keys are finally mine", "Light pours across my floors"],
        .body: ["I feel at home in my body", "Strong, light and fully mine", "I smile at my reflection"],
        .confidence: ["I walk in and take up space", "My voice is steady", "I trust myself completely"],
        .peace: ["My mind is finally quiet", "I have time, I have space", "Soft shoulders, slow breath"],
        .travel: ["I wake up in {place}", "Dinner by the water", "Stamps in my passport"],
        .family: ["A long, lazy breakfast together", "Laughter fills the house"],
        .general: ["Everything I asked for is here", "I'm living the life I wrote about", "This is only the beginning"],
    ]
}
