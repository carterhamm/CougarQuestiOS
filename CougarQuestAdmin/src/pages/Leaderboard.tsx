import { Download } from 'lucide-react'
import { motion } from 'motion/react'
import { useNavigate } from 'react-router-dom'
import { useUsers, displayNameFor } from '@/lib/queries'
import { BentoTile } from '@/components/ui/BentoTile'
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

      <BentoTile delay={0.18} hover={false} className="overflow-hidden p-0">
        <div className="flex items-center justify-between gap-3 px-6 pt-5 pb-3">
          <div className="text-sm font-semibold tracking-tight">Full ranking</div>
          <Button size="sm" variant="secondary" onClick={exportCsv} disabled={users.length === 0}>
            <Download className="h-4 w-4" />
            Export CSV
          </Button>
        </div>

        <div className="grid grid-cols-[64px_minmax(0,1fr)_96px_96px] items-center gap-4 px-6 py-3 text-[11px] font-semibold uppercase tracking-[0.12em] text-muted-foreground border-b border-border/60">
          <div>Rank</div>
          <div>Team / Camper</div>
          <div className="text-right">Completed</div>
          <div className="text-right">Points</div>
        </div>

        {isLoading && (
          <div className="px-6 py-16 text-center text-sm text-muted-foreground">Loading…</div>
        )}

        {!isLoading && rest.length === 0 && (
          <div className="px-6 py-16 text-center text-sm text-muted-foreground">
            No campers ranked yet beyond the podium.
          </div>
        )}

        <div>
          {rest.map((u, i) => (
            <button
              key={u.uid}
              type="button"
              onClick={() => navigate(`/campers/${u.uid}`)}
              className="w-full text-left grid grid-cols-[64px_minmax(0,1fr)_96px_96px] items-center gap-4 px-6 py-3.5 border-b border-border/40 last:border-0 transition group hover:bg-cougar/[0.04]"
            >
              <div className="text-sm tabular text-muted-foreground">{i + 4}</div>
              <div className="text-sm font-semibold tracking-tight truncate group-hover:text-cougar transition-colors">
                {displayNameFor(u)}
              </div>
              <div className="text-sm tabular text-right">{u.completedQuests?.length ?? 0}</div>
              <div className="text-base tabular font-bold text-right text-cougar">{u.points ?? 0}</div>
            </button>
          ))}
        </div>
      </BentoTile>
    </motion.div>
  )
}
