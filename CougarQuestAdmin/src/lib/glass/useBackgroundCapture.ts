import { useEffect, useRef } from 'react';
import * as THREE from 'three';
import html2canvas from 'html2canvas';

// ============================================================================
// useBackgroundCapture — Unified background texture provider
//
// Two modes:
//   1. Static image: backgroundImage URL provided → loads as THREE.Texture
//   2. DOM capture: no backgroundImage → two sub-modes:
//      a. Fast path: detects a directly-drawable element behind the glass
//         (<video>, <canvas>, <img>) and uses ctx.drawImage in a rAF loop.
//         This gives ~60fps updates with near-zero CPU overhead.
//      b. Fallback: html2canvas full-DOM re-render at ~8fps for pure CSS/HTML
//         backgrounds that have no drawable source element.
//
// In html2canvas mode, elements marked with [data-liquid-glass] are hidden
// during capture so the glass effect doesn't photograph itself.
// ============================================================================

export interface WallpaperColors {
  avgColor: [number, number, number];
  lightDir: [number, number];
  lightIntensity: number;
}

export interface GLRef {
  material: THREE.ShaderMaterial;
  texture: THREE.Texture | null;
}

// --- Wallpaper color extraction ---
// Reuses a persistent tiny canvas to avoid per-call allocation.

const _colorCanvas = document.createElement('canvas');
_colorCanvas.width = 16;
_colorCanvas.height = 16;
const _colorCtx = _colorCanvas.getContext('2d', { willReadFrequently: true })!;

export function extractWallpaperColors(
  source: HTMLCanvasElement | HTMLImageElement | HTMLVideoElement,
): WallpaperColors {
  const sz = 16;
  try {
    _colorCtx.drawImage(source, 0, 0, sz, sz);
  } catch {
    return { avgColor: [0.5, 0.5, 0.5], lightDir: [0.3, 0.5], lightIntensity: 0.5 };
  }
  const data = _colorCtx.getImageData(0, 0, sz, sz).data;
  let rS = 0, gS = 0, bS = 0, bL = 0, bX = 0, bY = 0;
  const n = sz * sz;
  for (let y = 0; y < sz; y++)
    for (let x = 0; x < sz; x++) {
      const i = (y * sz + x) * 4;
      const r = data[i] / 255, g = data[i + 1] / 255, b = data[i + 2] / 255;
      rS += r; gS += g; bS += b;
      const l = 0.299 * r + 0.587 * g + 0.114 * b;
      if (l > bL) { bL = l; bX = x; bY = y; }
    }
  const dx = (bX / sz - 0.5) * 2, dy = (0.5 - bY / sz) * 2;
  const len = Math.hypot(dx, dy) || 1;
  return {
    avgColor: [rS / n, gS / n, bS / n],
    lightDir: [dx / len, dy / len] as [number, number],
    lightIntensity: bL,
  };
}

// ============================================================================
// Shared singleton state
// ============================================================================

let sharedTexture: THREE.CanvasTexture | null = null;
let sharedColors: WallpaperColors = {
  avgColor: [0.5, 0.5, 0.5],
  lightDir: [0.3, 0.5],
  lightIntensity: 0.5,
};
let captureGeneration = 0;
let subscriberCount = 0;

// html2canvas state
let captureTimer: number = 0;
let capturing = false;
let capturePaused = false;        // toggled by GlassMenuButton during morph
let scrollPaused = false;         // toggled by hook-level scroll listener
// CAPTURE_INTERVAL removed — captures are now event-driven (mount + menu-close).
// No periodic loop = no periodic main-thread freezes.
// CAPTURE_SCALE = 1.0 (full CSS resolution). DPR-doubling (2x) was 4× the work
// per drawImage / GPU upload and made everything glitchy; 1.0 is still ~3× the
// original 0.6 so refraction stays sharp.
const CAPTURE_SCALE = 1.0;

/** Resolve the scrollable element (admin app uses `<main>`). Cached lazily. */
let _scrollEl: HTMLElement | null | undefined = undefined;
export function getScrollElement(): HTMLElement | null {
  if (_scrollEl !== undefined) return _scrollEl;
  _scrollEl = document.querySelector<HTMLElement>('main, [data-scroll-root]');
  return _scrollEl;
}

