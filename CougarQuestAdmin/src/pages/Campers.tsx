import { useMemo, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { doc, updateDoc } from 'firebase/firestore'
import { MagnifyingGlassIcon } from '@heroicons/react/24/outline'
import { db } from '@/lib/firebase'
import type { UserProfile } from '@/lib/types'
import { useUsers, useQuests, displayNameFor } from '@/lib/queries'
import { Input } from '@/components/ui/Input'
import { Drawer } from '@/components/ui/Drawer'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'

export default function CampersPage() {
  const { data: users = [], isLoading } = useUsers()
  const { data: quests = [] } = useQuests()
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<UserProfile | null>(null)

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return users
    return users.filter((u) =>
      [u.teamName, u.firstName, u.lastName, u.name, ...(u.sons || [])]
        .filter(Boolean)
        .some((v) => v!.toLowerCase().includes(q)),
    )
  }, [users, search])

  return (
    <div className="space-y-4">
      <div className="relative max-w-md">
        <MagnifyingGlassIcon className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
        <Input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by team, name, or son"
          className="pl-9"
        />
      </div>

      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              <tr className="border-b">
                <th className="px-5 py-3">Team / Camper</th>
                <th className="px-5 py-3">Phone</th>
                <th className="px-5 py-3 text-right">Completed</th>
                <th className="px-5 py-3 text-right">Points</th>
                <th className="px-5 py-3 text-right">Admin</th>
              </tr>
            </thead>
            <tbody>
              {isLoading && <tr><td colSpan={5} className="px-5 py-12 text-center text-muted-foreground">Loading…</td></tr>}
              {!isLoading && filtered.length === 0 && (
                <tr><td colSpan={5} className="px-5 py-12 text-center text-muted-foreground">No campers match.</td></tr>
              )}
              {filtered.map((u) => (
                <tr
                  key={u.uid}
                  onClick={() => setSelected(u)}
                  className="border-b last:border-0 hover:bg-secondary/50 cursor-pointer"
                >
                  <td className="px-5 py-3">
                    <div className="font-semibold">{displayNameFor(u)}</div>
                    {(u.sons?.length ?? 0) > 0 && (
                      <div className="text-xs text-muted-foreground line-clamp-1">
                        {u.sons!.filter(Boolean).join(' · ')}
                      </div>
                    )}
                  </td>
                  <td className="px-5 py-3 text-muted-foreground">{u.phoneNumber || '—'}</td>
                  <td className="px-5 py-3 text-right tabular">{u.completedQuests?.length ?? 0}</td>
                  <td className="px-5 py-3 text-right tabular font-semibold">{u.points ?? 0}</td>
                  <td className="px-5 py-3 text-right">
                    {u.isAdmin && <span className="inline-block rounded-full bg-cougar/10 text-cougar text-[10px] font-bold uppercase tracking-wider px-2 py-0.5">Admin</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <CamperDetail user={selected} quests={quests} onClose={() => setSelected(null)} />
    </div>
  )
}

function CamperDetail({
  user,
  quests,
  onClose,
}: {
  user: UserProfile | null
  quests: { id: string; title: string }[]
  onClose: () => void
}) {
  const qc = useQueryClient()
  const open = user !== null

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

  const completedTitles = new Set(user?.completedQuests ?? [])
  const completedQuests = quests.filter((q) => completedTitles.has(q.title))

  return (
    <Drawer open={open} onClose={onClose} title={user ? displayNameFor(user) : ''}>
      {user && (
        <div className="space-y-6">
          <div className="grid grid-cols-2 gap-3">
            <Stat label="Points" value={user.points ?? 0} />
            <Stat label="Completed" value={user.completedQuests?.length ?? 0} />
          </div>

          <div className="rounded-2xl border p-4 space-y-3">
            <div className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">Adjust points</div>
            <div className="flex gap-2">
              <Button size="sm" variant="secondary" onClick={() => adjustPoints.mutate(-10)}>-10</Button>
              <Button size="sm" variant="secondary" onClick={() => adjustPoints.mutate(-1)}>-1</Button>
              <Button size="sm" variant="secondary" onClick={() => adjustPoints.mutate(1)}>+1</Button>
              <Button size="sm" variant="secondary" onClick={() => adjustPoints.mutate(10)}>+10</Button>
            </div>
          </div>

          <div className="rounded-2xl border p-4 flex items-center justify-between">
            <div>
              <div className="text-sm font-semibold">Admin access</div>
              <div className="text-xs text-muted-foreground">
                {user.isAdmin ? 'Has dashboard access' : 'No dashboard access'}
              </div>
            </div>
            <Button
              size="sm"
              variant={user.isAdmin ? 'destructive' : 'primary'}
              onClick={() => toggleAdmin.mutate()}
            >
              {user.isAdmin ? 'Revoke' : 'Grant'}
            </Button>
          </div>

          <div>
            <div className="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-2">
              Completed quests ({completedQuests.length})
            </div>
            {completedQuests.length === 0 ? (
              <div className="text-sm text-muted-foreground">No completions yet.</div>
            ) : (
              <ul className="space-y-1">
                {completedQuests.map((q) => (
                  <li key={q.id} className="text-sm rounded-lg px-3 py-2 bg-secondary/60">
                    {q.title}
                  </li>
                ))}
              </ul>
            )}
          </div>

          <div className="text-[11px] text-muted-foreground border-t pt-3">
            UID: <span className="font-mono">{user.uid}</span>
          </div>
        </div>
      )}
    </Drawer>
  )
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-2xl border p-4">
      <div className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">{label}</div>
      <div className="mt-1 text-3xl font-black tabular text-cougar">{value}</div>
    </div>
  )
}
