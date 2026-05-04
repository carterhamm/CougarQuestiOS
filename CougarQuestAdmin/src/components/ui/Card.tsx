import { cn } from '@/lib/utils'
import type { HTMLAttributes, ReactNode } from 'react'

export function Card({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('rounded-2xl border bg-card shadow-sm', className)} {...props} />
}

export function CardHeader({ title, action }: { title: ReactNode; action?: ReactNode }) {
  return (
    <div className="px-5 py-4 border-b flex items-center justify-between">
      <div className="text-sm font-semibold tracking-tight">{title}</div>
      {action}
    </div>
  )
}
