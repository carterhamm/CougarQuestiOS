import React, { useRef, useEffect, useLayoutEffect, useState, useCallback } from 'react';
import { createPortal } from 'react-dom';
import * as THREE from 'three';
import { vertexShader, containerFragmentShader } from './shaders';
import {
  useBackgroundCapture,
  setCapturePaused,
  captureViewport,
  compositeFrame,
  getScrollElement,
} from './useBackgroundCapture';

// ============================================================================
// GlassMenuButton — iOS menu morph animation with Liquid Glass
// Pill button morphs into a dropdown menu via spring-animated shape.
// The entire shape (pill and menu) is rendered as gray-tinted liquid glass.
// Corners expand last during opening for a natural liquid feel.
// ============================================================================

const MAX_SHAPES = 12;

// --- Spring physics ---
interface SpringCfg { omega: number; k: number; zeta: number }
interface Sp { v: number; vel: number; t: number }

function springCfg(response: number, damping: number): SpringCfg {
  const omega = (2 * Math.PI) / response;
  return { omega, k: omega * omega, zeta: damping };
}

function stepSp(s: Sp, dt: number, c: SpringCfg): Sp {
  const d = s.v - s.t;
  const a = -c.k * d - 2 * c.zeta * c.omega * s.vel;
  return { v: s.v + s.vel * dt, vel: s.vel + a * dt, t: s.t };
}

function settled(s: Sp): boolean {
  return Math.abs(s.v - s.t) < 0.01 && Math.abs(s.vel) < 0.1;
}

// Forward: slightly underdamped for fluid feel, minimal overshoot
const SP_SHAPE = springCfg(0.45, 0.88);
const SP_POS = springCfg(0.45, 0.88);
// Reverse: slightly underdamped for satisfying snap-back
const SP_REV = springCfg(0.43, 0.70);
const SP_CORNER = springCfg(0.50, 0.90);

function keyLerp(keys: [number, number][], p: number): number {
  if (p <= keys[0][0]) return keys[0][1];
  if (p >= keys[keys.length - 1][0]) return keys[keys.length - 1][1];
  for (let i = 0; i < keys.length - 1; i++) {
    const [p0, v0] = keys[i];
    const [p1, v1] = keys[i + 1];
    if (p >= p0 && p <= p1) {
      const t = (p - p0) / (p1 - p0);
      const s = t * t * (3 - 2 * t);
      return v0 + (v1 - v0) * s;
    }
  }
  return keys[keys.length - 1][1];
}

interface MorphTarget {
  pillCx: number; pillCy: number;
  pillWidth: number; pillHeight: number;
  pillRight: number; pillTop: number;
  menuWidth: number; menuHeight: number; menuRadius: number;
}

interface AnimSprings {
  shape: Sp;
  pos: Sp;
  corner: Sp;
  content: Sp;
  direction: 'forward' | 'reverse';
}

export interface MenuItemDef {
  label?: string;
  shortcut?: string;
  icon?: React.ReactNode;
  sep?: boolean;
  onClick?: () => void;
}

export interface GlassMenuButtonProps {
  label?: React.ReactNode;
  menuItems: MenuItemDef[];
  pillWidth?: number;
  pillHeight?: number;
  menuWidth?: number;
  menuRadius?: number;
  backgroundImage?: string;
  menuHeader?: React.ReactNode;
  /** Base tint strength while idle (0 = clear glass, 0.6 = strong gray). Default 0 (Apple demo). */
  pillBaseTint?: number;
}

