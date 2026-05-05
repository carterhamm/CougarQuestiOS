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
        <div className="grid grid-cols-[minmax(0,1.6fr)_minmax(0,1.4fr)_72px_84px_88px] items-center gap-4 px-6 py-4 text-[11px] font-semibold uppercase tracking-[0.12em] text-muted-foreground border-b border-border/60">
          <div>Camper</div>
          <div>Contact</div>
          <div className="text-right">Done</div>
          <div className="text-right">Points</div>
          <div className="text-right">Admin</div>
        </div>

        {isLoading && (
          <div className="px-6 py-16 text-center text-sm text-muted-foreground">Loading…</div>
        )}

        {!isLoading && filtered.length === 0 && (
          <div className="px-6 py-16 text-center text-sm text-muted-foreground">
            {search ? 'No campers match that search.' : 'No campers yet.'}
          </div>
        )}

        <div>
          {filtered.map((u) => (
            <CamperRow key={u.uid} user={u} onClick={() => navigate(`/campers/${u.uid}`)} />
          ))}
        </div>
      </BentoTile>
    </motion.div>
  )
}

function CamperRow({ user, onClick }: { user: UserProfile; onClick: () => void }) {
  const contact = user.phoneNumber ? formatPhoneNumber(user.phoneNumber) : (user.email ?? '')
  const initial = displayNameFor(user)[0]?.toUpperCase() ?? '?'
  const sonsLine = (user.sons?.length ?? 0) > 0 ? user.sons!.filter(Boolean).join(' · ') : null

  return (
    <button
      type="button"
      onClick={onClick}
      className="w-full text-left grid grid-cols-[minmax(0,1.6fr)_minmax(0,1.4fr)_72px_84px_88px] items-center gap-4 px-6 py-3.5 border-b border-border/40 last:border-0 transition group hover:bg-cougar/[0.04]"
    >
      <div className="flex items-center gap-3 min-w-0">
        <div className="h-9 w-9 shrink-0 rounded-full bg-cougar/12 text-cougar text-xs font-bold flex items-center justify-center">
          {initial}
        </div>
        <div className="min-w-0">
          <div className="text-sm font-semibold tracking-tight truncate group-hover:text-cougar transition-colors">
            {displayNameFor(user)}
          </div>
          {sonsLine && (
            <div className="text-[11.5px] text-muted-foreground truncate">{sonsLine}</div>
          )}
        </div>
      </div>

      <div className="text-sm text-muted-foreground tabular truncate">
        {contact || '—'}
      </div>

      <div className="text-sm tabular text-right">{user.completedQuests?.length ?? 0}</div>

      <div className="text-base tabular font-bold text-right text-cougar">{user.points ?? 0}</div>

      <div className="flex justify-end">
        {user.isAdmin && (
          <span className="inline-flex items-center rounded-full bg-cougar/15 text-cougar text-[10px] font-bold uppercase tracking-[0.12em] px-2 py-0.5">
            Admin
          </span>
        )}
      </div>
    </button>
  )
}