/** Pause the html2canvas capture loop while animations run. */
export function setCapturePaused(paused: boolean) {
  capturePaused = paused;
}


// ============================================================================
// Fallback gradient — guarantees the shader always has a colorful texture
// to refract, even before html2canvas finishes its first capture (or if it
// fails entirely due to CORS-tainted images, fonts, etc.). Mirrors the body
// gradient so what the user sees and what glass refracts agree.
// ============================================================================

function paintFallbackGradient(canvas: HTMLCanvasElement) {
  const w = canvas.width, h = canvas.height;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  ctx.fillStyle = '#EEF1F7';
  ctx.fillRect(0, 0, w, h);
  const blobs: { x: number; y: number; r: number; color: string }[] = [
    { x: w * 0.90, y: h * 0.00, r: Math.max(w, h) * 0.60, color: 'rgba(255, 196,  64, 0.55)' },
    { x: w * 1.00, y: h * 0.30, r: Math.max(w, h) * 0.55, color: 'rgba(255,  99, 132, 0.40)' },
    { x: w * 0.00, y: h * 0.00, r: Math.max(w, h) * 0.65, color: 'rgba(  0,  71, 186, 0.55)' },
    { x: w * 0.30, y: h * 1.00, r: Math.max(w, h) * 0.65, color: 'rgba(110, 144, 220, 0.45)' },
    { x: w * 1.00, y: h * 1.00, r: Math.max(w, h) * 0.60, color: 'rgba(  0,  71, 186, 0.30)' },
  ];
  for (const b of blobs) {
    const g = ctx.createRadialGradient(b.x, b.y, 0, b.x, b.y, b.r);
    g.addColorStop(0, b.color);
    g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, w, h);
  }
}

function ensureFallbackTexture(): THREE.CanvasTexture {
  if (sharedTexture) return sharedTexture;
  const c = document.createElement('canvas');
  c.width = Math.max(64, Math.round(window.innerWidth * CAPTURE_SCALE));
  c.height = Math.max(64, Math.round(window.innerHeight * CAPTURE_SCALE));
  paintFallbackGradient(c);
  sharedTexture = new THREE.CanvasTexture(c);
  sharedTexture.minFilter = THREE.LinearFilter;
  sharedTexture.magFilter = THREE.LinearFilter;
  sharedTexture.wrapS = THREE.ClampToEdgeWrapping;
  sharedTexture.wrapT = THREE.ClampToEdgeWrapping;
  sharedTexture.anisotropy = 4;
  sharedColors = extractWallpaperColors(c);
  captureGeneration++;
  return sharedTexture;
}

/** Force a one-shot capture immediately (skips the interval). */
export async function requestCapture() {
  if (!capturePaused) await captureViewport();
}

// ============================================================================
// Per-frame composite: real-time scroll tracking with no html2canvas in the loop
//
// We capture the FULL page once via html2canvas (slow, blocking, but rare).
// Then on every frame we recompose what's *currently* visible into a viewport-
// sized scratch canvas: TopBar at the top + scroll-shifted main below. Two
// drawImage calls, ~1ms total. The shader samples the scratch canvas with
// simple viewport UV math — no shader changes, no UV-shift gymnastics.
// ============================================================================

let fullBodyCanvas: HTMLCanvasElement | null = null;
let topBarHeightPx = 0;
let scratchCanvas: HTMLCanvasElement | null = null;
let scratchCtx: CanvasRenderingContext2D | null = null;
let lastCompositedScroll = -1;

function ensureScratch() {
  const w = Math.round(window.innerWidth * CAPTURE_SCALE);
  const h = Math.round(window.innerHeight * CAPTURE_SCALE);
  if (!scratchCanvas || scratchCanvas.width !== w || scratchCanvas.height !== h) {
    scratchCanvas = document.createElement('canvas');
    scratchCanvas.width = w;
    scratchCanvas.height = h;
    scratchCtx = scratchCanvas.getContext('2d');
    lastCompositedScroll = -1;
  }
}

