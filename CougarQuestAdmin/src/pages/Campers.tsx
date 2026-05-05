import { useMemo } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { motion } from 'motion/react'
import type { UserProfile } from '@/lib/types'
import { useUsers, displayNameFor } from '@/lib/queries'
import { formatPhoneNumber } from '@/lib/formatters'
import { BentoTile } from '@/components/ui/BentoTile'

export default function CampersPage() {
  const navigate = useNavigate()
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
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 280, damping: 26 }}
      className="space-y-5"
    >
      <BentoTile delay={0.05} hover={false} className="overflow-hidden p-0">
        <div className="flex items-baseline justify-between px-8 pt-7 pb-5">
          <div className="text-[11px] font-semibold uppercase tracking-[0.18em] text-muted-foreground">
            All campers
          </div>
          <div className="text-xs text-muted-foreground/70 tabular">
            {filtered.length} {filtered.length === 1 ? 'team' : 'teams'}
          </div>
        </div>

        {isLoading ? (
          <div className="px-8 py-20 text-center text-sm text-muted-foreground">Loading…</div>
        ) : filtered.length === 0 ? (
          <div className="px-8 py-20 text-center text-sm text-muted-foreground">
            {search ? 'No campers match that search.' : 'No campers yet.'}
          </div>
        ) : (
          <div>
            {filtered.map((u) => (
              <CamperRow key={u.uid} user={u} onClick={() => navigate(`/campers/${u.uid}`)} />
            ))}
          </div>
        )}
      </BentoTile>
    </motion.div>
  )
}

function CamperRow({ user, onClick }: { user: UserProfile; onClick: () => void }) {
  const contact = user.phoneNumber ? formatPhoneNumber(user.phoneNumber) : (user.email ?? '')
  const sonsLine = (user.sons?.length ?? 0) > 0 ? user.sons!.filter(Boolean).join(' · ') : null

  return (
    <button
      type="button"
      onClick={onClick}
      className="w-full text-left grid grid-cols-[minmax(0,1fr)_auto_auto] md:grid-cols-[minmax(0,1fr)_minmax(0,260px)_auto_auto] items-center gap-6 px-8 py-5 transition group hover:bg-cougar/[0.04] focus:outline-none focus-visible:bg-cougar/[0.06]"
    >
      <div className="min-w-0">
        <div className="flex items-center gap-2 min-w-0">
          <span className="text-[15px] font-semibold tracking-tight truncate group-hover:text-cougar transition-colors">
            {displayNameFor(user)}
          </span>
          {user.isAdmin && (
            <span className="shrink-0 text-[9px] font-bold uppercase tracking-[0.14em] text-cougar bg-cougar/10 rounded-full px-1.5 py-0.5">
              Admin
            </span>
          )}
        </div>
        {sonsLine && (
          <div className="text-[12.5px] text-muted-foreground truncate mt-0.5">
            {sonsLine}
          </div>
        )}
      </div>

      <div className="hidden md:block text-sm text-muted-foreground tabular truncate">
        {contact || '—'}
      </div>

      <div className="flex items-baseline gap-1.5 tabular">
        <span className="text-[10px] uppercase tracking-[0.14em] text-muted-foreground/70">Done</span>
        <span className="text-sm font-semibold">{user.completedQuests?.length ?? 0}</span>
      </div>

      <div className="flex items-baseline gap-1.5 tabular min-w-[80px] justify-end">
        <span className="text-2xl font-black text-cougar leading-none">{user.points ?? 0}</span>
        <span className="text-[10px] uppercase tracking-[0.14em] text-muted-foreground/70">pts</span>
      </div>
    </button>
  )
}
