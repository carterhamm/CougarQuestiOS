import { cn } from '@/lib/utils'
import { type InputHTMLAttributes, type TextareaHTMLAttributes, forwardRef } from 'react'

export const Input = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(
  function Input({ className, ...props }, ref) {
    return (
      <input
        ref={ref}
        className={cn(
          'glass-tile h-11 w-full rounded-2xl border bg-background px-4 text-sm transition placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring',
          className,
        )}
        {...props}
      />
    )
  },
)

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaHTMLAttributes<HTMLTextAreaElement>>(
  function Textarea({ className, ...props }, ref) {
    return (
      <textarea
        ref={ref}
        className={cn(
          'glass-tile w-full rounded-2xl border bg-background p-3 text-sm transition placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring',
          className,
        )}
        {...props}
      />
    )
  },
)

export function Label({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <label className={cn('text-xs font-semibold uppercase tracking-wider text-muted-foreground', className)}>
      {children}
    </label>
  )
}