/** Recompose viewport-aligned texture from cached full-body capture + scrollY. */
export function compositeFrame(scrollY: number) {
  if (!fullBodyCanvas) return; // no full-body cache → using viewport-only fallback
  if (scrollY === lastCompositedScroll) return; // already composited for this scroll
  ensureScratch();
  if (!scratchCtx || !scratchCanvas) return;

  const W = scratchCanvas.width;
  const H = scratchCanvas.height;
  const tbH = Math.round(topBarHeightPx * CAPTURE_SCALE);
  const sY = Math.round(scrollY * CAPTURE_SCALE);

  scratchCtx.clearRect(0, 0, W, H);

  // 1) TopBar — first tbH rows of fullBody → first tbH rows of scratch.
  if (tbH > 0) {
    scratchCtx.drawImage(fullBodyCanvas, 0, 0, W, tbH, 0, 0, W, tbH);
  }
  // 2) Main — fullBody rows [tbH+sY .. tbH+sY+(H-tbH)] → scratch rows [tbH .. H].
  const mainSrcY = tbH + sY;
  const mainH = H - tbH;
  if (mainH > 0) {
    // Clamp source to fullBody bounds (avoid sampling past the captured area)
    const maxSrcY = fullBodyCanvas.height;
    const srcY = Math.max(0, Math.min(mainSrcY, maxSrcY - mainH));
    scratchCtx.drawImage(fullBodyCanvas, 0, srcY, W, mainH, 0, tbH, W, mainH);
  }

  if (sharedTexture) sharedTexture.needsUpdate = true;
  lastCompositedScroll = scrollY;
}

// Live source (drawImage) state
let liveRAF = 0;
let liveCanvas: HTMLCanvasElement | null = null;
let liveCtx: CanvasRenderingContext2D | null = null;
let liveColorFrame = 0;

// Periodic re-check for newly-available drawable sources
let sourceCheckTimer = 0;

// ============================================================================
// Fast path: direct drawImage from a background element
// ============================================================================

type DrawableSource = HTMLVideoElement | HTMLCanvasElement | HTMLImageElement;

function detectDrawableSource(): DrawableSource | null {
  // Playing video → always prefer (covers animated/live content)
  const videos = document.querySelectorAll<HTMLVideoElement>('video');
  for (const v of videos) {
    if (!v.paused && v.readyState >= 2) return v;
  }
  // Non-glass canvas
  const canvases = document.querySelectorAll<HTMLCanvasElement>('canvas:not([data-liquid-glass])');
  if (canvases.length > 0) return canvases[0];
  // Background-sized image (covers ≥50% of viewport in each dimension)
  const imgs = document.querySelectorAll<HTMLImageElement>('img');
  for (const img of imgs) {
    if (!img.complete || !img.naturalWidth) continue;
    const r = img.getBoundingClientRect();
    if (r.width >= window.innerWidth * 0.5 && r.height >= window.innerHeight * 0.5) return img;
  }
  return null;
}

function ensureLiveCanvas() {
  const w = Math.round(window.innerWidth * CAPTURE_SCALE);
  const h = Math.round(window.innerHeight * CAPTURE_SCALE);
  if (!liveCanvas || liveCanvas.width !== w || liveCanvas.height !== h) {
    liveCanvas = document.createElement('canvas');
    liveCanvas.width = w;
    liveCanvas.height = h;
    liveCtx = liveCanvas.getContext('2d')!;
    // Re-create texture pointing at the new canvas
    if (sharedTexture) {
      sharedTexture.dispose();
      sharedTexture = null;
    }
  }
  if (!sharedTexture) {
    sharedTexture = new THREE.CanvasTexture(liveCanvas);
    sharedTexture.minFilter = THREE.LinearFilter;
    sharedTexture.magFilter = THREE.LinearFilter;
    sharedTexture.wrapS = THREE.ClampToEdgeWrapping;
    sharedTexture.wrapT = THREE.ClampToEdgeWrapping;
    sharedTexture.anisotropy = 4;
  }
}

