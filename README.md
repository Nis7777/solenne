# Solenne

A personal manifestation app for iPhone, written in SwiftUI. You tell Solenne about your life and the life you want. It writes short first-person "vision stories" for you and narrates them with karaoke-style text. A 21-day listening streak, daily reminders, affirmation cards and a journal bring you back each day.

The product brief is in `docs/BRIEF.md`. The reference app's screens were used only for structure and flow. The name, copy, icon, cover art, music and content in this repo are all new.

## Run it

1. Open `Solenne.xcodeproj` in **Xcode 16 or later**.
2. Select the **Solenne** target → *Signing & Capabilities* → pick your Team. If `com.solenne.app` is taken, change the bundle id.
3. Pick an iPhone simulator (iOS 17+) and press **Run**.

It works fully offline. You don't need any keys to try it.

- **Stories** are written on device. On iOS 26 with Apple Intelligence turned on, Solenne uses Apple's on-device model (`FoundationModels`). Otherwise it uses a built-in story composer that writes from your onboarding answers.
- **Narration** uses `AVSpeechSynthesizer`, with each word highlighted as it is spoken. For much better voices, download an *Enhanced* or *Premium* voice in iOS Settings → Accessibility → Spoken Content → Voices. You can also use your own **Personal Voice** (iOS 17+).
- **Purchases** use StoreKit 2 with the local `Solenne.storekit` config, which the shared scheme already points to. The paywall shows real weekly and yearly plans with free trials in the simulator. In Debug builds, Settings → *Pro (debug only)* unlocks everything.

## Test on your iPhone without a Mac (TestFlight)

Two GitHub Actions workflows run on GitHub's Mac machines:

- **iOS build** compiles the app on every push. It needs no setup.
- **TestFlight** archives, signs and uploads a build you can install with the TestFlight app. You start it by hand.

One-time setup for TestFlight (works from a phone browser). It needs a paid **Apple Developer Program** membership.

