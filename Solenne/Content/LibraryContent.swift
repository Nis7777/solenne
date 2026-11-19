import Foundation

/// Bundled, original library content. Generated stories live in AppData; these ship with the app.
enum LibraryContent {
    static let trending: [Story] = [
        story("trending-1", "I am a money magnet", .golden, """
        I wake up in soft linen sheets, and the first thing I feel is ease. There is nothing to worry about this morning. My accounts are full, my bills are paid, and money keeps finding its way to me.

        I make coffee slowly and check my messages. Another payment has come through, and I smile, because this has become normal. I used to hold my breath every time I looked at my balance. Now I breathe all the way out.

        I spend the afternoon on work I love, and I'm paid beautifully for it. I treat myself to something I have wanted for a long time, and I don't feel guilty. I feel grateful. I give generously to the people around me, and it comes back to me multiplied.

        Money is safe with me. I respect it, I enjoy it, and it loves to stay. I am a magnet for abundance, and today is proof.
        """),
        story("trending-2", "He looks at me like I'm the answer", .rose, """
        The restaurant is warm and candlelit, and I can hear the soft clink of glasses all around us. Across the table, he's watching me tell a story, and he isn't checking his phone. He's completely here.

        I feel beautiful, not because of the dress, but because of the way I'm being seen. He laughs at exactly the right moment and reaches over to tuck my hair behind my ear.

        Walking home, his hand finds mine without either of us thinking about it. There's no anxiety in my chest, no wondering where I stand. I know. I'm chosen, steadily and openly, every single day.

        At my door he kisses me goodnight, slow and sure, and I go inside smiling. Love like this was always meant for me.
        """),
        story("trending-3", "The fog rolls past my balcony", .ocean, """
        I stand barefoot on my balcony as the fog drifts in from the ocean, soft and silver over the water. The air is cool and smells of salt. Below me the waves move in their slow, easy rhythm.

        This is my home now. The one I used to save photos of. Inside, everything is calm and clean and chosen by me. A candle is burning on the counter, and my favorite record is playing low.

        I wrap a blanket around my shoulders and sip my tea. Nothing is rushing me. My work fits around my life, not the other way around. I have time to watch the weather change.

        I take a deep breath and let it all sink in. I did this. I'm here. And it feels even better than I imagined.
        """),
        story("trending-4", "I get paid to be myself", .city, """
        My phone lights up with another notification, a new client who found me through a friend. I don't have to chase opportunities anymore. They arrive because people love what I do.

        I walk to my studio through busy morning streets, coffee in hand, feeling completely myself. The work I create is honest and fresh, and people pay me well for exactly that.

        In my meeting, I share an idea and the room goes quiet, then lights up. Someone says, this is exactly what we needed. I smile, because I knew it was.

        By evening I close my laptop, proud and unhurried. My career fits me like it was tailored. I get paid to be myself, and I always will.
        """),
    ]

    static let affirmationTracks: [Story] = [
        affirmations("aff-1", "He is obsessed with me", .rose, [
            "I am easy to love.", "I am adored exactly as I am.", "My person thinks about me all the time.",
            "I am the one they choose, again and again.", "Love feels safe and calm to me.",
            "I receive affection without questioning it.", "I am deeply, openly wanted.",
            "Being with me feels like home.",
        ]),
        affirmations("aff-2", "I'm the luckiest person I know", .golden, [
            "Good things find me everywhere I go.", "I am always in the right place at the right time.",
            "Luck follows me around like sunshine.", "Unexpected blessings arrive for me daily.",
            "Doors open for me before I even knock.", "I expect miracles, and they show up.",
        ]),
        affirmations("aff-3", "I get paid to exist", .golden, [
            "Money comes to me easily and often.", "I am paid well for being myself.",
            "My income grows while I rest.", "I am a magnet for wealth and opportunity.",
            "Abundance is my natural state.", "I always have more than enough.",
        ]),
        affirmations("aff-4", "I am a successful founder", .city, [
            "My business grows every single day.", "Customers love what I make.",
            "I make bold decisions with a calm mind.", "The right people want to work with me.",
            "My ideas are valuable, and the world is ready for them.", "I lead with clarity and kindness.",
        ]),
        affirmations("aff-5", "I have my dream body", .forest, [
            "My body is strong, healthy and full of energy.", "I love the way I look and feel.",
            "I treat my body with kindness.", "Every day I feel lighter and more alive.",
            "I glow from the inside out.", "My body knows how to heal and thrive.",
        ]),
        affirmations("aff-6", "It is safe for me to receive", .dawn, [
            "I am allowed to have good things.", "I open my hands and let life give to me.",
            "I deserve rest, love and ease.", "It is safe for me to be seen.",
            "I let go of what was and welcome what's coming.", "I am worthy, simply because I exist.",
        ]),
    ]

