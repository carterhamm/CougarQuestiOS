# CougarQuest share-link setup — exact steps

You asked four specific questions. Each one answered concretely, in order.

---

## 1. Port `cougarquest.com` from GoDaddy to Cloudflare

There are **two different things** people mean by "port to Cloudflare." Pick the one that matches what you actually want.

### Option A — Just use Cloudflare for DNS (recommended)

Keep GoDaddy as your registrar. Use Cloudflare's DNS (free tier, fast, gives you the orange-cloud features). This is what 90% of people mean.

1. Sign up for Cloudflare → "Add a site" → enter `cougarquest.com` → pick the Free plan.
2. Cloudflare scans your existing DNS records at GoDaddy. Verify the list looks right.
3. Cloudflare gives you two nameservers, e.g. `aria.ns.cloudflare.com` and `cole.ns.cloudflare.com`.
4. In GoDaddy: Domain Settings → Nameservers → Change → "Enter my own nameservers" → paste the two Cloudflare ones → Save.
5. Wait. Propagation usually finishes in 1–4 hours; Cloudflare emails you when it's live.

**Cost:** $0. **Reversibility:** trivial — point nameservers back to GoDaddy.

### Option B — Transfer the registrar to Cloudflare Registrar

You actually move ownership/billing to Cloudflare. Useful if you want to consolidate and pay at-cost ($9.77/yr for `.com` instead of GoDaddy's renewal price).

1. At GoDaddy: unlock the domain (Domain Settings → Domain Lock → off).
2. At GoDaddy: get the **EPP/Auth code** (Domain Settings → Transfer → "I want to transfer my domain away from GoDaddy" → email you the code).
3. At Cloudflare Registrar: Transfer Domain → enter `cougarquest.com` → paste the EPP code → pay (1-year extension required).
4. Approve the transfer email Cloudflare sends.
5. GoDaddy may show a 5-day waiting period; you can speed it up by approving in their portal.

**Cost:** ~$10 (1-year extension). **Reversibility:** wait 60 days for ICANN's transfer-lock to lift before you can transfer again.

### Which to pick

For your use case (Universal Links, Firebase Hosting, App Clip), **Option A is enough**. Only do Option B if you specifically want lower renewal prices or to consolidate billing.

### After either option — point DNS at Firebase Hosting

Once Cloudflare manages your DNS:

1. Firebase Console → Hosting → "Add custom domain" → enter `cougarquest.com`.
2. Firebase shows a TXT record for verification, plus two A records.
3. In Cloudflare DNS:
   - Add the TXT record (Type=TXT, Name=`@`, Content=whatever Firebase gave you).
   - Add the two A records (Type=A, Name=`@`, IP=whatever Firebase gave you).
   - **Important:** click the orange cloud → grey cloud (DNS-only, not proxied). Firebase Hosting handles its own SSL termination; running through Cloudflare's proxy can break the SSL handshake.
4. Wait for Firebase to verify (a few minutes to an hour).
5. Repeat for `www.cougarquest.com` if you want both.

---

## 2. Associated Domains entitlement — exact text

In Xcode:

- Open `CougarQuest.xcodeproj`.
- Select the **CougarQuest** target → **Signing & Capabilities** tab.
- If "Associated Domains" isn't already a row: click `+ Capability`, search "Associated Domains," double-click.
- Under "Domains" click `+` and add **each of these on its own line, exactly**:

```
applinks:cougarquest.com
appclips:cougarquest.com
```

That's it for the main app. When you eventually create the App Clip target, repeat the same two lines on the App Clip target's "Signing & Capabilities" tab too.

`applinks:` enables Universal Link handling. `appclips:` allows the App Clip to be invoked from the same domain.

---

## 3. AASA JSON — already done in this repo

Apple App Site Association file is already created at:

```
CougarQuestWeb/public/.well-known/apple-app-site-association
```

(no extension; that's intentional.) Vite copies `public/` → `dist/` at build, so after `npm run build && firebase deploy`, it'll be at:

```
https://cougarquest.com/.well-known/apple-app-site-association
```

`firebase.json` was updated to set `Content-Type: application/json` on that file (Apple is strict — must be JSON, no redirects, no HTML wrapper).

**Before deploying, edit one line:**

Open `CougarQuestWeb/public/.well-known/apple-app-site-association` and replace `REPLACE_TEAM_ID` (in two places) with your actual Apple Developer Team ID.

You can find your Team ID in:
- developer.apple.com → Membership → Team ID (10 chars, all caps), **or**
- Xcode → CougarQuest target → Signing & Capabilities → "Team" dropdown shows the name + ID.

So if your Team ID is `ABCD123XYZ`, the two `appIDs` lines become:

```json
"appIDs": ["ABCD123XYZ.tony.stark.CougarQuest"],
...
"apps": ["ABCD123XYZ.tony.stark.CougarQuest.Clip"]
```

(Bundle IDs come from your Xcode targets — verify them by selecting the target and looking at "Bundle Identifier" on the General tab. The clip target's bundle ID convention is `<main-bundle-id>.Clip`. If you pick a different suffix later, update the AASA accordingly.)

After editing, deploy:

```bash
cd CougarQuestWeb
npm run build
firebase deploy --only hosting
```

Verify it's live with:

```bash
curl -I https://cougarquest.com/.well-known/apple-app-site-association
# Should show: Content-Type: application/json, HTTP/2 200
```

Apple also has a public validator: <https://search.developer.apple.com/appsearch-validation-tool> — paste your domain in once it's deployed.

---

## 4. Web fallback — already built, but route alignment fixed

You already have `CougarQuestWeb/src/pages/Quest.tsx` and `App.tsx` routing `/quest/:id` to it. So the iOS share button now generates `https://cougarquest.com/quest/<questId>`.

Updated `CougarQuestLink.swift` to use `/quest/<id>` instead of `/q/<id>` so iOS, AASA, and the web all match. Single source of truth.

If you ever want a shorter URL, you can add a redirect in `CougarQuestWeb/src/App.tsx`:

```tsx
<Route path="q/:id" element={<Navigate to={`/quest/${useParams().id}`} replace />} />
```

But not needed today — `/quest/<id>` is the canonical shape.

---

## End-to-end checklist

In order, what's left:

- [ ] Pick Cloudflare option A or B; move DNS.
- [ ] Firebase Console → Hosting → Add custom domain `cougarquest.com`. Add the records Cloudflare → A/TXT.
- [ ] Wait for Firebase to verify.
- [ ] Edit `apple-app-site-association` to replace `REPLACE_TEAM_ID` (2 places).
- [ ] `cd CougarQuestWeb && npm run build && firebase deploy --only hosting`
- [ ] `curl -I https://cougarquest.com/.well-known/apple-app-site-association` → confirm `Content-Type: application/json`.
- [ ] Run Apple's AASA validator on the URL.
- [ ] Xcode → CougarQuest target → add Associated Domains capability → `applinks:cougarquest.com`, `appclips:cougarquest.com`.
- [ ] Build & install the app on your phone.
- [ ] Send yourself an iMessage with `https://cougarquest.com/quest/<some-real-quest-id>`. Long-press the link bubble — it should say "Open in CougarQuest" if the AASA + entitlement combo is correct. Tap → app opens, deep-links.
- [ ] (Later) Create the App Clip target and add `appclips:` enforcement.

When you hit a snag at any step, share the exact error and I'll narrow it down.
