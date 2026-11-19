import SwiftUI

struct OnboardingStep {
    enum Kind {
        case notifications
        case referral
        /// Solenne says something; the user taps to continue.
        case message
        case text(WritableKeyPath<Profile, String>, placeholder: String, keyboard: UIKeyboardType = .default, optional: Bool = false)
        case choice(WritableKeyPath<Profile, String>, options: [String], allowsText: Bool = false, placeholder: String = "")
        case people
        /// Solenne reflects the given answer back in one warm sentence.
        case reflect(WritableKeyPath<Profile, String>)
    }

    let prompt: (Profile) -> String
    let kind: Kind
    var isIncluded: (Profile) -> Bool = { _ in true }

    init(_ prompt: @escaping (Profile) -> String, _ kind: Kind, if isIncluded: @escaping (Profile) -> Bool = { _ in true }) {
        self.prompt = prompt
        self.kind = kind
        self.isIncluded = isIncluded
    }

    init(_ prompt: String, _ kind: Kind, if isIncluded: @escaping (Profile) -> Bool = { _ in true }) {
        self.init({ _ in prompt }, kind, if: isIncluded)
    }
}

enum OnboardingScript {
    static let homeTypes = [
        "Luxury Penthouse", "Beachfront Villa", "Modern Loft", "Cozy Cottage",
        "Suburban Mansion", "Farmhouse", "Cabin", "Tiny Home",
    ]

    private static func isPartnered(_ p: Profile) -> Bool {
        let r = p.relationship.lowercased()
        return r.contains("relationship") || r.contains("married") || r.contains("engaged")
    }

    static let steps: [OnboardingStep] = [
        OnboardingStep("Solenne works best with a gentle nudge each day.", .notifications),
        OnboardingStep("Did someone invite you?", .referral),
        OnboardingStep("Hi, I'm Solenne.\n\nThis is your quiet place to picture the life you're calling in, and to start living it.", .message),
        OnboardingStep("Before we begin, I'd love to get to know you.\n\nThe more open you are, the more your stories will sound like your life.", .message),
        OnboardingStep("First, what should I call you?", .text(\.name, placeholder: "Your name")),
        OnboardingStep({ "Lovely to meet you, \($0.firstName). Where are you living right now?" }, .text(\.city, placeholder: "City")),
        OnboardingStep("How old are you?", .text(\.age, placeholder: "Age", keyboard: .numberPad)),
        OnboardingStep("How do you identify?", .choice(\.gender, options: ["Woman", "Man", "Non-binary"], allowsText: true, placeholder: "Or describe it in your words")),
        OnboardingStep("What's your sexuality? It helps me write love the way you'd feel it.", .text(\.sexuality, placeholder: "e.g. straight, gay, bisexual…")),
        OnboardingStep("Do you have kids?", .choice(\.hasKids, options: ["Yes", "No"])),
        OnboardingStep({ "\($0.firstName), what are you hoping will change in your life right now?" }, .text(\.hopingChanges, placeholder: "Love, confidence, peace…")),
        OnboardingStep("", .reflect(\.hopingChanges)),
        OnboardingStep("Why does that matter so much to you right now?", .text(\.whyNow, placeholder: "Take your time")),
        OnboardingStep("", .reflect(\.whyNow)),
        OnboardingStep("What feels like the biggest thing standing in your way?", .text(\.obstacle, placeholder: "Doubt, timing, money, fear…")),
        OnboardingStep("What's your relationship status?", .choice(\.relationship, options: ["Single", "In a relationship", "Married", "It's complicated"])),
        OnboardingStep("Who are the people I should know matter most to you?", .people),
        OnboardingStep("What do you do for work?", .text(\.work, placeholder: "Student, nurse, founder, designer…")),
        OnboardingStep("How do you feel about your work?", .choice(\.workFeeling, options: ["I love it", "It's fine for now", "I'm ready for something new", "I'm building something on the side"])),
        OnboardingStep({ "Since we're only just meeting, \($0.firstName), what should I know to understand you better?" }, .text(\.about, placeholder: "How would you describe yourself?")),
        OnboardingStep("Is there anything from your past that still shapes what you want today?", .text(\.past, placeholder: "Only share what feels right", optional: true)),
        OnboardingStep({ "Now dream a little bigger, \($0.firstName).\n\nDon't be realistic. Don't hold back." }, .message),
        OnboardingStep("In your dream life, where do you wake up?", .text(\.dreamLocation, placeholder: "A city, a coastline, a country…")),
        OnboardingStep("What kind of home are you living in?", .choice(\.homeType, options: homeTypes)),
        OnboardingStep({ "\($0.firstName), what kind of partner are you calling in?" }, .text(\.partner, placeholder: "How should they make you feel?", optional: true), if: { !isPartnered($0) }),
        OnboardingStep("In your dream life, how does your partner make you feel?", .text(\.partner, placeholder: "Seen, safe, adored…", optional: true), if: { isPartnered($0) }),
        OnboardingStep("What does your work look like in this life?", .text(\.dreamCareer, placeholder: "What you do, who you do it with…", optional: true)),
        OnboardingStep("And money. How much is flowing to you?", .text(\.dreamMoney, placeholder: "$20k months, no debt, a paid-off home…", optional: true)),
        OnboardingStep("How do you feel in your body?", .text(\.dreamBody, placeholder: "Strong, rested, glowing…", optional: true)),
        OnboardingStep("Last one. Describe a perfect, ordinary day in that life.", .text(\.dreamDay, placeholder: "From the moment you wake up…", optional: true)),
    ]
}
