import { cn } from '@/lib/utils'
import type { ReactNode } from 'react'

interface Props {
  label: string
  value: ReactNode
  hint?: ReactNode
  icon?: ReactNode
  tone?: 'default' | 'cougar'
  className?: string
}

export function StatCard({ label, value, hint, icon, tone = 'default', className }: Props) {
  return (
    <div className={cn(
      'rounded-2xl border bg-card p-5 shadow-sm',
      tone === 'cougar' && 'bg-cougar text-white border-transparent',
      className,
    )}>
      <div className="flex items-start justify-between gap-3">
        <div className={cn(
          'text-xs font-semibold uppercase tracking-wider',
          tone === 'cougar' ? 'text-white/80' : 'text-muted-foreground',
        )}>
          {label}
        </div>
        {icon && (
          <div className={cn(
            'h-8 w-8 rounded-lg flex items-center justify-center',
            tone === 'cougar' ? 'bg-white/15 text-white' : 'bg-accent text-cougar',
          )}>
            {icon}
          </div>
        )}
      </div>
      <div className="mt-3 text-4xl font-black tabular leading-none">
        {value}
      </div>
      {hint && (
        <div className={cn(
          'mt-2 text-sm',
          tone === 'cougar' ? 'text-white/80' : 'text-muted-foreground',
        )}>
          {hint}
        </div>
      )}
    </div>
  )
}