function startLiveCapture(source: DrawableSource) {
  if (liveRAF) return; // already running
  ensureLiveCanvas();

  const loop = () => {
    if (subscriberCount <= 0) { liveRAF = 0; return; }
    const w = liveCanvas!.width, h = liveCanvas!.height;

    // Resize if window changed
    const targetW = Math.round(window.innerWidth * CAPTURE_SCALE);
    const targetH = Math.round(window.innerHeight * CAPTURE_SCALE);
    if (w !== targetW || h !== targetH) {
      ensureLiveCanvas();
      // Re-apply to all materials on next color sync
    }

    try {
      liveCtx!.drawImage(source, 0, 0, liveCanvas!.width, liveCanvas!.height);
      sharedTexture!.needsUpdate = true;
      // Color extraction every 12 frames (~5fps worth at 60fps) — cheap but not free
      if (liveColorFrame++ % 12 === 0) {
        sharedColors = extractWallpaperColors(liveCanvas!);
      }
      captureGeneration++;
    } catch {
      // Source became unavailable (e.g. CORS taint) — stop and fall back
      liveRAF = 0;
      startHtml2CanvasCapture();
      return;
    }

    liveRAF = requestAnimationFrame(loop);
  };

  liveRAF = requestAnimationFrame(loop);
}

function stopLiveCapture() {
  if (liveRAF) { cancelAnimationFrame(liveRAF); liveRAF = 0; }
}

// ============================================================================
// Fallback: html2canvas full-DOM re-render
// ============================================================================

async function captureFullBodyForComposite(): Promise<boolean> {
  try {
    const main = getScrollElement();
    if (!main) return false;
    const totalH = (main.offsetTop || 0) + main.scrollHeight;
    if (totalH < window.innerHeight + 20) return false; // page fits in viewport, no benefit

    const canvas = await html2canvas(document.body, {
      scale: CAPTURE_SCALE,
      useCORS: true,
      logging: false,
      backgroundColor: null,
      removeContainer: true,
      x: 0, y: 0,
      width: window.innerWidth,
      height: totalH,
      windowWidth: window.innerWidth,
      windowHeight: totalH,
      ignoreElements: (el: Element) => el.hasAttribute('data-liquid-glass'),
      onclone: (doc) => {
        // Conservatively lift only the AppShell-specific clip ancestors.
        doc.querySelectorAll<HTMLElement>('.h-screen.overflow-hidden').forEach((el) => {
          el.style.height = 'auto';
          el.style.minHeight = '100vh';
          el.style.overflow = 'visible';
        });
        doc.querySelectorAll<HTMLElement>('main').forEach((el) => {
          el.style.overflow = 'visible';
          el.style.height = 'auto';
          el.style.maxHeight = 'none';
        });
        // Defensive: nuke the cursor-driven rim/glow overlays from the
        // clone so even if html2canvas's ignoreElements predicate misses,
        // the conic+mask gradients can never bleed into the texture.
        doc.querySelectorAll('.glass-rim, .glass-glow').forEach((el) => el.remove());
      },
    });

    if (!canvas || canvas.height < window.innerHeight * 0.95 * CAPTURE_SCALE) return false;

    fullBodyCanvas = canvas;
    const tb = document.querySelector<HTMLElement>('header.sticky');
    topBarHeightPx = tb ? tb.offsetHeight : 0;
    // Force compositeFrame to redraw on the next call even if scrollY hasn't
    // changed — otherwise a route-change re-capture lands but the scratch
    // canvas stays bound to the previous tab's pixels, and the menu refraction
    // shows yesterday's leaderboard while you're already on the campers tab.
    lastCompositedScroll = -1;
    return true;
  } catch {
    return false;
  }
}

