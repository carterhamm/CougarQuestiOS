import { useEffect, useRef } from 'react'
import { useLocation, useNavigate, useSearchParams } from 'react-router-dom'
import { Search } from 'lucide-react'
import {
  ArrowRightOnRectangleIcon,
  Cog6ToothIcon,
  ArrowTopRightOnSquareIcon,
} from '@heroicons/react/24/outline'
import { useAuth } from '@/lib/auth'
import { GlassMenuButton } from '@/lib/glass/GlassMenuButton'

const SEARCHABLE: Record<string, string> = {
  '/quests': 'Search quests',
  '/campers': 'Search campers, sons, or emails',
}

export default function TopBar({ title }: { title: string }) {
  const { user, signOutNow } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [params, setParams] = useSearchParams()
  const inputRef = useRef<HTMLInputElement>(null)

  const placeholder = SEARCHABLE[location.pathname]
  const showSearch = Boolean(placeholder)
  const q = params.get('q') ?? ''

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (!showSearch) return
      const inField = (e.target as HTMLElement | null)?.closest('input, textarea')
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        inputRef.current?.focus()
        inputRef.current?.select()
        return
      }
      if (e.key === '/' && !inField) {
        e.preventDefault()
        inputRef.current?.focus()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [showSearch])

  function setQ(value: string) {
    const next = new URLSearchParams(params)
    if (value) next.set('q', value)
    else next.delete('q')
    setParams(next, { replace: true })
  }

  const fullName = user?.displayName || user?.email || ''
  const firstName = fullName.split(' ')[0] || fullName

  // Width tuned to fit "<name> ▾" cleanly. Min 110 (matches demo's compact pill),
  // grows by ~7px per character beyond 6 chars so longer names don't truncate.
  const pillWidth = Math.min(180, Math.max(110, 80 + firstName.length * 7))

  return (
    <header className="h-20 sticky top-0 grid grid-cols-[1fr_auto_1fr] items-center gap-6 px-8">
      <h1 className="text-2xl font-bold tracking-tight text-foreground truncate">
        {title}
      </h1>

      <div className="flex justify-center min-w-0">
        {showSearch && (
          <div className="relative w-full max-w-xl">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground pointer-events-none" />
            <input
              ref={inputRef}
              type="search"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder={placeholder}
              className="glass-tile w-full h-11 rounded-full border bg-background/60 pl-10 pr-16 text-sm placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring transition"
            />
            <kbd className="hidden sm:inline-flex items-center gap-1 absolute right-3 top-1/2 -translate-y-1/2 text-[10px] font-semibold text-muted-foreground/80 bg-secondary/70 rounded-md px-1.5 py-0.5 pointer-events-none">
              ⌘K
            </kbd>
          </div>
        )}
      </div>

      <div className="justify-self-end shrink-0">
        <GlassMenuButton
          pillWidth={pillWidth}
          pillHeight={40}
          menuWidth={280}
          menuRadius={12}
          pillBaseTint={0}
          label={firstName || 'Menu'}
          menuHeader={
            <div>
              <div style={{ fontSize: 13, fontWeight: 700, color: 'hsl(var(--foreground))', lineHeight: 1.2 }}>
                {fullName || 'Admin'}
              </div>
              <div style={{ fontSize: 11.5, color: 'hsl(var(--muted-foreground))', marginTop: 2 }}>
                {user?.email}
              </div>
            </div>
          }
          menuItems={[
            {
              label: 'Settings',
              icon: <Cog6ToothIcon style={{ width: 16, height: 16 }} />,
              onClick: () => navigate('/settings'),
            },
            {
              label: 'Open camper site',
              icon: <ArrowTopRightOnSquareIcon style={{ width: 16, height: 16 }} />,
              onClick: () => window.open('https://cougarquest-62ba2.web.app', '_blank'),
            },
            { sep: true },
            {
              label: 'Sign out',
              icon: <ArrowRightOnRectangleIcon style={{ width: 16, height: 16 }} />,
              onClick: () => signOutNow(),
            },
          ]}
        />
      </div>
    </header>
  )
}

