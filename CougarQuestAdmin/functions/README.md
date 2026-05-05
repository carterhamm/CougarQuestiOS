# Apple Maps Shortened URL Resolver

A Firebase Cloud Function that takes an Apple Maps place ID (from a URL like
`https://maps.apple/p/X2~YZwwPHxBGWt`) and returns its `latitude` / `longitude`
via the Apple Maps Server API.

The admin app's `appleMapsUrlToPlusCode()` calls this endpoint when a shortened
URL is pasted into the Plus Code field; the response is then converted to a
Plus Code locally with the Open Location Code library — no key needed in the
browser.

## Why this needs a backend

The Apple Maps Server API requires JWT authentication using a private key
issued to a Maps ID in your Apple Developer account. That private key cannot
be shipped to the browser, so the lookup must happen server-side.

## One-time setup

1. **Apple Developer**: Certificates, Identifiers & Profiles → Maps IDs →
   create a Maps ID (e.g. `maps.com.byu.cougarquest.admin`). Then create a
   Maps Private Key and download the `.p8` file. Note the Key ID and Team ID.

2. **Set Firebase config**:
   ```sh
   cd CougarQuestAdmin/functions
   firebase functions:secrets:set APPLE_MAPS_TEAM_ID
   firebase functions:secrets:set APPLE_MAPS_KEY_ID
   firebase functions:secrets:set APPLE_MAPS_PRIVATE_KEY  # paste the .p8 contents
   ```

3. **Install + deploy**:
   ```sh
   cd CougarQuestAdmin/functions
   npm install
   firebase deploy --only functions:resolveAppleMapsPlace
   ```

4. **Wire the URL into the admin app**: copy the deployed function URL into
   `CougarQuestAdmin/.env`:
   ```
   VITE_MAPS_RESOLVER_URL=https://<region>-<project>.cloudfunctions.net/resolveAppleMapsPlace
   ```
