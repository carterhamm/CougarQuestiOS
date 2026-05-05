import { forwardRef, type HTMLAttributes, type ReactNode } from 'react'
import { cn } from '@/lib/utils'

interface GlassEffectProps extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode
  /** Corner radius — `pill` rounds to fully circular ends. */
  radius?: number | 'pill'
  /** `regular` (default Apple system look) | `clear` (more transparent) | `tinted` (hint of cougar blue). */
  variant?: 'regular' | 'clear' | 'tinted'
  /** When true, the inner content stays fully opaque; the glass effect is only an outline + rim. Use for filled tiles where you still want the glass treatment. */
  opaque?: boolean
}

/**
 * SwiftUI-style `.glassEffect()` modifier ported to web.
 *
 * Apple's modifier adds four things to any view, even one that's already
 * fully opaque:
 *   1. Backdrop blur (saturate + blur of what's behind the view)
 *   2. An inset top highlight (1px white line, simulates the top edge of glass)
 *   3. A subtle outer rim (1px boundary that catches light)
 *   4. A soft drop shadow (lifts the glass off the underlying surface)
 *
 * This component does the same in CSS. Wrap any element to give it the glass
 * border/rim treatment. Works equally on transparent and fully opaque content.
 *
 * Example:
 *   <GlassEffect radius={20}>
 *     <div className="p-4 bg-white">Fully opaque tile, still feels glassy</div>
 *   </GlassEffect>
 *
 * For the *liquid* glass with real refraction, see `<GlassMenuButton>` (Three.js
 * shader). This component is for ordinary tiles where a CSS-only effect is
 * enough.
 */
export const GlassEffect = forwardRef<HTMLDivElement, GlassEffectProps>(function GlassEffect(
  { children, className, style, radius = 16, variant = 'regular', opaque = false, ...props },
  ref,
) {
  const r = radius === 'pill' ? 9999 : radius

  // (1) Backdrop layer — the actual glass tint + blur of what's behind.
  // Skipped when `opaque` because the wrapped content already covers anything behind.
  const backdropBg =
    variant === 'clear'   ? 'rgba(255,255,255,0.45)' :
    variant === 'tinted'  ? 'rgba(0, 71, 186, 0.12)' :
    /* regular */           'rgba(255,255,255,0.62)'

  // (2)+(3)+(4): inset top highlight, outer rim, drop shadow — all stacked into
  // a single box-shadow. These are what give an opaque tile its glass character.
  const glassShadow = [
    'inset 0 1px 0 rgba(255,255,255,0.85)',          // top inset highlight (line of light)
    'inset 0 -0.5px 0 rgba(255,255,255,0.25)',       // subtle bottom highlight
    'inset 0 0 0 0.5px rgba(255,255,255,0.45)',      // inner rim
    '0 0 0 0.5px rgba(0, 30, 80, 0.08)',             // outer rim
    '0 1px 2px rgba(0,30,80,0.06)',                   // tight contact shadow
    '0 6px 22px -4px rgba(0,30,80,0.18)',             // soft floating shadow
  ].join(', ')

  return (
    <div
      ref={ref}
      className={cn('relative isolate', className)}
      style={{
        borderRadius: r,
        boxShadow: glassShadow,
        ...style,
      }}
      {...props}
    >
      {/* Backdrop layer — only renders behind transparent content; for opaque
          children it's harmless but invisible. */}
      {!opaque && (
        <div
          aria-hidden
          style={{
            position: 'absolute',
            inset: 0,
            borderRadius: 'inherit',
            background: backdropBg,
            backdropFilter: 'saturate(180%) blur(20px)',
            WebkitBackdropFilter: 'saturate(180%) blur(20px)',
            zIndex: -1,
          }}
        />
      )}
      {children}
    </div>
  )
})
