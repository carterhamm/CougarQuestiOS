# CougarQuest App Clip + Web Share Plan

## Goal

A user shares a quest from the CougarQuest iOS app via the Share toolbar button. The recipient (probably a friend in Apple Messages) sees a rich link preview. Tapping it:

- **iOS, app installed** → opens CougarQuest, deep-links to that quest.
- **iOS, app not installed** → offers the App Clip (small one-quest preview, ≤15 MB compressed).
- **Web / Android / desktop** → opens a web page showing the quest detail.

Link shape: `https://cougarquest.com/q/<questId>`

## What's already in code

`CougarQuestLink` — `url(forQuestId:)` and `questId(from:)`. Used by:
- The Share toolbar button on `QuestView` (constructs the URL).
- `DeepLinkState.handle(_:)` (parses incoming URLs).

`CougarQuestApp.swift` — `.onOpenURL` + `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` route to `DeepLinkState.shared`.

`ContentView` — observes `DeepLinkState.pendingQuestId`, fetches the quest from Firestore, and opens it via the existing `sheetQuest` flow.

## What still needs to be done (outside Swift)

### 1. Domain

- Acquire `cougarquest.com` (or use `web.cougarquest.com` on whatever you already own).
- Either way, the Universal Link host must match `CougarQuestLink.host`.
- Update `CougarQuestLink.swift` if you go with `web.cougarquest.com`.

### 2. Add Associated Domains entitlement to the main app

Xcode → CougarQuest target → Signing & Capabilities → `+` Capability → Associated Domains. Add:

```
applinks:cougarquest.com
appclips:cougarquest.com
```

### 3. AASA (Apple App Site Association) file

Host this **exactly** at `https://cougarquest.com/.well-known/apple-app-site-association`. No `.json` extension; `Content-Type: application/json`; HTTPS only; no redirects.

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["TEAMID.tony.stark.CougarQuest"],
        "components": [
          { "/": "/q/*", "comment": "Quest deep link" }
        ]
      }
    ]
  },
  "appclips": {
    "apps": ["TEAMID.tony.stark.CougarQuest.Clip"]
  }
}
```

Replace `TEAMID` with your Apple Developer Team ID (Xcode → target → Signing & Capabilities → Team).

### 4. Web fallback page at `/q/<id>`

The page needs to:

- Look up the quest from Firestore (Web SDK or static rendering at deploy time).
- Render the quest's photo, title, address, description, and a "Open in Maps" link.
- Include the iOS Smart App Banner so non-clip iOS browsers can suggest the app:

  ```html
  <meta name="apple-itunes-app" content="app-id=YOUR_APP_STORE_ID, app-clip-bundle-id=tony.stark.CougarQuest.Clip">
  ```

This page can be a simple Next.js / Vite / static HTML page hosted on Firebase Hosting (same Firebase project, free tier covers this easily). Build this alongside the admin dashboard since both need Firebase Web SDK; share auth + read code.

### 5. App Clip target (Xcode)

App Clip targets must be created via Xcode UI (not script):

1. Xcode → File → New → Target → App Clip.
2. Bundle ID: `tony.stark.CougarQuest.Clip` (the suffix `.Clip` matters).
3. Add Capability → App Clips → invocation URL: `https://cougarquest.com/q/`.
4. Add Capability → Associated Domains → `appclips:cougarquest.com`.

### 6. App Clip scope decisions

What to **include** in the App Clip:

| Feature | Included | Notes |
|---------|----------|-------|
| Quest detail (photo, title, address, description) | ✅ | The whole point. |
| "Navigate" → opens Apple Maps | ✅ | Just a `Link(destination:)`. No MapKit binary cost. |
| Mark as visited (camera/photo + Firebase Storage upload) | ✅ | Reuses existing Storage rules. |
| Sign in with Apple (lightweight) | ✅ | App Clips officially support SiwA. Anonymous reads OK without it. |
| "Get the full app" CTA | ✅ | Uses `SKOverlay.Configuration(appIdentifier:)` for the App Store overlay. |
| Adaptive Glass styling | ✅ | The `AdaptiveGlass.swift` file is small enough to include. |
| Kingfisher for image loading | ✅ | Single image; small overhead. |

