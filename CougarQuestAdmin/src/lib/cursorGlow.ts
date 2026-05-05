/**
 * Cursor as a global directional light source for `.glass-tile` rims.
 *
 * The rim is split in two:
 *   1) BASE   — `box-shadow: inset 0 0 0 0.84px ...` on the .glass-tile
 *               itself. Uniform width, uniform opacity, captured by
 *               html2canvas so the rim survives into the glass-menu
 *               refraction.
 *   2) CURSOR — a `<span class="glass-rim" data-liquid-glass>` injected
 *               here as the first child of every .glass-tile. Same 0.84px
 *               ring shape; opacity along the perimeter is driven by the
 *               cursor. data-liquid-glass causes html2canvas's
 *               ignoreElements filter to skip it, so the cursor-light
 *               overlay never pollutes the captured texture.
 *
 * Per-frame we set on each tile:
 *   --cx, --cy   cursor position in tile-local pixels (proximity hotspot)
 *   --ang        bearing tile-center → cursor in CSS conic terms
 *                (0 = N, 90 = E, 180 = S, 270 = W)
 *   --intensity  0..1 distance falloff (floored — never zero)
 */

let installed = false
let raf = 0
let lastX = 0
let lastY = 0

const RAD_TO_DEG = 180 / Math.PI
const FAR = 1400
const FLOOR = 0.42

function ensureRim(el: HTMLElement) {
  // First child is our rim if it has the right class. Inject if missing.
  const first = el.firstElementChild
  if (first && first.classList.contains('glass-rim')) return
  const rim = document.createElement('span')
  rim.className = 'glass-rim'
  rim.setAttribute('data-liquid-glass', '')
  rim.setAttribute('aria-hidden', 'true')
  el.prepend(rim)
}

function update() {
  raf = 0
  const tiles = document.querySelectorAll<HTMLElement>('.glass-tile')
  for (const el of tiles) {
    ensureRim(el)
    const r = el.getBoundingClientRect()
    if (r.width === 0 || r.height === 0) continue

    const cx = lastX - r.left
    const cy = lastY - r.top

    const dx = lastX - (r.left + r.width / 2)
    const dy = lastY - (r.top + r.height / 2)
    let ang = Math.atan2(dx, -dy) * RAD_TO_DEG
    if (ang < 0) ang += 360

    const ex = Math.max(r.left - lastX, 0, lastX - r.right)
    const ey = Math.max(r.top - lastY, 0, lastY - r.bottom)
    const dist = Math.hypot(ex, ey)

    const t = Math.min(1, dist / FAR)
    const intensity = FLOOR + (1 - FLOOR) * (1 - t * t)

    const s = el.style
    s.setProperty('--cx', `${cx.toFixed(0)}px`)
    s.setProperty('--cy', `${cy.toFixed(0)}px`)
    s.setProperty('--ang', `${ang.toFixed(1)}deg`)
    s.setProperty('--intensity', intensity.toFixed(3))
  }
}

export function installCursorGlow() {
  if (installed || typeof window === 'undefined') return
  installed = true
  // Initial pass to inject rims and place lights even before first mousemove.
  if (!raf) raf = requestAnimationFrame(update)
  window.addEventListener('mousemove', (e) => {
    lastX = e.clientX
    lastY = e.clientY
    if (!raf) raf = requestAnimationFrame(update)
  }, { passive: true })
  // Re-run when new tiles mount on route changes
  const observer = new MutationObserver(() => { if (!raf) raf = requestAnimationFrame(update) })
  observer.observe(document.body, { childList: true, subtree: true })
}
