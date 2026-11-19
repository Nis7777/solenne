# Solenne: AI manifestation app (build brief for Claude Code)

> Working name: **Solenne**. Reference app: **Stella – Manifest Anything** (by Appllama).
> Everything in `screenshots/`, `onboarding-frames/` and `stella-onboarding-video.mp4` is **reference material from Stella**.
> Use it for structure, flow, and feel. **Do not copy Stella's name, logo, llama mascot, or copy text word for word.** Write our own.

---

## 1. What the app is

A personalised manifestation app. The user tells the AI guide about their life and their dream life.
The app then generates **short first-person "vision stories"** ("I watch my golden retriever sprint across the sand…"),
narrated by an AI voice (or the user's **own cloned voice**), with a cover image, played daily.
Retention comes from a **21-day listening streak**, daily reminders, affirmations and journaling.

The AI guide is a character. Stella calls it "Stella"; ours is **Solenne**. It always speaks warmly, in short lines, and uses the user's name.

## 2. Folder contents

| Path | What it is |
|---|---|
| `stella-onboarding-video.mp4` | Full screen recording of Stella's onboarding (3m50s) |
| `onboarding-frames/01–28` | Key frames from that video, in order (same flow as section 4) |
| `screenshots/01–16` | Every main screen of the app, grouped by feature (section 5) |

## 3. Visual design system

- **Background:** soft vertical gradient, cream/peach at the top (`#F8EDE6`) to dusty pink at the bottom (`#E2A9BF`). It's used on every screen.
- **Primary colour:** deep plum/burgundy (`#5A2338`) for primary buttons ("I'm in", "remind me every day"). Muted mauve (`#9E6F82`) for secondary buttons and sheets.
- **Surfaces:** frosted glass cards (white at about 50–60% opacity plus blur), large radii (20–28 px), very soft shadows.
- **Type:**
  - Headings use a condensed editorial serif, with *italic* for the emotional word ("what do you want to *manifest?*", "when should i *remind you?*"). Good free options: Instrument Serif, Playfair Display or Cormorant.
  - Body and UI text use a clean geometric sans (Inter, or Plus Jakarta Sans).
  - Small labels are uppercase with wide letter-spacing ("DAILY REFRESH IN", "COME BACK ONCE DAILY").
- **Signature elements:**
  - A glossy pink **orb** is the AI avatar on Home and in loading states.
  - A pink **flame** marks the streak.
  - Floating pill-shaped **tab bar**: Home · Library · Affirmations (star) · Profile.
- **Story player:** full-bleed blurred cover image, a dark overlay, and large serif text lines that change with the narration (karaoke-style).
- **Motion:** onboarding questions **type in letter by letter**. Cards stack and swipe. Sheets slide up from the bottom.
- Lower-case, intimate microcopy in places ("listen daily. keep the flame.").

## 4. Onboarding flow (from the video; follow `onboarding-frames/` in order)

A conversational, one-question-per-screen chat. The question types in, and the answer field sits above the keyboard with a send arrow. A thin progress bar is at the top, with a back arrow.

1. Notification permission pre-prompt ("works better with notifications").
2. Referral code: paste / enter manually / "I don't have a code" (with a Skip option).
3. Welcome. "Hello! Welcome to ___. This is your space to manifest the life of your dreams."
4. "Before we begin, I have a few important questions… the more honest you are, the more personal ___ can feel."
5. **Name.**
6. **Where do you live?**
7. **Age / gender** (quick screens).
8. **Sexuality** (free text with examples). This is used to write romance stories correctly.
9. **Do you have kids?** Yes/No chips.
10. **"{Name}, what are you hoping changes in your life right now?"** (placeholder: "Love, confidence, peace…").
    → The **AI reflects the answer back** in one warm sentence ("That desire for confidence is so important, {Name}…").
11. **"Why does this matter so much to you right now?"** → AI reflection again.
12. **"What feels like the biggest thing standing in your way?"** (doubt, timing, money, fear…).
13. **Relationship status.**
14. **"Who are the people ___ should know matter most to you?"** Use the Add Person bottom sheet (name + description such as "best friend", "sister"). Show a list and a Continue button.
15. **Work:** "What do you do for work?", then "How do you feel about your work?"
16. **"Since we've never met, what should I know about you to understand you better?"**
17. **"Is there anything from your past that still shapes what you want today?"** (optional; placeholder "Only share what feels relevant").
18. Transition: **"Now dream a little bigger, {Name}. Don't be realistic. Don't hold back."**
19. Dream life: **where are you living?**, **home type** chips (Luxury Penthouse, Beachfront Villa, Modern Loft, Cozy Cottage, Suburban Mansion, Farmhouse, Cabin, Tiny Home), **ideal partner**, and more dream questions (career, money, body, lifestyle).
20. Loading skeleton ("Making your stories… your visions are taking shape"), then **Home**, with the first stories already generated.

(Paywall: Stella shows "Unlock Pro" around this point. Put a RevenueCat paywall after onboarding, before or after the first story plays.)

All answers are saved to the **user profile**. The profile is the context for every generated story.

## 5. Screens and features (see `screenshots/`)

1. **Content discovery** (`01`)
   - **Home:** orb, "{Name}, what do you want to *manifest?*" input, a 21-day challenge banner, and a "For you" carousel of story cards with an Edit desires button.
   - **For You:** one big card plus a "DAILY REFRESH IN 04:11:32" countdown, since new stories arrive every 24h.
   - **Story Exploration:** swipeable vision cards ("Swipe to the vision you want to *step into*…").
   - **Library:** Trending, Affirmations, Songs and Sleep tracks rows.
2. **Story creation** (`02`): "What are you calling in?" sheet, where the user describes a new desire. Then a "Making your stories" loader.
3. **Story playback** (`03`)
   - Immersive intro ("Stepping into tonight's story… 25%").
   - **Audio player:** big serif line of the current sentence, a scrolling transcript strip, scrubber, like, ±10s, play/pause, background music toggle, and Share.
   - **"Something sound off?"** feedback sheet, which saves a preference for future stories.
   - **Reading view:** full text with the cover image, plus a bookmark.
4. **Sharing** (`04`): a share card (quote on the blurred cover) → Copy link / Instagram Stories / Messages / Save image.
5. **21-day challenge** (`05`): intro ("listen daily. keep the flame.") → Day 1 card → progress screen (flame + streak count, week dots, days this month, longest streak, calendar).
6. **Daily reminders** (`06`): choose a time (morning 8:00 / lunch 12:30 / golden 6:30 / sleep 9:30), with a preview of the notification.
7. **Desires** (`07`): "Your desires" list of cards (title + description + image, with edit/delete). Add desire.
8. **Voice selection** (`08`): "Clone your own voice" plus about 7 curated voices, each with a preview.
9. **Voice cloning** (`09`): mic permission → tips → record about 10s → trim and review → "Your voice is ready" preview. Allow 3 attempts.
10. **Affirmations** (`10`):
    - Audio affirmation list ("I am a money magnet", "I get paid to exist"…).
    - **Daily affirmation cards**: a swipeable stack with heart and share, and "COME BACK ONCE DAILY".
    - Completed state: "You've aligned with all of your affirmations for today."
    - Saved affirmations.
11. **Profile** (`11`):
    - Name and the line "The more ___ knows, the realer it feels".
    - Library: Favorites, Recently played.
    - The basics: name, age, city, career, gender, sexuality.
    - My people, My kids.
    - My lifestyle tags (AI-extracted and editable).
    - Never include (blocked topics).
    - Archive.
12. **Favorites** (`12`): list of liked stories with dates.
13. **Journaling** (`13`): Gratitude tab (daily entry + streak + history) and Manifestations tab ("What have you manifested?" with a photo, shown on a Wall of manifestations).
14. **Achievement reward** (`14`): "I manifested this ✨" shareable card → Share to Instagram Story / Save / More.
15. **Feedback** (`15`): "Anything ___ should know?" → saves straight to the profile.
16. **Settings** (`16`):
    - My voice and name pronunciations.
    - Sign in with Apple.
    - Manage subscription.
    - Version, Terms, Privacy, Contact.
    - Share troubleshooting info.
    - Delete account.

## 6. Suggested stack

- **App:** Expo (React Native + TypeScript) with Expo Router. Use expo-av / expo-audio for playback, expo-notifications, expo-blur and Reanimated for the motion.
- **Backend:** Supabase (auth with Sign in with Apple, Postgres for profile/desires/stories/streaks, storage for audio and images, edge functions).
- **Story text:** an LLM (Claude API). The prompt combines the profile, a desire and the "never include" list, and returns about 2–3 minutes of first-person, present-tense, sensory story plus a short title line.
- **Voice:** ElevenLabs (curated voices + instant voice cloning from a ~10s sample). Generate the audio once and cache it in storage.
- **Cover images:** an image model, or a curated stock library tagged by theme (cheaper to start).
- **Payments:** RevenueCat (weekly/yearly subscription with a trial).
- **Cost control:** generate a fixed number of stories per user per day (the "daily refresh"). Cache audio. Only generate on demand for paid users.

## 7. Data model (starting point)

- `profiles`: name, age, city, gender, sexuality, kids, relationship, work, work_feeling, about, past, dream_location, home_type, partner, lifestyle_tags[], never_include[], voice_id, reminder_time
- `people`: profile_id, name, relation
- `desires`: profile_id, title, description, image_url
- `stories`: profile_id, desire_id, title, text, audio_url, cover_url, duration, liked, created_at
- `listens`: profile_id, story_id, listened_at (used for streaks and the challenge)
- `affirmations`, `saved_affirmations`, `gratitude_entries`, `manifestations`, `feedback_notes`

## 8. Build order

1. Design system, tab bar and Home shell.
2. Conversational onboarding, saving to the profile.
3. Story generation pipeline (text → voice → cover) and the player.
4. Daily refresh, the 21-day streak and reminders.
5. Affirmations, journaling and favorites.
6. Voice cloning and sharing cards.
7. Paywall and settings.
