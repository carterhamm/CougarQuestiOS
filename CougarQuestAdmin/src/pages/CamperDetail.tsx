import { useNavigate, useParams } from 'react-router-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { doc, updateDoc } from 'firebase/firestore'
import { motion } from 'motion/react'
import { db } from '@/lib/firebase'
import { useUsers, useQuests, displayNameFor } from '@/lib/queries'
import { Button } from '@/components/ui/Button'
import { BentoTile } from '@/components/ui/BentoTile'
import { formatPhoneNumber } from '@/lib/formatters'
import { useSubview } from '@/lib/subview'

export default function CamperDetail() {
  const { uid } = useParams<{ uid: string }>()
  const navigate = useNavigate()
  const qc = useQueryClient()
  const { data: users = [] } = useUsers()
  const { data: quests = [] } = useQuests()

  const user = users.find((u) => u.uid === uid)

  // TopBar takes over with a back-pill on the left and the camper's team
  // name centered. Keeps the subview chrome consistent with QuestEditor.
  useSubview(user ? {
    title: displayNameFor(user),
    backTo: '/campers',
    backLabel: 'Campers',
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
      <div className="text-center py-16">
        <p className="text-muted-foreground">Camper not found.</p>
        <Button className="mt-4" onClick={() => navigate('/campers')}>Back to campers</Button>
      </div>
    )
  }

  const completedTitles = new Set(user.completedQuests ?? [])
  const completedQuests = quests.filter((q) => completedTitles.has(q.title))

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 280, damping: 26 }}
      className="space-y-6 max-w-4xl mx-auto"
    >
      <BentoTile delay={0} hover={false} className="p-6">
        <div className="flex items-center gap-5">
          <div className="h-20 w-20 rounded-full bg-cougar text-white text-2xl font-bold flex items-center justify-center shrink-0">
            {(displayNameFor(user))[0]?.toUpperCase() ?? '?'}
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-xs font-semibold uppercase tracking-[0.14em] text-muted-foreground">
              {user.isAdmin ? 'Camp admin' : 'Camper'}
            </div>
            <div className="mt-1 flex flex-wrap items-baseline gap-x-4 gap-y-1 text-sm text-muted-foreground">
              {user.phoneNumber
                ? <span className="tabular">{formatPhoneNumber(user.phoneNumber)}</span>
                : user.email && <span>{user.email}</span>}
              {(user.sons?.length ?? 0) > 0 && <span>{user.sons!.filter(Boolean).join(' · ')}</span>}
            </div>
          </div>
        </div>
      </BentoTile>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <BentoTile delay={0.05} className="p-5">
          <div className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Points</div>
          <div className="mt-2 text-4xl font-black tabular text-cougar">{user.points ?? 0}</div>
          <div className="mt-3 flex gap-2 flex-wrap">
            <Button size="sm" variant="secondary" onClick={() => adjustPoints.mutate(-10)}>−10</Button>
            <Button size="sm" variant="secondary" onClick={() => adjustPoints.mutate(-1)}>−1</Button>
            <Button size="sm" variant="secondary" onClick={() => adjustPoints.mutate(1)}>+1</Button>
            <Button size="sm" variant="secondary" onClick={() => adjustPoints.mutate(10)}>+10</Button>
          </div>
        </BentoTile>

        <BentoTile delay={0.10} className="p-5">
          <div className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Completed</div>
          <div className="mt-2 text-4xl font-black tabular">{user.completedQuests?.length ?? 0}</div>
          <div className="mt-1 text-xs text-muted-foreground">of {quests.length} quests</div>
        </BentoTile>
      </div>

      <BentoTile delay={0.15} className="p-5">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-sm font-semibold">Admin access</div>
            <div className="text-xs text-muted-foreground">
              {user.isAdmin ? 'Can sign in to this dashboard' : 'No dashboard access'}
            </div>
          </div>
          <Button size="sm" variant={user.isAdmin ? 'destructive' : 'primary'} onClick={() => toggleAdmin.mutate()}>
            {user.isAdmin ? 'Revoke' : 'Grant'}
          </Button>
        </div>
      </BentoTile>

      <BentoTile delay={0.20} className="p-5">
        <div className="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-3">
          Completed quests ({completedQuests.length})
        </div>
        {completedQuests.length === 0 ? (
          <div className="text-sm text-muted-foreground">No completions yet.</div>
        ) : (
          <ul className="space-y-1">
            {completedQuests.map((q) => (
              <li key={q.id} className="text-sm rounded-2xl px-3 py-2 bg-secondary/60">{q.title}</li>
            ))}
          </ul>
        )}
      </BentoTile>

      <div className="text-[11px] text-muted-foreground text-center">
        UID: <span className="font-mono">{user.uid}</span>
      </div>
    </motion.div>
  )
}
