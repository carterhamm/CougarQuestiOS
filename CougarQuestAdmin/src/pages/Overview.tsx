import { useMemo } from 'react'
import { Map, Users, BadgeCheck, Sparkles, ArrowRight } from 'lucide-react'
import { Link } from 'react-router-dom'
import { motion } from 'motion/react'
import { BentoTile } from '@/components/ui/BentoTile'
import { useQuests, useUsers, displayNameFor } from '@/lib/queries'
import fathersAndSonsLogo from '@/assets/FathersAndSonsLogo.png'

export default function Overview() {
  const quests = useQuests()
  const users = useUsers()

  const stats = useMemo(() => {
    const totalQuests = quests.data?.length ?? 0
    const totalUsers = users.data?.length ?? 0
    const totalCompletions = (users.data ?? []).reduce(
      (acc, u) => acc + (u.completedQuests?.length ?? 0), 0,
    )
    const totalPoints = (users.data ?? []).reduce(
      (acc, u) => acc + (u.points ?? 0), 0,
    )
    const possible = totalQuests * Math.max(totalUsers, 1)
    const completionRate = possible > 0 ? Math.round((totalCompletions / possible) * 100) : 0
    return { totalQuests, totalUsers, totalCompletions, totalPoints, completionRate }
  }, [quests.data, users.data])

  const topThree = (users.data ?? []).slice(0, 3)

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 280, damping: 26 }}
      className="space-y-6"
    >
      <BentoTile delay={0} hover={false} className="relative overflow-hidden p-7 bg-gradient-to-br from-cougar-600 via-cougar to-cougar-700 text-white">
        <div className="relative z-10 flex items-center justify-between gap-6">
          <div>
            <div className="text-xs font-semibold uppercase tracking-[0.18em] text-white/75">
              BYU Fathers &amp; Sons
            </div>
            <div className="text-3xl font-extrabold tracking-tight mt-1.5">
              Camp at a glance
            </div>
            <div className="text-sm text-white/80 mt-1">
              {stats.totalUsers} campers · {stats.totalQuests} quests · {stats.completionRate}% completion
            </div>
          </div>
          <img
            src={fathersAndSonsLogo}
            alt="Fathers and Sons"
            className="h-24 w-24 object-contain drop-shadow-md hidden sm:block"
          />
        </div>
        <div className="pointer-events-none absolute -right-16 -bottom-16 h-56 w-56 rounded-full bg-white/10 blur-3xl" />
        <div className="pointer-events-none absolute -left-10 -top-10 h-40 w-40 rounded-full bg-white/10 blur-3xl" />
      </BentoTile>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatTile delay={0.04} label="Active quests" value={quests.isLoading ? '—' : stats.totalQuests} icon={<Map className="h-4 w-4" />} />
        <StatTile delay={0.08} label="Campers"       value={users.isLoading ? '—' : stats.totalUsers} icon={<Users className="h-4 w-4" />} />
        <StatTile delay={0.12} label="Completions"   value={users.isLoading ? '—' : stats.totalCompletions} hint={`${stats.completionRate}% rate`} icon={<BadgeCheck className="h-4 w-4" />} />
        <StatTile delay={0.16} label="Points awarded" value={users.isLoading ? '—' : stats.totalPoints.toLocaleString()} icon={<Sparkles className="h-4 w-4" />} accent />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <BentoTile delay={0.20} hover={false} className="lg:col-span-2 p-5">
          <div className="flex items-center justify-between mb-3">
            <div className="text-sm font-semibold tracking-tight">Top campers</div>
            <Link to="/leaderboard" className="text-xs font-semibold text-cougar inline-flex items-center gap-1 hover:underline">
              View all <ArrowRight className="h-3.5 w-3.5" />
            </Link>
          </div>
          <ul className="divide-y -mx-2">
            {topThree.length === 0 && !users.isLoading && (
              <li className="py-8 text-sm text-muted-foreground text-center">
                No campers signed up yet.
              </li>
            )}
            {topThree.map((u, i) => (
              <li key={u.uid} className="px-2 py-3 flex items-center gap-4">
                <span className="text-lg w-6 text-center">{['🥇', '🥈', '🥉'][i]}</span>
                <div className="flex-1 min-w-0">
                  <div className="text-sm font-semibold truncate">{displayNameFor(u)}</div>
                  <div className="text-xs text-muted-foreground">
                    {u.completedQuests?.length ?? 0} quests completed
                  </div>
                </div>
                <div className="text-base font-black tabular text-cougar">{u.points ?? 0}</div>
              </li>
            ))}
          </ul>
        </BentoTile>

        <BentoTile delay={0.24} hover={false} className="p-3">
          <div className="px-2 pt-2 pb-3 text-sm font-semibold tracking-tight">Quick actions</div>
          <div className="space-y-1">
            <ActionRow to="/quests/new" label="Add a new quest" />
            <ActionRow to="/broadcasts" label="Send a push to campers" />
            <ActionRow to="/campers" label="Manage camper roster" />
            <ActionRow to="/settings" label="Manage admin access" />
          </div>
        </BentoTile>
      </div>
    </motion.div>
  )
}

function StatTile({
  delay, label, value, hint, icon, accent,
}: {
  delay: number
  label: string
  value: number | string
  hint?: string
  icon: React.ReactNode
  accent?: boolean
}) {
  return (
    <BentoTile delay={delay} className="p-5">
      <div className="flex items-center justify-between text-muted-foreground">
        <div className="text-xs font-semibold uppercase tracking-wider">{label}</div>
        <div className="opacity-70">{icon}</div>
      </div>
      <div className={`mt-2 text-3xl font-black tabular ${accent ? 'text-cougar' : ''}`}>{value}</div>
      {hint && <div className="mt-1 text-xs text-muted-foreground">{hint}</div>}
    </BentoTile>
  )
}

function ActionRow({ to, label }: { to: string; label: string }) {
  return (
    <Link
      to={to}
      className="flex items-center justify-between rounded-2xl px-3 py-2.5 text-sm hover:bg-secondary transition group"
    >
      <span className="font-medium">{label}</span>
      <ArrowRight className="h-4 w-4 text-muted-foreground group-hover:text-cougar transition" />
    </Link>
  )
}
