import { ArrowDownTrayIcon } from '@heroicons/react/24/outline'
import { useUsers, displayNameFor } from '@/lib/queries'
import { Card, CardHeader } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'

export default function LeaderboardPage() {
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

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-3 gap-4">
        {[1, 0, 2].map((idx) => {
          const u = podium[idx]
          if (!u) return <div key={idx} />
          const rank = idx + 1
          const heights = ['h-44', 'h-32', 'h-24']
          const colors = ['bg-amber-400', 'bg-slate-300', 'bg-orange-400']
          const medals = ['🥇', '🥈', '🥉']
          return (
            <div key={u.uid} className="flex flex-col items-center gap-3">
              <div className="text-3xl">{medals[idx]}</div>
              <div className="text-center">
                <div className="text-sm font-semibold line-clamp-2">{displayNameFor(u)}</div>
                <div className="text-xs text-muted-foreground">{u.points ?? 0} pts</div>
              </div>
              <div className={`w-full ${heights[idx]} ${colors[idx]} rounded-2xl flex items-end justify-center pb-3 shadow-sm`}>
                <span className="text-white text-2xl font-black">{rank}</span>
              </div>
            </div>
          )
        })}
      </div>

      <Card className="overflow-hidden">
        <CardHeader
          title="Full ranking"
          action={
            <Button size="sm" variant="secondary" onClick={exportCsv} disabled={users.length === 0}>
              <ArrowDownTrayIcon className="h-4 w-4" />
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
              <tr key={u.uid} className="border-b last:border-0">
                <td className="px-5 py-3 tabular text-muted-foreground">{i + 4}</td>
                <td className="px-5 py-3 font-semibold">{displayNameFor(u)}</td>
                <td className="px-5 py-3 text-right tabular">{u.completedQuests?.length ?? 0}</td>
                <td className="px-5 py-3 text-right tabular font-bold text-cougar">{u.points ?? 0}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  )
}
