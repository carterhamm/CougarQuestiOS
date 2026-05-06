import { useMemo } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { motion } from 'motion/react'
import type { UserProfile } from '@/lib/types'
import { useUsers, displayNameFor } from '@/lib/queries'
import { formatPhoneNumber } from '@/lib/formatters'

export default function CampersPage() {
  const { data: users = [], isLoading } = useUsers()
  const [params] = useSearchParams()
  const search = params.get('q') ?? ''

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return users
    return users.filter((u) =>
      [u.teamName, u.firstName, u.lastName, u.name, u.email, ...(u.sons || [])]
        .filter(Boolean)
        .some((v) => v!.toLowerCase().includes(q)),
    )
  }, [users, search])

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 280, damping: 28 }}
      className="space-y-8 pb-16"
    >
      <header className="flex items-baseline justify-between">
        <div>
          <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-foreground/60">
            Roster
          </div>
          <div className="text-sm text-muted-foreground tabular mt-1">
            {filtered.length} {filtered.length === 1 ? 'team' : 'teams'}
            {search && ` · filtered by "${search}"`}
          </div>
        </div>
      </header>

      {isLoading ? (
        <div className="text-center py-24 text-sm text-muted-foreground">Loading roster…</div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-24 text-sm text-muted-foreground">
          {search ? 'No campers match.' : 'No campers signed up yet.'}
        </div>
      ) : (
        <div>
          {filtered.map((u) => (
            <CamperRow key={u.uid} user={u} />
          ))}
        </div>
      )}
    </motion.div>
  )
}

function CamperRow({ user }: { user: UserProfile }) {
  const contact = user.phoneNumber ? formatPhoneNumber(user.phoneNumber) : (user.email ?? '')
  const sonsLine = (user.sons?.length ?? 0) > 0 ? user.sons!.filter(Boolean).join(' · ') : null

  return (
    <Link
      to={`/campers/${user.uid}`}
      className="group grid grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)_auto] items-baseline gap-x-8 gap-y-1 py-7 border-t border-foreground/8 first:border-t-0 transition-colors"
    >
      <div className="min-w-0">
        <div className="flex items-center gap-3 min-w-0">
          <span className="text-xl font-semibold tracking-tight truncate group-hover:text-cougar transition-colors">
            {displayNameFor(user)}
          </span>
          {user.isAdmin && (
            <span className="shrink-0 text-[10px] font-bold uppercase tracking-[0.16em] text-cougar">
              ADMIN
            </span>
          )}
        </div>
        {sonsLine && (
          <div className="text-[12.5px] text-muted-foreground truncate mt-1">
            {sonsLine}
          </div>
        )}
      </div>

      {/* Use the same proportional metrics for both phone numbers and emails
          so they read at the same visual weight. `tabular` would make the
          digits in phone numbers wider than email letters and they'd
          appear to be different sizes. */}
      <div className="hidden md:block text-sm text-muted-foreground truncate">
        {contact || '—'}
      </div>

      <div className="flex items-baseline gap-2 tabular shrink-0 justify-self-end">
        <span className="text-3xl font-black text-foreground leading-none">
          {(user.points ?? 0).toLocaleString()}
        </span>
        <span className="text-[10px] font-bold uppercase tracking-[0.18em] text-muted-foreground">
          PTS
        </span>
      </div>
    </Link>
  )
}