What to **exclude**:

| Feature | Excluded | Reason |
|---------|----------|--------|
| Full Leaderboard | ❌ | 200+ rows = huge UI, large fetch; tax on the 15 MB budget. |
| QuestsView (full map) | ❌ | Out of scope for "share *this* quest"; MapKit + many pins + Firestore listAll = big. |
| HomeView (For You / Completed sections) | ❌ | Personal — clip viewer doesn't have a profile. |
| ProfileView, Sign-up flow | ❌ | Friction. The clip's CTA is "Get the full app for the full experience." |
| Admin / SortingView | ❌ | Obviously. |
| Custom FloatingTabBar / morph state | ❌ | Single-screen clip; no tabs. |
| FCM / push notifications | ❌ | Clips should be silent. |
| Crashlytics | Optional | Useful for clip-specific crash debugging; ~1 MB. |
| Real-time Firestore listeners | ❌ | One-shot `getDocument` is enough. |

So the App Clip is essentially a **one-screen QuestPreview** + **Sign in with Apple gate** (optional, for "Mark visited") + **App Store overlay**. Estimate ~3–5 MB compressed once you account for shared Firebase + Kingfisher binaries.

### 7. App Clip target file membership

Add the following files to the App Clip target's "Compile Sources":

- `Models.swift` (Quest, UserProfile)
- `AdaptiveGlass.swift`
- `CougarQuestLink.swift`
- `Color+CougarBlue.swift` (if it exists; otherwise inline the color into the clip)
- New file: `ClipQuestPreviewView.swift` (a simplified one-screen QuestView)
- New file: `ClipApp.swift` (the App Clip's `@main` entry point)

Do **not** add: ContentView, HomeView, QuestsView, LeaderboardView, ProfileView, SortingView, the full QuestView, HomeView's hero greeting, FCM/Messaging code.

### 8. App Clip launch flow

```swift
// ClipApp.swift
@main
struct CougarQuestClipApp: App {
    init() { FirebaseApp.configure() }
    var body: some Scene {
        WindowGroup {
            ClipRootView()
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL,
                       let id = CougarQuestLink.questId(from: url) {
                        ClipState.shared.questId = id
                    }
                }
        }
    }
}
```

`ClipRootView` reads `ClipState.shared.questId`, fetches the quest doc, and renders `ClipQuestPreviewView`. If `questId` is nil (clip launched without a deep link, edge case), show a "Get the app" landing screen.

### 9. Verifying

- `xcrun swift-protobuf` not relevant; instead use:
- Apple's [App Site Association Validator](https://search.developer.apple.com/appsearch-validation-tool) once the AASA file is live.
- Test the link in Apple Messages: type the URL, send to yourself. Should preview as a rich link with the quest's photo (Open Graph metadata on the web page) and tap should open the app or offer the clip.
- Test offline behavior: clip-only first launch should still load the quest if cellular is available. Cache nothing aggressively.

## Open questions (decide before building)

- Do anonymous (non-signed-in) users count toward the leaderboard if they upload a photo via the App Clip? (Probably no — App Clip uploads can be tagged with a temporary clip-uuid and reconciled if/when they install the full app.)
- Should the share message include the quest's photo as Open Graph metadata? (Nice-to-have for the rich link preview in Messages.)
- One link format for everything (`/q/<id>`), or separate clip vs deep link paths? (Recommend one — Apple resolves AASA components for both.)

## Implementation order

1. **Now (already done):** Share button, URL builder/parser, deep link routing in iOS code.
2. **Next:** Acquire domain, deploy AASA + web fallback page (can be a single static HTML page that reads the quest from Firestore via Web SDK).
3. **Then:** Add Associated Domains entitlement, test Universal Link with main app installed.
4. **Then:** Create App Clip target in Xcode, port `ClipQuestPreviewView` + `ClipApp`, test invocation.
5. **Last:** App Store submission flow for the clip (must be approved alongside or after the main app).
