import { cn } from '@/lib/utils'
import { type ButtonHTMLAttributes, forwardRef } from 'react'

type Variant = 'primary' | 'secondary' | 'ghost' | 'destructive'
type Size = 'sm' | 'md' | 'lg' | 'icon'

interface Props extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  size?: Size
}

const variants: Record<Variant, string> = {
  primary: 'bg-cougar text-white hover:bg-cougar-600 disabled:bg-cougar-300',
  secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/80 border',
  ghost: 'hover:bg-secondary text-foreground',
  destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
}

const sizes: Record<Size, string> = {
  sm:   'h-9 px-4 text-sm rounded-full',
  md:   'h-11 px-5 text-sm rounded-full',
  lg:   'h-12 px-6 text-base rounded-full',
  icon: 'h-10 w-10 rounded-full',
}

export const Button = forwardRef<HTMLButtonElement, Props>(function Button(
  { className, variant = 'primary', size = 'md', ...props },
  ref,
) {
  return (
    <button
      ref={ref}
      className={cn(
        'glass-tile inline-flex items-center justify-center gap-2 font-semibold transition focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 focus:ring-offset-background disabled:opacity-60 disabled:pointer-events-none',
        variants[variant],
        sizes[size],
        className,
      )}
      {...props}
    />
  )
})
