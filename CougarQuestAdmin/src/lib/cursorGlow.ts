/**
 * Per-tile bearing-to-cursor tracker for `.glass-tile` elements.
 *
 * Each tile gets a `<span class="glass-rim" data-liquid-glass>` injected as
 * its last child. The CSS for .glass-rim uses --ang (set here per frame)
 * to draw a conic-gradient highlight on the segment of the rim facing the
 * cursor — additive on top of the baseline box-shadow rim that's always
 * present.
 *
 * --ang     bearing tile-center → cursor in CSS conic terms
 *           (0=N, 90=E, 180=S, 270=W)
 *
 * Void HTML elements (<input>, <img>, etc.) are skipped — they cannot have
 * children, so wrap them in a div if you want the cursor highlight.
 */

let installed = false
let raf = 0
let lastX = 0
let lastY = 0
let lastUpdateAt = 0

const RAD_TO_DEG = 180 / Math.PI
// Cap rim-update rate. The cursor highlight is purely visual polish so 30fps
// is plenty — at 60fps each move reads getBoundingClientRect on every glass
// tile, which forces layout and competes with the menu's WebGL shader for
// main-thread time.
const UPDATE_INTERVAL_MS = 33

const VOID_TAGS = new Set([
  'INPUT', 'IMG', 'BR', 'HR', 'AREA', 'BASE', 'COL', 'EMBED',
  'LINK', 'META', 'PARAM', 'SOURCE', 'TRACK', 'WBR',
])

function ensureRim(el: HTMLElement) {
  if (VOID_TAGS.has(el.tagName)) return
  const last = el.lastElementChild
  if (last && last.classList.contains('glass-rim')) return
  const rim = document.createElement('span')
  rim.className = 'glass-rim'
  rim.setAttribute('data-liquid-glass', '')
  rim.setAttribute('aria-hidden', 'true')
  el.appendChild(rim)
}

function update() {
  raf = 0
  const tiles = document.querySelectorAll<HTMLElement>('.glass-tile')
  for (const el of tiles) {
    ensureRim(el)
    const r = el.getBoundingClientRect()
    if (r.width === 0 || r.height === 0) continue
    const dx = lastX - (r.left + r.width / 2)
    const dy = lastY - (r.top + r.height / 2)
    let ang = Math.atan2(dx, -dy) * RAD_TO_DEG
    if (ang < 0) ang += 360
    el.style.setProperty('--ang', `${ang.toFixed(1)}deg`)
  }
}

export function installCursorGlow() {
  if (installed || typeof window === 'undefined') return
  installed = true
  if (!raf) raf = requestAnimationFrame(update)
  window.addEventListener('mousemove', (e) => {
    lastX = e.clientX
    lastY = e.clientY
    const now = performance.now()
    if (now - lastUpdateAt < UPDATE_INTERVAL_MS) return
    lastUpdateAt = now
    if (!raf) raf = requestAnimationFrame(update)
  }, { passive: true })
  const observer = new MutationObserver(() => { if (!raf) raf = requestAnimationFrame(update) })
  observer.observe(document.body, { childList: true, subtree: true })
}
