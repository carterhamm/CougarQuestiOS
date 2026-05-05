/**
 * Cursor as a directional light source for `.glass-tile` elements.
 *
 * Each tile gets TWO children auto-injected:
 *   <span class="glass-glow" data-liquid-glass>  — first  (behind content)
 *   <span class="glass-rim"  data-liquid-glass>  — last   (above content)
 * Both have data-liquid-glass so html2canvas's ignoreElements predicate
 * excludes them from the menu's refraction texture.
 *
 * Per frame we set on each tile:
 *   --cx, --cy   cursor in tile-local pixels (drives radial bloom + glow)
 *   --ang        bearing tile-center → cursor (CSS conic 0=N / 90=E)
 *
 * Void HTML elements (<input>, <img>, etc.) cannot have children, so we
 * skip them — wrap such elements in a div with .glass-tile if you want
 * the rim treatment.
 */

let installed = false
let raf = 0
let lastX = 0
let lastY = 0

const RAD_TO_DEG = 180 / Math.PI

const VOID_TAGS = new Set([
  'INPUT', 'IMG', 'BR', 'HR', 'AREA', 'BASE', 'COL', 'EMBED',
  'LINK', 'META', 'PARAM', 'SOURCE', 'TRACK', 'WBR',
])

function ensureChildren(el: HTMLElement) {
  if (VOID_TAGS.has(el.tagName)) return
  let glow = el.firstElementChild
  if (!glow || !glow.classList.contains('glass-glow')) {
    glow = document.createElement('span')
    glow.className = 'glass-glow'
    glow.setAttribute('data-liquid-glass', '')
    glow.setAttribute('aria-hidden', 'true')
    el.prepend(glow)
  }
  let rim = el.lastElementChild
  if (!rim || !rim.classList.contains('glass-rim')) {
    rim = document.createElement('span')
    rim.className = 'glass-rim'
    rim.setAttribute('data-liquid-glass', '')
    rim.setAttribute('aria-hidden', 'true')
    el.appendChild(rim)
  }
}

// Max attractive translate, in pixels. The tile shifts THIS much toward the
// cursor when the cursor is right on top; falls off with proximity.
const TILT_MAX = 1.6
// Distance at which the tilt has fully decayed.
const TILT_FAR = 520

function update() {
  raf = 0
  const tiles = document.querySelectorAll<HTMLElement>('.glass-tile')
  for (const el of tiles) {
    ensureChildren(el)
    const r = el.getBoundingClientRect()
    if (r.width === 0 || r.height === 0) continue

    const cx = lastX - r.left
    const cy = lastY - r.top

    const dx = lastX - (r.left + r.width / 2)
    const dy = lastY - (r.top + r.height / 2)
    let ang = Math.atan2(dx, -dy) * RAD_TO_DEG
    if (ang < 0) ang += 360

    // Subtle attractive shift: cursor right → tile leans right by ~1px.
    // Falls off with distance so far-away tiles don't twitch when cursor moves.
    const dist = Math.hypot(dx, dy)
    const proximity = Math.max(0, 1 - dist / TILT_FAR)
    const dirLen = Math.max(1, dist)
    const tx = (dx / dirLen) * TILT_MAX * proximity
    const ty = (dy / dirLen) * TILT_MAX * proximity

    const s = el.style
    s.setProperty('--cx', `${cx.toFixed(0)}px`)
    s.setProperty('--cy', `${cy.toFixed(0)}px`)
    s.setProperty('--ang', `${ang.toFixed(1)}deg`)
    s.setProperty('--tx', `${tx.toFixed(2)}px`)
    s.setProperty('--ty', `${ty.toFixed(2)}px`)
  }
}

export function installCursorGlow() {
  if (installed || typeof window === 'undefined') return
  installed = true
  if (!raf) raf = requestAnimationFrame(update)
  window.addEventListener('mousemove', (e) => {
    lastX = e.clientX
    lastY = e.clientY
    if (!raf) raf = requestAnimationFrame(update)
  }, { passive: true })
  const observer = new MutationObserver(() => { if (!raf) raf = requestAnimationFrame(update) })
  observer.observe(document.body, { childList: true, subtree: true })
}
