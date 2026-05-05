import { useMemo } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { motion } from 'motion/react'
import { useUsers, displayNameFor } from '@/lib/queries'
import { formatPhoneNumber } from '@/lib/formatters'
import { Card } from '@/components/ui/Card'

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
      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              <tr className="border-b">
                <th className="px-5 py-3">Team / Camper</th>
                <th className="px-5 py-3">Contact</th>
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
              {filtered.map((u) => {
                const contact = u.phoneNumber
                  ? formatPhoneNumber(u.phoneNumber)
                  : (u.email ?? '')
                return (
                  <tr
                    key={u.uid}
                    onClick={() => navigate(`/campers/${u.uid}`)}
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
                    <td className="px-5 py-3 text-muted-foreground tabular truncate max-w-[260px]">
                      {contact || '—'}
                    </td>
                    <td className="px-5 py-3 text-right tabular">{u.completedQuests?.length ?? 0}</td>
                    <td className="px-5 py-3 text-right tabular font-semibold">{u.points ?? 0}</td>
                    <td className="px-5 py-3 text-right">
                      {u.isAdmin && (
                        <span className="inline-block rounded-full bg-cougar/10 text-cougar text-[10px] font-bold uppercase tracking-wider px-2 py-0.5">
                          Admin
                        </span>
                      )}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </Card>
    </motion.div>
  )
}