export async function captureViewport() {
  if (capturing) return;
  capturing = true;

  try {
    // 1) Try full-body capture for the per-frame composite path. If it works,
    //    we get real-time refraction during scroll for free (compositeFrame
    //    redraws the viewport from the cached canvas every frame, ~1ms).
    const fullOk = await captureFullBodyForComposite();

    if (fullOk) {
      ensureScratch();
      compositeFrame(getScrollElement()?.scrollTop ?? 0);
      if (!sharedTexture) {
        sharedTexture = new THREE.CanvasTexture(scratchCanvas!);
        sharedTexture.minFilter = THREE.LinearFilter;
        sharedTexture.magFilter = THREE.LinearFilter;
        sharedTexture.wrapS = THREE.ClampToEdgeWrapping;
        sharedTexture.wrapT = THREE.ClampToEdgeWrapping;
        sharedTexture.anisotropy = 4;
      } else {
        sharedTexture.image = scratchCanvas!;
        sharedTexture.needsUpdate = true;
      }
      sharedColors = extractWallpaperColors(scratchCanvas!);
      captureGeneration++;
      return;
    }

    // 2) Fallback: viewport-only capture (the working baseline). No real-time
    //    scroll tracking, but visible distortion is preserved.
    fullBodyCanvas = null;
    const canvas = await html2canvas(document.body, {
      scale: CAPTURE_SCALE,
      useCORS: true,
      logging: false,
      backgroundColor: null,
      removeContainer: true,
      x: window.scrollX,
      y: window.scrollY,
      width: window.innerWidth,
      height: window.innerHeight,
      windowWidth: window.innerWidth,
      windowHeight: window.innerHeight,
      ignoreElements: (el: Element) => el.hasAttribute('data-liquid-glass'),
    });

    if (!canvas) return;

    if (!sharedTexture) {
      sharedTexture = new THREE.CanvasTexture(canvas);
      sharedTexture.minFilter = THREE.LinearFilter;
      sharedTexture.magFilter = THREE.LinearFilter;
      sharedTexture.wrapS = THREE.ClampToEdgeWrapping;
      sharedTexture.wrapT = THREE.ClampToEdgeWrapping;
      sharedTexture.anisotropy = 4;
    } else {
      sharedTexture.image = canvas;
      sharedTexture.needsUpdate = true;
    }

    sharedColors = extractWallpaperColors(canvas);
    captureGeneration++;
  } catch { /* silently ignore */ }

  capturing = false;
}

function startHtml2CanvasCapture() {
  // ONE capture on subscription start (event-driven model — the hook also fires
  // captureViewport on scroll-end and menu-close, so there's no need for a
  // periodic loop that would freeze the main thread every CAPTURE_INTERVAL).
  if (captureTimer) return;
  captureTimer = window.setTimeout(async () => {
    captureTimer = 0;
    const source = detectDrawableSource();
    if (source) { startLiveCapture(source); return; }
    if (!capturePaused && !scrollPaused) {
      await captureViewport();
    }
  }, 0);
}

function stopHtml2CanvasCapture() {
  if (captureTimer) { clearTimeout(captureTimer); captureTimer = 0; }
}

// ============================================================================
// Unified start/stop
// ============================================================================

function startCapture() {
  if (liveRAF || captureTimer) return;
  const source = detectDrawableSource();
  if (source) {
    startLiveCapture(source);
  } else {
    startHtml2CanvasCapture();
  }
  // Periodically check if a video starts playing so we can upgrade to fast path
  if (!sourceCheckTimer) {
    sourceCheckTimer = window.setInterval(() => {
      if (subscriberCount <= 0) {
        clearInterval(sourceCheckTimer); sourceCheckTimer = 0; return;
      }
      if (!liveRAF) {
        const src = detectDrawableSource();
        if (src) { stopHtml2CanvasCapture(); startLiveCapture(src); }
      }
    }, 1500);
  }
}

function stopCapture() {
  stopLiveCapture();
  stopHtml2CanvasCapture();
  if (sourceCheckTimer) { clearInterval(sourceCheckTimer); sourceCheckTimer = 0; }
}

// ============================================================================
// Apply texture + colors to a GL material
// ============================================================================

function applyToMaterial(
  gl: GLRef,
  tex: THREE.Texture,
  colors: WallpaperColors,
  ownsTexture: boolean,
) {
  if (ownsTexture && gl.texture && gl.texture !== tex) gl.texture.dispose();
  if (ownsTexture) gl.texture = tex;
  gl.material.uniforms.uBackgroundTexture.value = tex;
  gl.material.uniforms.uWallpaperTint.value.set(...colors.avgColor);
  gl.material.uniforms.uLightDir.value.set(...colors.lightDir);
  gl.material.uniforms.uLightIntensity.value = colors.lightIntensity;
}

// ============================================================================
// Hook
// ============================================================================

