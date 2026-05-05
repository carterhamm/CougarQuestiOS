import { Download } from 'lucide-react'
import { motion } from 'motion/react'
import { Link } from 'react-router-dom'
import { useUsers, displayNameFor } from '@/lib/queries'

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

  const champion = users[0]
  const runnersUp = users.slice(1, 3)
  const rest = users.slice(3)

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 280, damping: 28 }}
      className="space-y-12 pb-16"
    >
      <header className="flex items-baseline justify-between">
        <div>
          <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-foreground/60">
            Standings
          </div>
          <div className="text-sm text-muted-foreground tabular mt-1">
            {users.length} {users.length === 1 ? 'team' : 'teams'} · live
          </div>
        </div>
        <button
          onClick={exportCsv}
          disabled={users.length === 0}
          className="group text-[11px] font-bold uppercase tracking-[0.18em] text-cougar inline-flex items-center gap-1.5 disabled:opacity-40 disabled:pointer-events-none"
        >
          <Download className="h-3.5 w-3.5 transition-transform group-hover:translate-y-0.5" />
          Export CSV
        </button>
      </header>

      {isLoading ? (
        <div className="text-center py-24 text-sm text-muted-foreground">Loading standings…</div>
      ) : users.length === 0 ? (
        <div className="text-center py-24 text-sm text-muted-foreground">
          No campers signed up yet.
        </div>
      ) : (
        <>
          {/* Champion — full editorial hero */}
          {champion && (
            <Link to={`/campers/${champion.uid}`} className="group block">
              <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-cougar">
                Champion
              </div>
              <div className="grid grid-cols-[minmax(0,1fr)_auto] items-end gap-6 mt-3">
                <div
                  className="font-black tracking-[-0.04em] leading-[0.9] truncate group-hover:text-cougar transition-colors"
                  style={{ fontSize: 'clamp(48px, 9vw, 108px)' }}
                >
                  {displayNameFor(champion)}
                </div>
                <div className="flex items-baseline gap-2 tabular shrink-0">
                  <span
                    className="font-black text-cougar leading-none"
                    style={{ fontSize: 'clamp(48px, 7.5vw, 88px)' }}
                  >
                    {(champion.points ?? 0).toLocaleString()}
                  </span>
                  <span className="text-[11px] font-bold uppercase tracking-[0.18em] text-muted-foreground">
                    PTS
                  </span>
                </div>
              </div>
              <div className="text-sm text-muted-foreground tabular mt-3">
                {(champion.completedQuests?.length ?? 0)} quests completed
                {(champion.sons?.length ?? 0) > 0 && ` · ${champion.sons!.filter(Boolean).join(' · ')}`}
              </div>
            </Link>
          )}

          {/* Runners-up — same shape, scaled down */}
          {runnersUp.length > 0 && (
            <section className="border-t border-foreground/10 pt-7 space-y-7">
              <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-foreground/60">
                Runners-up
              </div>
              <div className="space-y-7">
                {runnersUp.map((u, i) => (
                  <Link
                    key={u.uid}
                    to={`/campers/${u.uid}`}
                    className="group grid grid-cols-[80px_minmax(0,1fr)_auto] items-baseline gap-6"
                  >
                    <span className="text-[60px] font-extralight tabular text-foreground/35 leading-none group-hover:text-cougar transition-colors">
                      {String(i + 2).padStart(2, '0')}
                    </span>
                    <div className="min-w-0">
                      <div className="text-3xl font-bold tracking-tight truncate group-hover:text-cougar transition-colors">
                        {displayNameFor(u)}
                      </div>
                      <div className="text-xs text-muted-foreground tabular mt-1">
                        {u.completedQuests?.length ?? 0} quests
                      </div>
                    </div>
                    <div className="flex items-baseline gap-2 tabular shrink-0">
                      <span className="text-4xl font-black text-foreground leading-none">
                        {(u.points ?? 0).toLocaleString()}
                      </span>
                      <span className="text-[10px] font-bold uppercase tracking-[0.18em] text-muted-foreground">
                        PTS
                      </span>
                    </div>
                  </Link>
                ))}
              </div>
            </section>
          )}

          {/* Full ranking from 04 onwards */}
          {rest.length > 0 && (
            <section className="border-t border-foreground/10 pt-7">
              <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-foreground/60">
                Ranking
              </div>
              <div className="mt-2">
                {rest.map((u, i) => (
                  <Link
                    key={u.uid}
                    to={`/campers/${u.uid}`}
                    className="group grid grid-cols-[64px_minmax(0,1fr)_auto] items-baseline gap-6 py-5 border-t border-foreground/5 first:border-t-0"
                  >
                    <span className="text-2xl font-extralight tabular text-foreground/40 leading-none">
                      {i + 4}
                    </span>
                    <span className="text-base font-semibold tracking-tight truncate group-hover:text-cougar transition-colors">
                      {displayNameFor(u)}
                    </span>
                    <div className="flex items-baseline gap-1.5 tabular shrink-0">
                      <span className="text-xl font-black text-foreground leading-none">
                        {(u.points ?? 0).toLocaleString()}
                      </span>
                      <span className="text-[10px] font-bold uppercase tracking-[0.18em] text-muted-foreground">
                        PTS
                      </span>
                    </div>
                  </Link>
                ))}
              </div>
            </section>
          )}
        </>
      )}
    </motion.div>
  )
}
