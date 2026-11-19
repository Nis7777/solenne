import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Produces stories, reflections and tags. Tries, in order:
/// 1. the Supabase backend (Claude for text, ElevenLabs for voice), when configured;
/// 2. Apple's on-device model (iOS 26+, Apple Intelligence enabled);
/// 3. the local `StoryComposer`, so the app always works offline.
enum StoryEngine {
    /// Stories generated per daily refresh.
    static let dailyCount = 3

    static func story(for desire: Desire, profile: Profile, voiceID: String) async -> Story {
        if Backend.isConfigured {
            do {
                let result = try await Backend.generateStory(profile: profile, desire: desire, voiceID: voiceID)
                return Story(title: result.title, text: result.text, theme: desire.theme,
                             desireID: desire.id, audioURL: result.audioURL)
            } catch {
                print("Backend story failed, falling back:", error)
            }
        }

        if OnDeviceModel.isAvailable,
           let raw = try? await OnDeviceModel.respond(instructions: Prompting.storyInstructions,
                                                      prompt: Prompting.storyPrompt(profile: profile, desire: desire)),
           let parsed = Prompting.parseStory(raw) {
            return Story(title: parsed.title, text: parsed.text, theme: desire.theme, desireID: desire.id)
        }

        let composed = StoryComposer.compose(desire: desire, profile: profile)
        return Story(title: composed.title, text: composed.text, theme: desire.theme, desireID: desire.id)
    }

    /// One warm sentence that reflects an onboarding answer back to the user.
    static func reflection(question: String, answer: String, name: String) async -> String {
        if Backend.isConfigured, let text = try? await Backend.reflect(question: question, answer: answer, name: name) {
            return text
        }
        if OnDeviceModel.isAvailable,
           let text = try? await OnDeviceModel.respond(
               instructions: Prompting.reflectionInstructions,
               prompt: "Question: \(question)\nTheir answer: \(answer)\nTheir name: \(name)"
           ) {
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"")))
            if !clean.isEmpty { return clean }
        }
        return StoryComposer.reflection(answer: answer, name: name, question: question)
    }

    static func lifestyleTags(for profile: Profile) async -> [String] {
        if Backend.isConfigured, let tags = try? await Backend.lifestyleTags(profile: profile), !tags.isEmpty {
            return tags
        }
        return StoryComposer.lifestyleTags(for: profile)
    }
}

// MARK: - Prompts (on-device; the backend keeps its own copy server-side)

enum Prompting {
    static let storyInstructions = """
    You are Solenne, a warm manifestation guide. You write short vision stories the listener plays every day.
    Rules: first person ("I"), present tense, as if the dream is already real. Sensory and specific: light, sound, \
    smell, touch. Calm, intimate, hopeful. No therapy talk, no lists, no hashtags, no emojis. \
    About 300 words in 3 or 4 short paragraphs. Use details from the profile naturally; never invent names that \
    were not given. Never mention anything in the "never include" list.
    Output format: the first line is a title of at most 9 words in first person (e.g. "I watch the fog roll past my balcony"). \
    Then a blank line. Then the story.
    """

    static let reflectionInstructions = """
    You are Solenne, a warm manifestation guide. Reply with exactly one or two short, warm sentences that reflect \
    the person's answer back to them and use their name once. No questions, no advice, no emojis.
    """

    static func profileSummary(_ p: Profile) -> String {
        var lines: [String] = []
        func add(_ label: String, _ value: String) {
            let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { lines.append("\(label): \(v)") }
        }
        add("Name", p.firstName)
        add("Age", p.age)
        add("Gender", p.gender)
        add("Sexuality", p.sexuality)
        add("Lives in", p.city)
        add("Relationship", p.relationship)
        add("Has kids", p.hasKids)
        add("Kids", p.kids.map(\.name).joined(separator: ", "))
        add("Important people", p.people.map { "\($0.name) (\($0.relation))" }.joined(separator: ", "))
        add("Work", p.work)
        add("Feels about work", p.workFeeling)
        add("Hoping changes", p.hopingChanges)
        add("Why now", p.whyNow)
        add("In the way", p.obstacle)
        add("About them", p.about)
        add("Past", p.past)
        add("Dream location", p.dreamLocation)
        add("Dream home", p.homeType)
        add("Dream partner", p.partner)
        add("Dream career", p.dreamCareer)
        add("Dream money", p.dreamMoney)
        add("Dream body", p.dreamBody)
        add("Dream day", p.dreamDay)
        add("Lifestyle", p.lifestyleTags.joined(separator: ", "))
        add("Notes for stories", p.notes.joined(separator: " | "))
        return lines.joined(separator: "\n")
    }

    static func storyPrompt(profile: Profile, desire: Desire) -> String {
        """
        Profile:
        \(profileSummary(profile))

        Never include: \(profile.neverInclude.isEmpty ? "nothing specific" : profile.neverInclude.joined(separator: ", "))

        Write today's vision story for this desire: \(desire.title). \(desire.detail)
        """
    }

    static func parseStory(_ raw: String) -> (title: String, text: String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let split = trimmed.range(of: "\n") else { return nil }
        let title = trimmed[..<split.lowerBound]
            .trimmingCharacters(in: CharacterSet(charactersIn: "#*\" ").union(.whitespaces))
        let text = trimmed[split.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, text.split(separator: " ").count > 60 else { return nil }
        return (title, text)
    }
}

// MARK: - Apple on-device model

enum OnDeviceModel {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    static func respond(instructions: String, prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            return response.content
        }
        #endif
        throw CancellationError()
    }
}

// MARK: - Desires

enum DesireSeeder {
    /// Turns onboarding answers into the first set of desires.
    static func desires(from p: Profile) -> [Desire] {
        var result: [Desire] = []
        func clean(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }

        if !clean(p.hopingChanges).isEmpty {
            let title = clean(p.hopingChanges).prefix(1).uppercased() + clean(p.hopingChanges).dropFirst()
            result.append(desire(title: String(title.prefix(48)), detail: clean(p.whyNow)))
        }
        if !clean(p.homeType).isEmpty || !clean(p.dreamLocation).isEmpty {
            let home = clean(p.homeType).isEmpty ? "dream home" : clean(p.homeType)
            let place = clean(p.dreamLocation).isEmpty ? "" : " in \(clean(p.dreamLocation))"
            result.append(Desire(title: "My \(home.lowercased())\(place)", detail: "The home I'm calling in.", theme: .dawn))
        }
        if !clean(p.partner).isEmpty {
            result.append(Desire(title: "Deep, easy love", detail: clean(p.partner), theme: .rose))
        }
        if !clean(p.dreamCareer).isEmpty {
            result.append(Desire(title: "My dream work", detail: clean(p.dreamCareer), theme: .city))
        }
        if !clean(p.dreamMoney).isEmpty {
            result.append(Desire(title: "Abundance", detail: clean(p.dreamMoney), theme: .golden))
        }
        if !clean(p.dreamBody).isEmpty {
            result.append(Desire(title: "At home in my body", detail: clean(p.dreamBody), theme: .forest))
        }
        if result.isEmpty {
            result.append(Desire(title: "My dream life", detail: "Everything I'm calling in.", theme: .ocean))
        }
        return result
    }

    static func desire(fromWish wish: String) -> Desire {
        let title = wish.count > 48 ? String(wish.prefix(46)) + "…" : wish
        return desire(title: title.prefix(1).uppercased() + title.dropFirst(), detail: wish)
    }

    static func desire(title: String, detail: String) -> Desire {
        let category = StoryComposer.category(for: title + " " + detail)
        return Desire(title: title, detail: detail, theme: category.theme)
    }
}