export function useBackgroundCapture(
  backgroundImage: string | undefined,
  glRef: React.RefObject<GLRef | null>,
  onReady?: () => void,
) {
  const appliedGenRef = useRef(-1);

  // --- Static image mode ---
  useEffect(() => {
    if (!backgroundImage) return;
    const loader = new THREE.TextureLoader();
    let cancelled = false;

    const attempt = () => {
      if (cancelled) return;
      if (!glRef.current) { requestAnimationFrame(attempt); return; }
      loader.load(backgroundImage, (tex) => {
        if (cancelled) { tex.dispose(); return; }
        tex.minFilter = THREE.LinearFilter;
        tex.magFilter = THREE.LinearFilter;
        tex.wrapS = THREE.ClampToEdgeWrapping;
        tex.wrapT = THREE.ClampToEdgeWrapping;
        const gl = glRef.current;
        if (gl) {
          const colors = extractWallpaperColors(tex.image as HTMLImageElement);
          applyToMaterial(gl, tex, colors, true);
          onReady?.();
        }
      });
    };
    attempt();
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [backgroundImage]);

  // --- DOM capture mode ---
  useEffect(() => {
    if (backgroundImage) return;

    // Prime a synthetic gradient texture so the shader has rich content to
    // refract immediately, even before the first html2canvas frame lands
    // (or if it never does because of a CORS-tainted image).
    ensureFallbackTexture();

    subscriberCount++;
    startCapture();

    let cancelled = false;
    let scrollResumeTimer = 0;

    // Pause captures while the user is actively scrolling — html2canvas blocks
    // the main thread for ~250ms per call, which kills 60fps scroll. After
    // scroll-end + a short debounce, fire ONE capture so the texture catches up.
    const onScroll = () => {
      scrollPaused = true;
      window.clearTimeout(scrollResumeTimer);
      scrollResumeTimer = window.setTimeout(async () => {
        scrollPaused = false;
        if (!capturePaused) await captureViewport();
      }, 180);
    };
    window.addEventListener('scroll', onScroll, { capture: true, passive: true });
    window.addEventListener('wheel', onScroll, { capture: true, passive: true });
    window.addEventListener('touchmove', onScroll, { capture: true, passive: true });

    // Scroll listeners on the actual scrollable element. `<scroll>` events do
    // NOT bubble, so window-level listeners miss scroll on inner overflow:auto
    // containers (the admin app scrolls <main>, not document). Hook them up
    // directly to every scrollable descendant.
    const scrollables = Array.from(document.querySelectorAll<HTMLElement>('main, [data-scroll-root]'));
    for (const el of scrollables) {
      el.addEventListener('scroll', onScroll, { passive: true });
    }

    // Wire up shared texture (now non-null thanks to the fallback)
    const waitAndApply = () => {
      if (cancelled) return;
      const gl = glRef.current;
      if (gl && sharedTexture) {
        applyToMaterial(gl, sharedTexture, sharedColors, false);
        appliedGenRef.current = captureGeneration;
        onReady?.();
      } else {
        requestAnimationFrame(waitAndApply);
      }
    };
    waitAndApply();

    // Sync colors + texture pointer as captures update.
    // Use rAF for the live path (color updates at ~5fps), timer for html2canvas.
    const syncInterval = setInterval(() => {
      const gl = glRef.current;
      if (!gl || !sharedTexture) return;
      if (captureGeneration === appliedGenRef.current) return;

      // Re-wire texture pointer in case it was re-created (e.g. after resize)
      if (gl.material.uniforms.uBackgroundTexture.value !== sharedTexture) {
        gl.material.uniforms.uBackgroundTexture.value = sharedTexture;
      }
      gl.material.uniforms.uWallpaperTint.value.set(...sharedColors.avgColor);
      gl.material.uniforms.uLightDir.value.set(...sharedColors.lightDir);
      gl.material.uniforms.uLightIntensity.value = sharedColors.lightIntensity;
      appliedGenRef.current = captureGeneration;
    }, 150);

    return () => {
      cancelled = true;
      clearInterval(syncInterval);
      window.clearTimeout(scrollResumeTimer);
      window.removeEventListener('scroll', onScroll, { capture: true } as AddEventListenerOptions);
      window.removeEventListener('wheel', onScroll, { capture: true } as AddEventListenerOptions);
      window.removeEventListener('touchmove', onScroll, { capture: true } as AddEventListenerOptions);
      for (const el of scrollables) el.removeEventListener('scroll', onScroll);
      subscriberCount--;
      if (subscriberCount <= 0) {
        stopCapture();
        subscriberCount = 0;
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [backgroundImage]);
}
