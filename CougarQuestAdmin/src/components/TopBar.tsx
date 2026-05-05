import { useEffect, useRef } from 'react'
import { Link, useLocation, useNavigate, useSearchParams } from 'react-router-dom'
import { Search, ArrowLeft } from 'lucide-react'
import {
  ArrowRightOnRectangleIcon,
  Cog6ToothIcon,
  ArrowTopRightOnSquareIcon,
} from '@heroicons/react/24/outline'
import { useAuth } from '@/lib/auth'
import { useSubviewState } from '@/lib/subview'
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

  const subview = useSubviewState()
  const placeholder = SEARCHABLE[location.pathname]
  // In subview mode the centered slot is the subview title, not the search.
  const showSearch = Boolean(placeholder) && !subview
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
      <div className="min-w-0 flex items-center">
        {subview ? (
          <Link
            to={subview.backTo}
            className="inline-flex items-center gap-2 h-10 pl-3 pr-4 rounded-full bg-secondary/80 hover:bg-secondary text-sm font-semibold text-foreground transition"
          >
            <ArrowLeft className="h-4 w-4" />
            <span>{subview.backLabel ?? 'Back'}</span>
          </Link>
        ) : (
          <h1 className="text-2xl font-bold tracking-tight text-foreground truncate">
            {title}
          </h1>
        )}
      </div>

      <div className="flex justify-center min-w-0">
        {subview ? (
          <h1 className="text-lg font-bold tracking-tight text-foreground text-center truncate max-w-xl">
            {subview.title}
          </h1>
        ) : showSearch ? (
          <div className="glass-tile flex items-center w-full max-w-xl h-11 rounded-full bg-card/85 backdrop-blur px-4 transition focus-within:ring-2 focus-within:ring-ring focus-within:ring-offset-0">
            <Search className="h-4 w-4 text-muted-foreground shrink-0" />
            <input
              ref={inputRef}
              type="search"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder={placeholder}
              className="flex-1 mx-3 min-w-0 bg-transparent text-sm text-foreground placeholder:text-muted-foreground focus:outline-none border-none"
            />
            <kbd className="hidden sm:inline-flex items-center gap-1 text-[10px] font-semibold text-muted-foreground bg-secondary/80 rounded-md px-1.5 py-0.5 pointer-events-none shrink-0">
              ⌘K
            </kbd>
          </div>
        ) : null}
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

