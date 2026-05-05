/**
 * Cursor as a directional light source for `.glass-tile` rims.
 *
 * Each tile gets a `<span class="glass-rim" data-liquid-glass>` auto-injected
 * as the first child. The rim's CSS uses `--cx,--cy,--ang` (set here per
 * frame) to draw an opacity-varying ring whose cursor-facing segment is
 * 100% opaque and whose far segment fades to 0%.
 *
 * Tiles inside a [data-liquid-glass] subtree (the glass menu) are skipped —
 * their refraction shader handles its own visual edges and we don't want our
 * rim competing with it.
 *
 * data-liquid-glass on the rim itself excludes it from html2canvas capture so
 * the rim never appears in the menu's refracted texture.
 */

let installed = false
let raf = 0
let lastX = 0
let lastY = 0

const RAD_TO_DEG = 180 / Math.PI

function ensureRim(el: HTMLElement) {
  // Don't inject into glass-menu elements — they manage their own visuals.
  if (el.closest('[data-liquid-glass]')) return
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
    if (el.closest('[data-liquid-glass]')) continue
    ensureRim(el)
    const r = el.getBoundingClientRect()
    if (r.width === 0 || r.height === 0) continue

    const cx = lastX - r.left
    const cy = lastY - r.top

    const dx = lastX - (r.left + r.width / 2)
    const dy = lastY - (r.top + r.height / 2)
    let ang = Math.atan2(dx, -dy) * RAD_TO_DEG
    if (ang < 0) ang += 360

    const s = el.style
    s.setProperty('--cx', `${cx.toFixed(0)}px`)
    s.setProperty('--cy', `${cy.toFixed(0)}px`)
    s.setProperty('--ang', `${ang.toFixed(1)}deg`)
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
