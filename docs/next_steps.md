# What to do now

Concrete order of operations. Skip Cloudflare for the moment — it can wait. Focus on the iMessage rich preview + App Clip.

## 1. iMessage rich preview (per-quest photo)

The pieces are in place; you just need to deploy.

### What's already done

- `index.html` now has default Open Graph + iTunes-app meta tags.
- `scripts/generate-quest-pages.mjs` reads every quest from Firestore and writes `dist/quest/<id>/index.html` with that quest's title / description / photo as OG meta.
- `package.json` `build` script now runs the generator after `vite build`. So a normal `npm run build && firebase deploy --only hosting` will publish per-quest preview HTML files.
- Firebase Hosting serves the static `dist/quest/<id>/index.html` first; only requests for non-existent files fall through to the SPA shell. So `/quest/abc` lands on the pre-rendered file (scrapers see OG meta) but the SPA still mounts and takes over for live users.

### What you do

1. Make a default `og-default.png` (CougarQuest logo on a brand-blue background, ≥1200×630 recommended). Drop it at `CougarQuestWeb/public/og-default.png`.
2. (Optional, recommended) Replace the `YOUR_APP_STORE_ID` placeholder in `index.html`'s `apple-itunes-app` meta tag once you have an App Store ID.
3. Deploy:
   ```bash
   cd CougarQuestWeb
   npm run build              # vite build + per-quest pre-render
   firebase deploy --only hosting
   ```
4. Test the preview by sending yourself an iMessage with a real quest URL like `https://cougarquest.com/quest/<some-firestore-doc-id>`. iMessage caches link previews aggressively — if it doesn't update, try sending to a different iMessage thread.

If iMessage still shows the URL as plain text:
- Verify with `curl https://cougarquest.com/quest/<id>` that the HTML response contains `<meta property="og:image" ...>` pointing at the quest's photo.
- Verify it's the per-quest HTML, not the SPA shell (the title tag should be the quest title).
- Apple's link-preview validator: <https://search.developer.apple.com/appsearch-validation-tool> (technically an AASA tool but useful for header inspection).

## 2. App Clip — wizard answers + post-create steps

**Wizard:** change `Product Name` → `Clip`, set `Storage` → `None`, **uncheck** `Host in CloudKit`. Everything else (Team, SwiftUI, Swift, Embed in CougarQuest) is correct. Click Finish.

After Xcode creates the target:

### 2a. Replace the auto-generated source files

Xcode creates a `Clip/` folder with default `ClipApp.swift` + `ContentView.swift`. Replace them with the starter files in `Clip/` already in the repo:

- `Clip/ClipApp.swift` — `@main` entry, Firebase init, parses incoming Universal Link → `ClipState.shared.questId`.
- `Clip/ClipRootView.swift` — root scene; loads quest by id, shows preview, presents the App Store overlay for "Get the full app".
- `Clip/ClipQuestPreview.swift` — the one screen: hero photo, title, address, description, Navigate, Get-app CTA.

In Xcode → Project Navigator → drag these three files into the Clip folder of the project. **Make sure** "Target Membership" on the right side has only the Clip target checked, not the main app.

### 2b. Add shared sources to the Clip target

These already exist in the main app folder. In Xcode:

- Select `CougarQuest/CougarQuestLink.swift` → File Inspector → Target Membership → also check "Clip" ✅.
- Same for `CougarQuest/AdaptiveGlass.swift` (if you want the Adaptive Glass styling in the clip's UI; the starter currently uses plain Capsules so it isn't strictly required).
- `CougarQuest/Models.swift` is **not** required — `ClipApp.swift` defines its own lightweight `ClipQuest` struct.

### 2c. Add Firebase to the Clip target

Project Navigator → CougarQuest project → Package Dependencies → select `firebase-ios-sdk` → check the Clip target's checkbox for these products:
- `FirebaseCore`
- `FirebaseFirestore`

(Skip Auth, Messaging, Crashlytics, Storage — the clip is read-only for now. Add Storage later if you want clip users to upload photos.)

Same for Kingfisher (only the `Kingfisher` product).

### 2d. Add capabilities to the Clip target

Select the Clip target → Signing & Capabilities → click `+ Capability`:
1. **Associated Domains** — add `applinks:cougarquest.com` and `appclips:cougarquest.com`.
2. **App Clips** — accept defaults.

### 2e. Configure App Clip invocation URL

Apple Connect / Xcode App Clip target settings → `App Clip Configuration` → set the **invocation URL** to `https://cougarquest.com/quest/`. Apple uses this prefix to determine which URLs trigger the clip.

### 2f. Update AASA Team ID

Open `CougarQuestWeb/public/.well-known/apple-app-site-association` and replace **both** instances of `REPLACE_TEAM_ID` with your Apple Developer Team ID. You can find it at:
- developer.apple.com → Membership → Team ID, **or**
- Xcode → CougarQuest target → Signing & Capabilities → "Team" → the popup shows the ID.

Re-deploy: `firebase deploy --only hosting`.

### 2g. Verify

1. `curl -I https://cougarquest.com/.well-known/apple-app-site-association` → expect `Content-Type: application/json` and `200 OK`.
2. Run Apple's AASA validator on `cougarquest.com`.
3. Build the App Clip target on a real device (App Clips don't run in Simulator). Use Xcode → Product → Scheme → Clip → Build and Run.
4. Test invocation: with the clip installed (after a real device build), tap an `https://cougarquest.com/quest/<id>` link in Messages. The clip should appear as a card above iMessage. Tap → opens the preview screen.

## 3. Things you don't have to do

- **Cloudflare** — defer until you have a reason. Firebase Hosting works fine with GoDaddy DNS.
- **App Store submission** — you can develop and TestFlight the clip without submitting. Submit when the main app + clip are ready together.
- **Per-clip auth (Sign in with Apple)** — out of scope for the read-only preview. Add later if you want clip users to mark visited.
