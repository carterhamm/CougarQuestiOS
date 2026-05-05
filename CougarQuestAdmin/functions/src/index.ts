import { onRequest } from 'firebase-functions/v2/https'
import { defineSecret } from 'firebase-functions/params'
import * as jwt from 'jsonwebtoken'

const TEAM_ID     = defineSecret('APPLE_MAPS_TEAM_ID')
const KEY_ID      = defineSecret('APPLE_MAPS_KEY_ID')
const PRIVATE_KEY = defineSecret('APPLE_MAPS_PRIVATE_KEY')

let cachedToken: { token: string; exp: number } | null = null

function mintMapsToken(): string {
  // Reuse for ~50min to stay well under Apple's 1hr token lifetime.
  const now = Math.floor(Date.now() / 1000)
  if (cachedToken && cachedToken.exp - now > 60) return cachedToken.token

  const expSec = now + 60 * 50
  const token = jwt.sign(
    { iss: TEAM_ID.value(), iat: now, exp: expSec },
    PRIVATE_KEY.value(),
    {
      algorithm: 'ES256',
      header: { kid: KEY_ID.value(), typ: 'JWT', alg: 'ES256' },
    },
  )
  cachedToken = { token, exp: expSec }
  return token
}

interface ApplePlaceResponse {
  results?: Array<{
    coordinate?: { latitude: number; longitude: number }
    point?:      { latitude: number; longitude: number }
  }>
  coordinate?: { latitude: number; longitude: number }
  point?:      { latitude: number; longitude: number }
}

/**
 * GET /resolveAppleMapsPlace?id=<placeId>
 *
 * Resolves a shortened Apple Maps place ID to lat/lon. The admin frontend
 * converts that to a Plus Code locally — no need for the function to know
 * about Open Location Code.
 */
export const resolveAppleMapsPlace = onRequest(
  {
    secrets: [TEAM_ID, KEY_ID, PRIVATE_KEY],
    cors: true,
    memory: '256MiB',
    timeoutSeconds: 15,
  },
  async (req, res) => {
    const id = (req.query.id ?? '').toString().trim()
    if (!id) { res.status(400).json({ error: 'missing id' }); return }

    try {
      const token = mintMapsToken()
      const r = await fetch(`https://maps-api.apple.com/v1/place/${encodeURIComponent(id)}`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (!r.ok) { res.status(r.status).json({ error: 'apple maps lookup failed' }); return }
      const data = (await r.json()) as ApplePlaceResponse

      const coord =
        data.results?.[0]?.coordinate ??
        data.results?.[0]?.point ??
        data.coordinate ??
        data.point
      if (!coord) { res.status(404).json({ error: 'no coordinates in response' }); return }

      res.json({ latitude: coord.latitude, longitude: coord.longitude })
    } catch (err) {
      res.status(500).json({ error: (err as Error).message })
    }
  },
)
