/**
 * Cursor as a global directional light source for `.glass-tile` borders.
 *
 * Mental model: the cursor sits high on the +Z axis (above the page). Every
 * glass tile receives light from it at once. For each tile we compute, on
 * every frame the cursor moves:
 *
 *   --cx, --cy   cursor position in tile-local pixels (drives the proximity
 *                hotspot; CSS uses these for the radial highlight)
 *   --ang        bearing angle from tile center → cursor, in CSS conic
 *                terms (0deg = N, 90deg = E, 180deg = S, 270deg = W). The
 *                directional half of the rim CSS pivots around this so the
 *                hemisphere of the border facing the cursor lights up.
 *   --intensity  0..1 dimmer based on cursor distance to the tile's nearest
 *                edge. Far tiles still receive light (sun model), near tiles
 *                light up brighter — gentle falloff to ~0.45 at viewport edge.
 */

let installed = false
let raf = 0
let lastX = 0
let lastY = 0

const TWO_PI = Math.PI * 2
const RAD_TO_DEG = 180 / Math.PI
// Distance at which intensity bottoms out (still > 0 — the sun is always lit).
const FAR = 1400
// Floor intensity for far tiles so every glass element stays subtly lit.
const FLOOR = 0.42

function update() {
  raf = 0
  const tiles = document.querySelectorAll<HTMLElement>('.glass-tile')
  for (const el of tiles) {
    const r = el.getBoundingClientRect()
    if (r.width === 0 || r.height === 0) continue

    // Tile-local cursor coords (drives the proximity radial gradient).
    const cx = lastX - r.left
    const cy = lastY - r.top

    // Directional bearing from tile center to cursor. Screen Y grows downward,
    // CSS conic 0deg points up, increases CW; atan2(dx, -dy) is the right map.
    const dx = lastX - (r.left + r.width / 2)
    const dy = lastY - (r.top + r.height / 2)
    let ang = Math.atan2(dx, -dy) * RAD_TO_DEG
    if (ang < 0) ang += 360

    // Distance from cursor to nearest point on the tile rect — 0 if inside.
    const ex = Math.max(r.left - lastX, 0, lastX - r.right)
    const ey = Math.max(r.top - lastY, 0, lastY - r.bottom)
    const dist = Math.hypot(ex, ey)

    // Smoothstep-ish falloff from 1 (cursor on tile) → FLOOR (cursor far).
    const t = Math.min(1, dist / FAR)
    const intensity = FLOOR + (1 - FLOOR) * (1 - t * t)

    el.style.setProperty('--cx', `${cx.toFixed(0)}px`)
    el.style.setProperty('--cy', `${cy.toFixed(0)}px`)
    el.style.setProperty('--ang', `${ang.toFixed(1)}deg`)
    el.style.setProperty('--intensity', intensity.toFixed(3))
  }
  // Suppress unused-import warning for TWO_PI — kept for clarity.
  void TWO_PI
}

export function installCursorGlow() {
  if (installed || typeof window === 'undefined') return
  installed = true
  window.addEventListener('mousemove', (e) => {
    lastX = e.clientX
    lastY = e.clientY
    if (!raf) raf = requestAnimationFrame(update)
  }, { passive: true })
  // Re-run when new tiles mount on route changes
  const observer = new MutationObserver(() => { if (!raf) raf = requestAnimationFrame(update) })
  observer.observe(document.body, { childList: true, subtree: true })
}