export const GlassMenuButton: React.FC<GlassMenuButtonProps> = ({
  label = 'Menu',
  menuItems,
  pillWidth: PILL_W = 100,
  pillHeight: PILL_H = 40,
  menuWidth: MENU_W = 260,
  menuRadius: MENU_R = 9,
  backgroundImage,
  menuHeader,
  pillBaseTint = 0,
}) => {
  // Initial estimate; replaced by measurement once content lays out.
  const initialMenuH = menuItems.reduce((h, item) => h + (item.sep ? 7 : 34), 0) + 12 + (menuHeader ? 60 : 0);
  const [MENU_H, setMenuH] = useState(initialMenuH);
  const PAD = 20;
  const DROP = 70;

  const pillRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const measureRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const mouseRef = useRef({ x: 0.5, y: 0.5 });
  const rafRef = useRef(0);
  const lastTRef = useRef(0);
  const springsRef = useRef<AnimSprings | null>(null);
  const targetRef = useRef<MorphTarget | null>(null);
  const isOpenRef = useRef(false);
  const settledStateRef = useRef<{ width: number; height: number; cx: number; cy: number; cornerRadius: number } | null>(null);

  const [isOpen, setIsOpen] = useState(false);
  const [pillHidden, setPillHidden] = useState(false);

  // Keep ref in sync with state for rAF access
  useEffect(() => { isOpenRef.current = isOpen; }, [isOpen]);

  // Auto-measure menu height from a hidden render of the actual content.
  useLayoutEffect(() => {
    const el = measureRef.current;
    if (!el) return;
    const h = Math.ceil(el.getBoundingClientRect().height);
    if (h > 0 && Math.abs(h - MENU_H) > 1) setMenuH(h);
  }, [menuItems, menuHeader, MENU_W, MENU_H]);

  const glRef = useRef<{
    renderer: THREE.WebGLRenderer;
    scene: THREE.Scene;
    camera: THREE.OrthographicCamera;
    material: THREE.ShaderMaterial;
    texture: THREE.Texture | null;
  } | null>(null);

  // --- Three.js Init ---
  // Gray-tinted glass: higher thickness for more absorption, muted tint
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const dpr = window.devicePixelRatio;
    const renderer = new THREE.WebGLRenderer({
      canvas, alpha: true, antialias: true, premultipliedAlpha: false,
      powerPreference: 'high-performance',
    });
    renderer.setPixelRatio(dpr);
    renderer.setClearColor(0x000000, 0);

    const scene = new THREE.Scene();
    const camera = new THREE.OrthographicCamera(-0.5, 0.5, 0.5, -0.5, 0.1, 10);
    camera.position.z = 1;

    const positions: THREE.Vector2[] = [];
    const sizes: THREE.Vector2[] = [];
    for (let i = 0; i < MAX_SHAPES; i++) {
      positions.push(new THREE.Vector2(0, 0));
      sizes.push(new THREE.Vector2(0, 0));
    }

    const material = new THREE.ShaderMaterial({
      vertexShader,
      fragmentShader: containerFragmentShader,
      transparent: true,
      depthTest: false,
      uniforms: {
        uBackgroundTexture: { value: null },
        uResolution: { value: new THREE.Vector2(100, 100) },
        uContainerPosition: { value: new THREE.Vector2(0, 0) },
        uContainerSize: { value: new THREE.Vector2(1, 1) },
        uThickness: { value: 8.0 },        // higher = more Beer's law absorption = darker/grayer
        uIor: { value: 1.5 },
        uDispersion: { value: new THREE.Vector3(0.01, 0.005, 0.015) },
        uOpacity: { value: 0.92 },
        uBlurRadius: { value: 18 },         // more blur = frosted gray look
        uTime: { value: 0 },
        uMouse: { value: new THREE.Vector2(0.5, 0.5) },
        uReducedMotion: { value: 0 },
        uAberrationIntensity: { value: 0.6 },
        uWallpaperTint: { value: new THREE.Vector3(0.35, 0.35, 0.38) }, // gray tint
        uLightDir: { value: new THREE.Vector2(0.3, 0.5) },
        uLightIntensity: { value: 0.4 },
        uMorphSmoothness: { value: 0.06 },
        uEdgeFalloff: { value: 0.0 },
        uGlassTint: { value: new THREE.Vector4(0.28, 0.28, 0.32, 0.45) }, // gray tint
        uShapeCount: { value: 1 },
        uShapePositions: { value: positions },
        uShapeSizes: { value: sizes },
        uShapeTypes: { value: new Array(MAX_SHAPES).fill(0) },
        uShapeRadii: { value: new Array(MAX_SHAPES).fill(0.5) },
        uShapeAnim: { value: new Array(MAX_SHAPES).fill(1) },
      },
    });

    const geometry = new THREE.PlaneGeometry(1, 1);
    scene.add(new THREE.Mesh(geometry, material));
    glRef.current = { renderer, scene, camera, material, texture: null };

    return () => {
      cancelAnimationFrame(rafRef.current);
      geometry.dispose(); material.dispose(); renderer.dispose();
      if (glRef.current?.texture) glRef.current.texture.dispose();
      glRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useBackgroundCapture(backgroundImage, glRef);

  // --- Get morph target from pill position ---
  const getTarget = useCallback((): MorphTarget => {
    const r = pillRef.current!.getBoundingClientRect();
    return {
      pillRight: r.right,
      pillTop: r.top,
      pillCx: r.left + r.width / 2,
      pillCy: r.top + r.height / 2,
      pillWidth: PILL_W,
      pillHeight: PILL_H,
      menuWidth: MENU_W,
      menuHeight: MENU_H,
      menuRadius: MENU_R,
    };
  }, [PILL_W, PILL_H, MENU_W, MENU_H, MENU_R]);

  const createSprings = useCallback((direction: 'forward' | 'reverse'): AnimSprings => {
    if (direction === 'forward') {
      return {
        shape: { v: 0, vel: 2.2, t: 1 },
        pos: { v: 0, vel: 2.2, t: 1 },
        corner: { v: 0, vel: 1.6, t: 1 },
        content: { v: 0, vel: 0, t: 0 },
        direction,
      };
    } else {
      return {
        shape: { v: 1, vel: -2, t: 0 },
        pos: { v: 1, vel: -2, t: 0 },
        corner: { v: 1, vel: -1.5, t: 0 },
        content: { v: 1, vel: -3, t: 0 },
        direction,
      };
    }
  }, []);

  const readMorphState = useCallback((s: AnimSprings, t: MorphTarget) => {
    const sp = Math.max(0, Math.min(1, s.shape.v));
    const pp = Math.max(-0.05, Math.min(1.15, s.pos.v));
    const cp = Math.max(0, Math.min(1, s.corner.v));

    const circle = t.pillHeight;
    const vertW = t.menuWidth * 0.7;
    const vertH = t.menuHeight * 0.7;

    const width = keyLerp([
      [0.00, t.pillWidth], [0.18, circle], [0.38, circle],
      [0.62, vertW], [1.00, t.menuWidth],
    ], sp);

    const height = keyLerp([
      [0.00, t.pillHeight], [0.18, circle], [0.38, circle],
      [0.62, vertH], [1.00, t.menuHeight],
    ], sp);

    const dropTop = t.pillCy + DROP - circle / 2;
    const vertCy = dropTop + vertH / 2;
    const finalCy = t.pillTop + t.menuHeight / 2;

    const cy = keyLerp([
      [0.00, t.pillCy], [0.15, t.pillCy],
      [0.38, t.pillCy + DROP], [0.62, vertCy], [1.00, finalCy],
    ], pp);

    const cx = keyLerp([
      [0.00, t.pillCx], [0.38, t.pillCx],
      [0.62, t.pillRight - vertW / 2], [1.00, t.pillRight - t.menuWidth / 2],
    ], sp);

    const maxRound = Math.min(width, height) / 2;
    // Corners stay rounded during expansion, un-round at the end
    const cr = keyLerp([
      [0.00, t.pillHeight / 2], [0.62, Math.min(vertW, vertH) / 2],
      [0.82, Math.min(vertW, vertH) / 2], [0.95, t.menuRadius],
      [1.00, t.menuRadius],
    ], cp);

    return {
      width: Math.max(1, width),
      height: Math.max(1, height),
      cornerRadius: Math.min(cr, maxRound),
      cx, cy,
      contentOpacity: Math.max(0, Math.min(1, s.content.v)),
    };
  }, [DROP]);

  // --- Glass render helper ---
  const renderGlass = useCallback((gl: NonNullable<typeof glRef.current>, state: { width: number; height: number; cx: number; cy: number; cornerRadius: number }, tintStrength = 0.0) => {
    const dpr = window.devicePixelRatio;
    const sw = window.innerWidth;
    const sh = window.innerHeight;
    const cLeft = state.cx - state.width / 2 - PAD;
    const cTop = state.cy - state.height / 2 - PAD;
    const canvasW = state.width + 2 * PAD;
    const canvasH = state.height + 2 * PAD;

    const wrap = wrapRef.current;
    if (wrap) {
      wrap.style.display = 'block';
      wrap.style.position = 'fixed';
      wrap.style.left = `${cLeft}px`;
      wrap.style.top = `${cTop}px`;
      wrap.style.width = `${canvasW}px`;
      wrap.style.height = `${canvasH}px`;
      wrap.style.zIndex = '101';
      wrap.style.pointerEvents = 'none';
    }

    // If a full-body capture is cached, recompose the viewport-aligned texture
    // from it using the live scrollTop. Cheap (~1ms) and tracks scroll at 60fps.
    // No-op when only viewport-only capture is active.
    const scrollEl = getScrollElement();
    compositeFrame(scrollEl ? scrollEl.scrollTop : 0);

    gl.renderer.setSize(canvasW, canvasH);
    const u = gl.material.uniforms;
    u.uResolution.value.set(canvasW * dpr, canvasH * dpr);
    u.uTime.value = performance.now() * 0.001;
    u.uMouse.value.set(mouseRef.current.x, mouseRef.current.y);

    u.uContainerPosition.value.set(cLeft / sw, 1.0 - (cTop + canvasH) / sh);
    u.uContainerSize.value.set(canvasW / sw, canvasH / sh);

    const positions = u.uShapePositions.value as THREE.Vector2[];
    const sizes = u.uShapeSizes.value as THREE.Vector2[];
    positions[0].set(0.5, 0.5);
    sizes[0].set((state.width / 2) / canvasW, (state.height / 2) / canvasH);
    const maxHalf = Math.min(state.width, state.height) / 2;
    u.uShapeRadii.value[0] = Math.min(state.cornerRadius / maxHalf, 0.5);
    u.uShapeAnim.value[0] = 1.0;
    u.uShapeCount.value = 1;

    // Dynamic gray tint — 0 for pill, ramps up for expanded menu
    u.uGlassTint.value.set(0.22, 0.22, 0.25, tintStrength);

    gl.renderer.render(gl.scene, gl.camera);
  }, [PAD]);

  // --- Animation loop ---
  useEffect(() => {
    const loop = () => {
      const springs = springsRef.current;
      const target = targetRef.current;
      const gl = glRef.current;
      const pill = pillRef.current;

      if (!springs || !target) {
        // Not animating
        if (isOpenRef.current && gl && settledStateRef.current) {
          // Menu is open — keep rendering at exact settled state (no recalc)
          renderGlass(gl, settledStateRef.current, 0);
        } else if (!isOpenRef.current && gl && pill) {
          // Idle — render glass at pill position
          const pr = pill.getBoundingClientRect();
          if (pr.width > 0) {
            renderGlass(gl, {
              width: pr.width, height: pr.height,
              cx: pr.left + pr.width / 2,
              cy: pr.top + pr.height / 2,
              cornerRadius: PILL_H / 2,
            }, pillBaseTint);
          }
        } else {
          const wrap = wrapRef.current;
          if (wrap) wrap.style.display = 'none';
        }
        rafRef.current = requestAnimationFrame(loop);
        return;
      }

      // Animating
      const now = performance.now();
      const dt = Math.min((now - lastTRef.current) / 1000, 0.033);
      lastTRef.current = now;

      if (springs.direction === 'forward') {
        springs.shape = stepSp(springs.shape, dt, SP_SHAPE);
        springs.pos = stepSp(springs.pos, dt, SP_POS);
        springs.corner = stepSp(springs.corner, dt, SP_CORNER);
        springs.content = stepSp(springs.content, dt, SP_REV);
        if (springs.shape.v > 0.75) springs.content.t = 1;
      } else {
        springs.shape = stepSp(springs.shape, dt, SP_REV);
        springs.pos = stepSp(springs.pos, dt, SP_REV);
        springs.corner = stepSp(springs.corner, dt, SP_REV);
        springs.content = stepSp(springs.content, dt, SP_REV);
      }

      // Reverse snap
      if (springs.direction === 'reverse' && springs.shape.v < 0.15) {
        springsRef.current = null;
        setPillHidden(false);
        setIsOpen(false);
        setCapturePaused(false);
        // Refresh page snapshot for next open — defer so the snap-back
        // animation completes smoothly before html2canvas blocks main thread.
        const idle = (window as unknown as { requestIdleCallback?: (cb: () => void) => void }).requestIdleCallback;
        if (idle) idle(() => captureViewport());
        else setTimeout(() => captureViewport(), 600);
        pillRef.current?.animate([
          { transform: 'scale(0.88)', offset: 0 },
          { transform: 'scale(1.1)', offset: 0.4 },
          { transform: 'scale(0.96)', offset: 0.7 },
          { transform: 'scale(1.02)', offset: 0.88 },
          { transform: 'scale(1)', offset: 1 },
        ], { duration: 400, easing: 'ease-out' });
        rafRef.current = requestAnimationFrame(loop);
        return;
      }

      const state = readMorphState(springs, target);

      // Position menu content overlay
      const menu = menuRef.current;
      if (menu) {
        menu.style.top = `${state.cy - state.height / 2}px`;
        menu.style.left = `${state.cx - state.width / 2}px`;
        menu.style.width = `${state.width}px`;
        menu.style.height = `${state.height}px`;
        menu.style.opacity = `${state.contentOpacity}`;
        menu.style.borderRadius = `${state.cornerRadius}px`;
        menu.style.pointerEvents = state.contentOpacity > 0.5 ? 'all' : 'none';
      }

      // Clear glass throughout. No frosting — pure refraction so lens
      // distortion + chromatic aberration are fully visible.
      const MENU_TINT = 0;
      const tint = pillBaseTint + (MENU_TINT - pillBaseTint) * Math.max(0, Math.min(1, springs.shape.v));
      if (gl) renderGlass(gl, state, tint);

      // Settled — snap springs to exact target then compute final state
      // through readMorphState so there's zero discontinuity
      if (settled(springs.shape) && settled(springs.pos) && settled(springs.corner) && settled(springs.content)) {
        springs.shape.v = springs.shape.t; springs.shape.vel = 0;
        springs.pos.v = springs.pos.t; springs.pos.vel = 0;
        springs.corner.v = springs.corner.t; springs.corner.vel = 0;
        springs.content.v = springs.content.t; springs.content.vel = 0;
        const finalState = readMorphState(springs, target);
        settledStateRef.current = finalState;
        const menu = menuRef.current;
        if (menu) {
          menu.style.top = `${finalState.cy - finalState.height / 2}px`;
          menu.style.left = `${finalState.cx - finalState.width / 2}px`;
          menu.style.width = `${finalState.width}px`;
          menu.style.height = `${finalState.height}px`;
          menu.style.borderRadius = `${finalState.cornerRadius}px`;
        }
        if (gl) renderGlass(gl, finalState, 0.6);
        springsRef.current = null;
        // Resume captures while menu sits open (so refraction stays fresh if page changes)
        setCapturePaused(false);
      }

      rafRef.current = requestAnimationFrame(loop);
    };

    rafRef.current = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(rafRef.current);
  }, [PILL_H, readMorphState, renderGlass]);

  // --- Open / Close ---
  const open = useCallback(() => {
    if (springsRef.current) return;
    const target = getTarget();
    targetRef.current = target;
    setPillHidden(true);
    setIsOpen(true);
    settledStateRef.current = null;
    // Pause html2canvas captures so the morph stays at 60fps; resume after settled.
    setCapturePaused(true);
    springsRef.current = createSprings('forward');
    lastTRef.current = performance.now();
  }, [getTarget, createSprings]);

  const close = useCallback(() => {
    if (springsRef.current?.direction === 'reverse') return;
    const target = targetRef.current ?? getTarget();
    targetRef.current = target;
    setCapturePaused(true);
    springsRef.current = createSprings('reverse');
    lastTRef.current = performance.now();
  }, [getTarget, createSprings]);

  // Resume captures whenever no spring animation is active.
  useEffect(() => {
    return () => setCapturePaused(false);
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape' && isOpenRef.current) close(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [close]);

  useEffect(() => {
    const onMouse = (e: MouseEvent) => {
      mouseRef.current = { x: e.clientX / window.innerWidth, y: 1 - e.clientY / window.innerHeight };
    };
    window.addEventListener('mousemove', onMouse);
    return () => window.removeEventListener('mousemove', onMouse);
  }, []);

  // Outside-click dismiss only. Scroll passes through naturally because there's
  // no full-screen overlay; the menu is position:fixed so it stays anchored while
  // the page scrolls under it.
  useEffect(() => {
    if (!isOpen) return;
    const onDown = (e: MouseEvent) => {
      const m = menuRef.current;
      const p = pillRef.current;
      const t = e.target as Node;
      if ((m && m.contains(t)) || (p && p.contains(t))) return;
      close();
    };
    document.addEventListener('mousedown', onDown, true);
    return () => {
      document.removeEventListener('mousedown', onDown, true);
    };
  }, [isOpen, close]);

  // The actual menu rows — shared between the visible menu and the hidden measurer
  // so menu_h is always exactly what gets rendered.
  const menuBody = (
    <div style={{ padding: '5px', display: 'flex', flexDirection: 'column' }}>
      {menuHeader && (
        <div style={{ padding: '10px 14px 12px', borderBottom: '1px solid rgba(0,0,0,0.08)', marginBottom: 4 }}>
          {menuHeader}
        </div>
      )}
      {menuItems.map((item, i) => {
        if (item.sep) {
          return <div key={i} style={{ height: 1, margin: '4px 12px', background: 'rgba(0,0,0,0.08)' }} />;
        }
        return (
          <div
            key={i}
            onClick={() => { item.onClick?.(); close(); }}
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              padding: '8px 14px',
              cursor: 'pointer',
              color: 'rgba(20, 22, 30, 0.95)',
              fontSize: 13.5,
              fontWeight: 500,
              borderRadius: 999,
              margin: '1px 0',
              textShadow: '0 1px 2px rgba(255,255,255,0.55)',
            }}
            onMouseEnter={e => (e.currentTarget.style.background = 'rgba(255,255,255,0.45)')}
            onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              {item.icon && <span style={{ display: 'flex', opacity: 0.9 }}>{item.icon}</span>}
              <span>{item.label}</span>
            </div>
            {item.shortcut && (
              <span style={{ fontSize: 11, color: 'rgba(20,22,30,0.45)', marginLeft: 20 }}>
                {item.shortcut}
              </span>
            )}
          </div>
        );
      })}
    </div>
  );

  // Portal: glass canvas + visible menu + hidden measurer. Body-level so no
  // ancestor with backdrop-filter / transform / filter can break their
  // fixed-position math.
  const portalContent = (
    <>
      {/* Glass canvas — always rendered, repositioned by renderGlass */}
      <div ref={wrapRef} style={{ position: 'fixed', display: 'none', pointerEvents: 'none', zIndex: 9000 }}>
        <canvas
          ref={canvasRef}
          data-liquid-glass
          style={{
            position: 'absolute',
            top: 0, left: 0,
            width: '100%', height: '100%',
            pointerEvents: 'none',
            transform: 'translateZ(0)',
          }}
          aria-hidden="true"
        />
      </div>

      {/* Hidden measurer — same content as visible menu, used to size the morph */}
      <div
        ref={measureRef}
        data-liquid-glass
        aria-hidden="true"
        style={{
          position: 'fixed',
          top: -10000,
          left: -10000,
          width: MENU_W,
          visibility: 'hidden',
          pointerEvents: 'none',
        }}
      >
        {menuBody}
      </div>

      {/* Visible menu — only rendered while open. No full-screen overlay so scroll passes through. */}
      {isOpen && (
        <div
          ref={menuRef}
          data-liquid-glass
          style={{
            position: 'fixed',
            opacity: 0,
            overflow: 'hidden',
            pointerEvents: 'none',
            borderRadius: MENU_R,
            zIndex: 9001,
          }}
        >
          {menuBody}
        </div>
      )}
    </>
  );

  return (
    <>
      {typeof document !== 'undefined' && createPortal(portalContent, document.body)}

      {/* Pill trigger — stays in-tree where component is placed */}
      <button
        ref={pillRef}
        data-liquid-glass
        onClick={open}
        style={{
          width: PILL_W,
          height: PILL_H,
          borderRadius: PILL_H / 2,
          border: 'none',
          background: 'transparent',
          color: '#fff',
          fontSize: 14,
          fontWeight: 500,
          cursor: 'pointer',
          outline: 'none',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 5,
          opacity: pillHidden ? 0 : 1,
          pointerEvents: pillHidden ? 'none' : 'auto',
          position: 'relative',
          zIndex: 9002,
          transition: 'opacity 0.1s ease',
        }}
      >
        {label}
        <svg width="8" height="5" viewBox="0 0 8 5" fill="none" style={{ flexShrink: 0 }}>
          <path d="M1 1l3 3 3-3" stroke="#fff" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      </button>
    </>
  );
};

export default GlassMenuButton;