    static let sleepTracks: [Story] = [
        story("sleep-1", "Listen before you go to bed", .midnight, """
        Let your body grow heavy against the bed. Let your jaw soften. Let your shoulders drop away from your ears.

        Tonight there is nothing left to do. Everything that needed you today has been handled, or it can wait until morning. Right now, you are only here, breathing slowly.

        Imagine waking tomorrow inside the life you've been calling in. The light is soft. The room is calm. You feel rested in a deep, new way. Something good is already waiting for you.

        Breathe in, and feel that you are safe. Breathe out, and let the day go. You are exactly where you need to be. Sleep now, and let your dreams do the work.
        """),
        story("sleep-2", "A slow walk along the shore", .ocean, """
        Picture a quiet beach at dusk. The sand is cool and soft beneath your feet, and the water comes in slow, silver waves.

        With every step, you leave something behind. The worry from this afternoon. The conversation you keep replaying. The list of things to do. The tide carries each one gently away.

        The sky turns lavender, then deep blue. The first stars appear, one by one. You sit down on the warm sand and listen to the steady hush of the water.

        Everything you want is moving toward you, even now, even as you rest. You don't have to hold it. You only have to sleep.
        """),
        story("sleep-3", "The cabin in the snow", .forest, """
        Snow is falling softly outside the window of a small wooden cabin. Inside, a fire crackles, and the air smells of cedar and warm tea.

        You are wrapped in a thick blanket, and your body feels warm all the way through. There is nowhere you need to be. The whole world has gone quiet under the snow.

        Let your breathing slow to match the falling flakes. In, and out. In, and out. Each breath makes you a little heavier, a little calmer.

        You are safe. You are held. Tomorrow will be kind to you. For now, just drift.
        """),
    ]

    static var all: [Story] { trending + affirmationTracks + sleepTracks }

    private static func story(_ key: String, _ title: String, _ theme: CoverTheme, _ text: String, kind: StoryKind = .vision) -> Story {
        Story(id: UUID.stable(key), title: title, text: text, theme: theme,
              kind: key.hasPrefix("sleep") ? .sleep : kind,
              createdAt: Date(timeIntervalSince1970: 1_767_225_600))
    }

    private static func affirmations(_ key: String, _ title: String, _ theme: CoverTheme, _ lines: [String]) -> Story {
        // Each affirmation is repeated so it can sink in.
        let text = lines.map { "\($0) \($0)" }.joined(separator: "\n\n")
        return Story(id: UUID.stable(key), title: title, text: text, theme: theme, kind: .affirmation,
                     createdAt: Date(timeIntervalSince1970: 1_767_225_600))
    }
}

/// Daily affirmation cards: a fresh deck each day, chosen from this pool.
enum AffirmationDeck {
    struct Card: Hashable {
        let text: String
        let anchor: String
    }

    static let pool: [Card] = [
        Card(text: "I trust my inner voice completely and walk into every room with quiet certainty.", anchor: "my confidence is natural"),
        Card(text: "I am worthy of deep peace, and I let joy move through my life with ease.", anchor: "I embody inner calm"),
        Card(text: "I honor my quiet nature as a source of wisdom and true self-expression.", anchor: "my softness is my strength"),
        Card(text: "I celebrate my own way of seeing the world and share it without apology.", anchor: "my creativity is my power"),
        Card(text: "Money flows to me easily, and I receive it with gratitude.", anchor: "abundance is my birthright"),
        Card(text: "I am loved in a way that feels safe, steady and true.", anchor: "love is easy for me"),
        Card(text: "My body is my home, and I treat it with tenderness.", anchor: "I glow from within"),
        Card(text: "I let go of what was, and I open my arms to what is coming.", anchor: "I am ready"),
        Card(text: "Every small step I take is building the life I dream about.", anchor: "I am becoming"),
        Card(text: "I am allowed to rest. My worth was never measured by how busy I am.", anchor: "rest is productive"),
        Card(text: "The right people, places and chances are finding their way to me.", anchor: "I am aligned"),
        Card(text: "I speak kindly to myself, and I believe what I say.", anchor: "I am my own best friend"),
        Card(text: "My future is bright, and I walk toward it with an open heart.", anchor: "the best is ahead"),
        Card(text: "I release comparison. My path is mine, and it is beautiful.", anchor: "I trust my timing"),
        Card(text: "I attract opportunities that fit who I truly am.", anchor: "I am magnetic"),
        Card(text: "I give myself permission to want more and to receive it.", anchor: "I deserve good things"),
        Card(text: "I am safe in my body, in my home and in my life.", anchor: "I am held"),
        Card(text: "I choose thoughts that make me feel expansive and free.", anchor: "my mind is my garden"),
        Card(text: "I am proud of how far I've come, and excited for where I'm going.", anchor: "I am growing"),
        Card(text: "Good things happen to me, often and unexpectedly.", anchor: "I am lucky"),
        Card(text: "My dreams are not too big. They are exactly my size.", anchor: "I think bigger"),
    ]

    static let perDay = 5

    /// A stable deck for the given day.
    static func deck(for day: String = Day.key()) -> [Card] {
        var h: UInt64 = 1469598103934665603
        for b in day.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        let start = Int(h % UInt64(pool.count))
        return (0..<perDay).map { pool[(start + $0 * 4) % pool.count] }
    }
}