1. **App Store Connect → Apps → +** → New App. Register a unique bundle id, e.g. `com.yourname.solenne`.
2. **App Store Connect → Users and Access → Integrations → App Store Connect API** → generate a key with the **Admin** role. Download the `.p8` file (you can only download it once) and note the Key ID and Issuer ID.
3. **GitHub repo → Settings → Secrets and variables → Actions**:
   - Secrets: `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (the full text of the `.p8` file).
   - Variable: `BUNDLE_ID` (the bundle id from step 1).
4. **GitHub → Actions → TestFlight → Run workflow**. After about 15 minutes of build time and Apple's processing, the build appears in TestFlight. Add yourself as an internal tester and install it from the TestFlight app.

## What's in the app

| Area | Where |
|---|---|
| Conversational onboarding: typewriter questions, AI reflections, people sheet, dream-life questions | `Features/Onboarding` |
| Home (orb, "what do you want to *manifest?*"), For You with daily-refresh countdown, Explore swipe cards, Library | `Features/Home` |
| Immersive player: intro, karaoke line, transcript strip, scrubber, ±10s, ambient music toggle, "Something sound off?", reading view, bookmark | `Features/Player` |
| Share cards → copy link, Instagram Stories, Messages, save image, share sheet | `Features/Share` |
| 21-day challenge: intro → day card → progress (streak, week dots, month calendar) | `Features/Challenge` |
| Daily reminders with notification preview, desires, "What are you *calling in?*" | `Features/Settings/RemindersAndDesires.swift` |
| Voice picker (7 curated voices + Personal Voice) and voice cloning (record 10s, review, 3 attempts) | `Features/Voice` |
| Daily affirmation deck (swipe, save, share, completed state), saved affirmations | `Features/Affirmations` |
| Profile: basics, people, kids, AI lifestyle tags, never-include, "Anything Solenne should *know?*" | `Features/Profile` |
| Journal: gratitude streak + history, manifestation wall, "I manifested this ✨" card | `Features/Journal` |
| Settings (name pronunciation, Sign in with Apple, subscription, troubleshooting, delete account) and paywall | `Features/Settings` |

Everything you enter stays on the device, in `Documents/solenne.json`, written by `Model/AppModel.swift`. The profile is the context for every story.

## Connect the backend (Claude + ElevenLabs)

`supabase/` holds the server side of the generation pipeline: **text → voice → cached audio**. You can set it all up from a phone:

1. Create a project at supabase.com. Note the database password you choose.
2. In that project, open **Authentication → Sign In / Providers** and turn on **Anonymous sign-ins**.
3. Get the keys:
   - **ElevenLabs:** elevenlabs.io → Developers → API Keys. Voice cloning needs the Starter plan or higher.
   - **Anthropic:** console.anthropic.com → API Keys.
   - **Supabase:** supabase.com → Account → Access Tokens.
4. In GitHub, open **Settings → Secrets and variables → Actions**:
   - Secrets: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY`.
   - Variables:
     - `SUPABASE_PROJECT_REF` (the id in your project's dashboard URL).
     - `SUPABASE_URL` (`https://<ref>.supabase.co`).
     - `SUPABASE_ANON_KEY` (Project Settings → API keys → anon public).
5. Go to **Actions → Deploy backend → Run workflow**. It creates the table and storage bucket, stores the API keys as function secrets and deploys the four functions.
6. Run **TestFlight** again. The new build reads `SUPABASE_URL` and `SUPABASE_ANON_KEY`, so it uses the backend.

If you build from Xcode instead, type the URL and anon key into `Config` in `Solenne/Services/Backend.swift`. To deploy from a computer:

```bash
supabase link --project-ref <ref>
```

```bash
supabase db push
```

```bash
supabase secrets set ANTHROPIC_API_KEY=... ELEVENLABS_API_KEY=...
```

```bash
supabase functions deploy
```

What happens once it's connected:

- Each install signs in anonymously. Every function checks the user's JWT and enforces a per-user daily cap, set in `DAILY_LIMITS` in `supabase/functions/_shared/common.ts`.
- `generate-story` writes the story with Claude (`claude-opus-5-5`, with server-side refusal fallbacks turned on). It narrates the story once with ElevenLabs (`eleven_multilingual_v2`) in the voice the user picked, and stores the MP3 in the `stories` bucket. The app streams that file and maps the playback time onto the text.
- `clone-voice` sends the 10-second sample to ElevenLabs instant voice cloning. From then on, stories use the user's own voice.
- `reflect` and `lifestyle-tags` write the onboarding reflections and the profile tags.
- If any call fails, the app falls back to on-device generation and the iOS voice. A story is never blocked.

The 7 curated voices map to ElevenLabs premade voices in `Services/Voices.swift` (`elevenLabsID`). To use different voices, copy their ids from your ElevenLabs Voice Library. In-app voice previews still use the iOS voices; only the stories themselves are narrated by ElevenLabs.

## Before App Store submission

- Replace `Config.termsURL`, `privacyURL` and `supportEmail`.
- Create `solenne.pro.weekly` and `solenne.pro.yearly` in App Store Connect, in one subscription group, with free-trial intro offers.
- Add the **Sign in with Apple** capability to the target. It is left off so the project builds with a free personal team.
- Optional: set `Config.instagramAppID` (a Meta app id) to share straight to Instagram Stories. Without it, the share sheet is used.
- Not built yet: syncing the profile and stories to Supabase across devices, background-music choices beyond the one ambient bed, "Songs", and trimming the voice sample.

## Project layout

```
Solenne.xcodeproj      Xcode 16 project (folder-synced: new files in Solenne/ are picked up automatically)
Solenne/
  App/                 entry point, tab shell, floating pill tab bar, routes
  Design/              palette, fonts, glass cards, orb, flame, typewriter, generated cover art
  Model/               data model, app state, streak math, daily refresh
  Services/            story engine + composer, narrator, voices, backend client, StoreKit, notifications, recorder
  Content/             library stories, affirmation tracks, sleep tracks, daily affirmation pool
  Features/            one folder per area (see table above)
  Resources/           Instrument Serif + Plus Jakarta Sans (OFL), ambient.m4a (generated for this project)
SupportingFiles/       Info.plist additions (background audio, URL scheme)
Solenne.storekit       local StoreKit test products
supabase/              edge functions + migration
```
