import { useNavigate, useParams } from 'react-router-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { doc, updateDoc } from 'firebase/firestore'
import { motion } from 'motion/react'
import { db } from '@/lib/firebase'
import { useUsers, useQuests, displayNameFor } from '@/lib/queries'
import { Button } from '@/components/ui/Button'
import { formatPhoneNumber } from '@/lib/formatters'
import { useSubview } from '@/lib/subview'

export default function CamperDetail() {
  const { uid } = useParams<{ uid: string }>()
  const navigate = useNavigate()
  const qc = useQueryClient()
  const { data: users = [] } = useUsers()
  const { data: quests = [] } = useQuests()

  const user = users.find((u) => u.uid === uid)

  useSubview(user ? {
    title: displayNameFor(user),
    backTo: '/campers',
    backLabel: 'Roster',
  } : null)

  const toggleAdmin = useMutation({
    mutationFn: async () => {
      if (!user) return
      await updateDoc(doc(db, 'users', user.uid), { isAdmin: !user.isAdmin })
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['users'] }),
  })

  const adjustPoints = useMutation({
    mutationFn: async (delta: number) => {
      if (!user) return
      await updateDoc(doc(db, 'users', user.uid), { points: Math.max(0, (user.points ?? 0) + delta) })
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['users'] }),
  })

  if (!user) {
    return (
      <div className="text-center py-24">
        <div className="text-sm text-muted-foreground">Camper not found.</div>
        <Button className="mt-6" onClick={() => navigate('/campers')}>Back to roster</Button>
      </div>
    )
  }

  const completedTitles = new Set(user.completedQuests ?? [])
  const completedQuests = quests.filter((q) => completedTitles.has(q.title))
  const contact = user.phoneNumber ? formatPhoneNumber(user.phoneNumber) : (user.email ?? '')

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 280, damping: 28 }}
      className="space-y-12 pb-16 max-w-4xl mx-auto"
    >
      {/* Identity */}
      <header>
        <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-cougar">
          {user.isAdmin ? 'Admin · Camper' : 'Camper'}
        </div>
        <div
          className="font-black tracking-[-0.04em] leading-[0.9] mt-3"
          style={{ fontSize: 'clamp(40px, 7vw, 88px)' }}
        >
          {displayNameFor(user)}
        </div>
        <div className="flex flex-wrap items-baseline gap-x-5 gap-y-1 mt-4 text-sm text-muted-foreground tabular">
          {contact && <span>{contact}</span>}
          {(user.sons?.length ?? 0) > 0 && (
            <>
              <span className="text-foreground/25" aria-hidden>·</span>
              <span>{user.sons!.filter(Boolean).join(' · ')}</span>
            </>
          )}
        </div>
      </header>

      {/* Stats — inline editorial */}
      <section className="border-t border-foreground/10 pt-8 flex flex-wrap items-baseline gap-x-10 gap-y-5">
        <BigStat value={user.points ?? 0} label="Points" accent />
        <Sep />
        <BigStat value={user.completedQuests?.length ?? 0} label="Completed" />
        <Sep />
        <BigStat value={`${quests.length - (user.completedQuests?.length ?? 0)}`} label="Remaining" />
      </section>

      {/* Adjust points — minimal command-line buttons */}
      <section className="border-t border-foreground/10 pt-7">
        <div className="flex items-baseline justify-between mb-4">
          <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-foreground/60">
            Adjust points
          </div>
          <div className="text-xs text-muted-foreground tabular">manual override</div>
        </div>
        <div className="flex items-center gap-2">
          {[-10, -1, 1, 10].map((delta) => (
            <button
              key={delta}
              type="button"
              onClick={() => adjustPoints.mutate(delta)}
              className="glass-tile h-10 min-w-[68px] px-4 rounded-full bg-secondary/70 hover:bg-secondary text-sm font-bold tabular text-foreground transition"
            >
              {delta > 0 ? `+${delta}` : delta}
            </button>
          ))}
        </div>
      </section>

      {/* Admin access */}
      <section className="border-t border-foreground/10 pt-7 flex items-baseline justify-between gap-6">
        <div>
          <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-foreground/60">
            Admin access
          </div>
          <div className="text-sm text-muted-foreground mt-1">
            {user.isAdmin ? 'Has dashboard access.' : 'No dashboard access.'}
          </div>
        </div>
        <Button
          size="sm"
          variant={user.isAdmin ? 'destructive' : 'primary'}
          onClick={() => toggleAdmin.mutate()}
        >
          {user.isAdmin ? 'Revoke' : 'Grant'}
        </Button>
      </section>

      {/* Completed expeditions list */}
      <section className="border-t border-foreground/10 pt-7">
        <div className="flex items-baseline justify-between mb-4">
          <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-foreground/60">
            Completed expeditions
          </div>
          <div className="text-xs text-muted-foreground tabular">
            {completedQuests.length} / {quests.length}
          </div>
        </div>
        {completedQuests.length === 0 ? (
          <div className="text-sm text-muted-foreground py-6">No completions yet.</div>
        ) : (
          <div>
            {completedQuests.map((q, i) => (
              <div
                key={q.id}
                className="grid grid-cols-[44px_minmax(0,1fr)] items-baseline gap-4 py-3 border-t border-foreground/5 first:border-t-0"
              >
                <span className="text-base font-extralight tabular text-foreground/45 leading-none">
                  {String(i + 1).padStart(2, '0')}
                </span>
                <span className="text-sm font-medium truncate">{q.title}</span>
              </div>
            ))}
          </div>
        )}
      </section>

      <div className="border-t border-foreground/10 pt-6 text-[10px] tabular text-muted-foreground/70 text-center font-mono">
        UID · {user.uid}
      </div>
    </motion.div>
  )
}

function BigStat({ value, label, accent = false }: { value: number | string; label: string; accent?: boolean }) {
  return (
    <div className="inline-flex items-baseline gap-2.5 tabular">
      <span className={`text-5xl font-black leading-none ${accent ? 'text-cougar' : 'text-foreground'}`}>
        {typeof value === 'number' ? value.toLocaleString() : value}
      </span>
      <span className="text-[11px] font-bold uppercase tracking-[0.18em] text-muted-foreground">{label}</span>
    </div>
  )
}

function Sep() {
  return <span className="text-foreground/25 select-none" aria-hidden>·</span>
}
