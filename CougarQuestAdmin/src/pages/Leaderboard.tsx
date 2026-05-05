import { Download } from 'lucide-react'
import { motion } from 'motion/react'
import { useNavigate } from 'react-router-dom'
import { useUsers, displayNameFor } from '@/lib/queries'
import { Card, CardHeader } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'

export default function LeaderboardPage() {
  const navigate = useNavigate()
  const { data: users = [], isLoading } = useUsers()

  function exportCsv() {
    const rows = [
      ['rank', 'name', 'team', 'points', 'completed'],
      ...users.map((u, i) => [
        String(i + 1),
        displayNameFor(u).replace(/"/g, '""'),
        (u.teamName || '').replace(/"/g, '""'),
        String(u.points ?? 0),
        String(u.completedQuests?.length ?? 0),
      ]),
    ]
    const csv = rows.map((r) => r.map((v) => `"${v}"`).join(',')).join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `cougarquest-leaderboard-${new Date().toISOString().slice(0, 10)}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  const podium = users.slice(0, 3)
  const rest = users.slice(3)

  // Display order: 2nd, 1st, 3rd. Heights: 1st tallest.
  const podiumLayout: { idx: number; height: string; gradient: string; label: string }[] = [
    { idx: 1, height: 'h-36', gradient: 'from-cougar-300 to-cougar-500', label: '2' },
    { idx: 0, height: 'h-48', gradient: 'from-cougar-400 to-cougar-700', label: '1' },
    { idx: 2, height: 'h-28', gradient: 'from-cougar-200 to-cougar-400', label: '3' },
  ]

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 280, damping: 26 }}
      className="space-y-8"
    >
      <div className="grid grid-cols-3 gap-4 items-end">
        {podiumLayout.map(({ idx, height, gradient, label }, i) => {
          const u = podium[idx]
          if (!u) return <div key={idx} />
          return (
            <motion.div
              key={u.uid}
              initial={{ opacity: 0, y: 24 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ type: 'spring', stiffness: 280, damping: 24, delay: i * 0.06 }}
              className="flex flex-col items-center gap-3"
            >
              <div className="text-center">
                <div className="text-sm font-semibold line-clamp-2">{displayNameFor(u)}</div>
                <div className="text-xs text-muted-foreground tabular">{u.points ?? 0} pts</div>
              </div>
              <div
                className={`glass-tile w-full ${height} rounded-3xl bg-gradient-to-b ${gradient} flex items-end justify-center pb-4 shadow-lg`}
              >
                <span className="text-white text-4xl font-black drop-shadow-md tabular">{label}</span>
              </div>
            </motion.div>
          )
        })}
      </div>

      <Card className="overflow-hidden">
        <CardHeader
          title="Full ranking"
          action={
            <Button size="sm" variant="secondary" onClick={exportCsv} disabled={users.length === 0}>
              <Download className="h-4 w-4" />
              Export CSV
            </Button>
          }
        />
        <table className="w-full text-sm">
          <thead className="text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            <tr className="border-b">
              <th className="px-5 py-3 w-16">Rank</th>
              <th className="px-5 py-3">Team / Camper</th>
              <th className="px-5 py-3 text-right">Completed</th>
              <th className="px-5 py-3 text-right">Points</th>
            </tr>
          </thead>
          <tbody>
            {isLoading && <tr><td colSpan={4} className="px-5 py-12 text-center text-muted-foreground">Loading…</td></tr>}
            {rest.map((u, i) => (
              <tr
                key={u.uid}
                onClick={() => navigate(`/campers/${u.uid}`)}
                className="border-b last:border-0 hover:bg-secondary/50 cursor-pointer"
              >
                <td className="px-5 py-3 tabular text-muted-foreground">{i + 4}</td>
                <td className="px-5 py-3 font-semibold">{displayNameFor(u)}</td>
                <td className="px-5 py-3 text-right tabular">{u.completedQuests?.length ?? 0}</td>
                <td className="px-5 py-3 text-right tabular font-bold text-cougar">{u.points ?? 0}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </motion.div>
  )
}
