import { useMemo } from 'react'
import {
  MapIcon,
  UsersIcon,
  CheckBadgeIcon,
  SparklesIcon,
  ArrowRightIcon,
} from '@heroicons/react/24/outline'
import { Link } from 'react-router-dom'
import { StatCard } from '@/components/ui/StatCard'
import { Card, CardHeader } from '@/components/ui/Card'
import { useQuests, useUsers, displayNameFor } from '@/lib/queries'

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
    <div className="space-y-6">
      <div className="flex items-end justify-between">
        <div>
          <div className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            BYU Fathers and Sons
          </div>
          <div className="text-2xl font-bold tracking-tight mt-1">
            Camp at a glance
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          label="Active quests"
          value={quests.isLoading ? '—' : stats.totalQuests}
          icon={<MapIcon className="h-4 w-4" />}
        />
        <StatCard
          label="Campers"
          value={users.isLoading ? '—' : stats.totalUsers}
          icon={<UsersIcon className="h-4 w-4" />}
        />
        <StatCard
          label="Completions"
          value={users.isLoading ? '—' : stats.totalCompletions}
          hint={`${stats.completionRate}% completion rate`}
          icon={<CheckBadgeIcon className="h-4 w-4" />}
        />
        <StatCard
          label="Points awarded"
          value={users.isLoading ? '—' : stats.totalPoints.toLocaleString()}
          icon={<SparklesIcon className="h-4 w-4" />}
          tone="cougar"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <Card className="lg:col-span-2">
          <CardHeader
            title="Top campers"
            action={
              <Link to="/leaderboard" className="text-xs font-semibold text-cougar inline-flex items-center gap-1 hover:underline">
                View all <ArrowRightIcon className="h-3.5 w-3.5" />
              </Link>
            }
          />
          <ul className="divide-y">
            {topThree.length === 0 && !users.isLoading && (
              <li className="px-5 py-8 text-sm text-muted-foreground text-center">
                No campers signed up yet.
              </li>
            )}
            {topThree.map((u, i) => (
              <li key={u.uid} className="px-5 py-3 flex items-center gap-4">
                <span className="text-lg">
                  {['🥇', '🥈', '🥉'][i]}
                </span>
                <div className="flex-1 min-w-0">
                  <div className="text-sm font-semibold truncate">{displayNameFor(u)}</div>
                  <div className="text-xs text-muted-foreground">
                    {u.completedQuests?.length ?? 0} quests completed
                  </div>
                </div>
                <div className="text-base font-black tabular text-cougar">
                  {u.points ?? 0}
                </div>
              </li>
            ))}
          </ul>
        </Card>

        <Card>
          <CardHeader title="Quick actions" />
          <div className="p-3 space-y-1">
            <ActionRow to="/quests" label="Add a new quest" />
            <ActionRow to="/broadcasts" label="Send a push to campers" />
            <ActionRow to="/campers" label="Manage camper roster" />
            <ActionRow to="/settings" label="Manage admin access" />
          </div>
        </Card>
      </div>
    </div>
  )
}

function ActionRow({ to, label }: { to: string; label: string }) {
  return (
    <Link
      to={to}
      className="flex items-center justify-between rounded-xl px-3 py-2.5 text-sm hover:bg-secondary transition group"
    >
      <span className="font-medium">{label}</span>
      <ArrowRightIcon className="h-4 w-4 text-muted-foreground group-hover:text-cougar transition" />
    </Link>
  )
}
