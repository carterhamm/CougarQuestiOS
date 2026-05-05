import OpenLocationCode from 'open-location-code-typescript'

/**
 * Apple Maps URL → Google Plus Code conversion.
 *
 * Two paths:
 *
 * 1. **Direct extraction (no auth needed)** — many Apple Maps URLs include
 *    `?ll=<lat>,<lon>` or `?coordinate=<lat>,<lon>` query parameters. We can
 *    extract those client-side and convert to Plus Code with no network call.
 *
 * 2. **Shortened URLs** like `https://maps.apple/p/X2~YZwwPHxBGWt` only carry
 *    a place ID. Resolving that to coordinates requires the Apple Maps Server
 *    API, which is JWT-authenticated with a private key — that **must** run on
 *    a server. See `functions/index.ts` for a Firebase Function stub. Once
 *    deployed, set `VITE_MAPS_RESOLVER_URL` and `resolveAppleMapsUrl()` will
 *    use it automatically.
 */

export interface LatLng {
  latitude: number
  longitude: number
}

const APPLE_MAPS_HOSTS = ['maps.apple.com', 'maps.apple', 'beta.maps.apple.com']

/**
 * Try to extract lat/lon from an Apple Maps URL query string.
 * Returns null for shortened URLs that don't carry coordinates.
 */
export function extractCoordsFromAppleMapsUrl(input: string): LatLng | null {
  if (!input) return null
  const trimmed = input.trim()
  let url: URL
  try {
    url = new URL(trimmed.startsWith('http') ? trimmed : `https://${trimmed}`)
  } catch {
    return null
  }

  if (!APPLE_MAPS_HOSTS.some((h) => url.hostname.endsWith(h))) return null

  const params = url.searchParams
  // Apple Maps uses `ll`, `coordinate`, and `sll` for coordinate pairs.
  for (const key of ['ll', 'coordinate', 'sll']) {
    const v = params.get(key)
    if (!v) continue
    const m = v.match(/^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/)
    if (m) {
      return { latitude: parseFloat(m[1]), longitude: parseFloat(m[2]) }
    }
  }
  return null
}

/** Pull the place ID out of a shortened Apple Maps URL like maps.apple/p/X2~ABC. */
export function extractAppleMapsPlaceId(input: string): string | null {
  if (!input) return null
  try {
    const url = new URL(input.trim())
    if (!APPLE_MAPS_HOSTS.some((h) => url.hostname.endsWith(h))) return null
    const m = url.pathname.match(/^\/p\/([^/?#]+)/)
    return m ? m[1] : null
  } catch {
    return null
  }
}

/** lat/lon → Open Location Code Plus Code (e.g. "8FVC9G8F+6W"). */
export function latLngToPlusCode(lat: number, lon: number, codeLength = 10): string {
  return OpenLocationCode.encode(lat, lon, codeLength)
}

/**
 * Resolve any Apple Maps URL to a Plus Code.
 *
 * - URLs with `ll=` / `coordinate=` → resolved instantly, no network.
 * - Shortened maps.apple/p/* URLs → calls the configured backend resolver
 *   (`VITE_MAPS_RESOLVER_URL`). If it's not configured / unreachable, returns
 *   `null` and the caller can fall back to manual entry.
 */
export async function appleMapsUrlToPlusCode(input: string): Promise<string | null> {
  const direct = extractCoordsFromAppleMapsUrl(input)
  if (direct) return latLngToPlusCode(direct.latitude, direct.longitude)

  const placeId = extractAppleMapsPlaceId(input)
  if (!placeId) return null

  const endpoint = import.meta.env.VITE_MAPS_RESOLVER_URL
  if (!endpoint) return null
  try {
    const res = await fetch(`${endpoint}?id=${encodeURIComponent(placeId)}`)
    if (!res.ok) return null
    const data = (await res.json()) as { latitude?: number; longitude?: number }
    if (typeof data.latitude !== 'number' || typeof data.longitude !== 'number') return null
    return latLngToPlusCode(data.latitude, data.longitude)
  } catch {
    return null
  }
}
