import { useEffect, type ReactNode } from 'react'
import { XMarkIcon } from '@heroicons/react/24/outline'
import { cn } from '@/lib/utils'

interface Props {
  open: boolean
  onClose: () => void
  title: ReactNode
  children: ReactNode
  footer?: ReactNode
  width?: string
}

export function Drawer({ open, onClose, title, children, footer, width = 'w-[480px]' }: Props) {
  useEffect(() => {
    function onKey(e: KeyboardEvent) { if (e.key === 'Escape') onClose() }
    if (open) document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [open, onClose])

  return (
    <div
      data-liquid-glass
      style={{ zIndex: 9500 }}
      className={cn(
        'fixed inset-0 transition',
        open ? 'pointer-events-auto' : 'pointer-events-none',
      )}
      aria-hidden={!open}
    >
      <div
        onClick={onClose}
        className={cn(
          'absolute inset-0 bg-black/40 transition-opacity',
          open ? 'opacity-100' : 'opacity-0',
        )}
      />
      <div
        className={cn(
          'absolute right-0 top-0 h-full bg-card border-l shadow-2xl transition-transform duration-300 ease-out flex flex-col',
          width,
          'max-w-full',
          open ? 'translate-x-0' : 'translate-x-full',
        )}
      >
        <div className="flex items-center justify-between px-5 py-4 border-b">
          <div className="text-base font-bold tracking-tight">{title}</div>
          <button
            onClick={onClose}
            className="h-8 w-8 rounded-lg hover:bg-secondary flex items-center justify-center text-muted-foreground"
          >
            <XMarkIcon className="h-5 w-5" />
          </button>
        </div>
        <div className="flex-1 overflow-y-auto p-5">{children}</div>
        {footer && <div className="border-t px-5 py-3 bg-background/50">{footer}</div>}
      </div>
    </div>
  )
}
