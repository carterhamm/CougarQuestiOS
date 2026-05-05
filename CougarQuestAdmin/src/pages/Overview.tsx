import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { motion } from 'motion/react'
import { ArrowRight } from 'lucide-react'
import { useQuests, useUsers, displayNameFor } from '@/lib/queries'

/* ---------- Counter that animates from 0 → target with an ease-out cubic. */
function useCount(target: number, durationMs = 900) {
  const [v, setV] = useState(0)
  useEffect(() => {
    if (target === 0) { setV(0); return }
    const start = performance.now()
    let raf = 0
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / durationMs)
      const eased = 1 - Math.pow(1 - t, 3)
      setV(Math.round(target * eased))
      if (t < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [target, durationMs])
  return v
}

const fmtDate = new Intl.DateTimeFormat('en-US', { weekday: 'long', month: 'long', day: 'numeric' })

const SPRING = { type: 'spring' as const, stiffness: 280, damping: 28 }

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

  const heroPoints = useCount(stats.totalPoints, 1100)
  const topThree = (users.data ?? []).slice(0, 3)
  const today = useMemo(() => fmtDate.format(new Date()), [])
  const buildTag = useMemo(() => {
    const d = new Date()
    return `CQ·${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, '0')}`
  }, [])

  return (
    <div className="space-y-16 pb-24">
      {/* ---------- Eyebrow: system name · date · build · LIVE pulse */}
      <motion.header
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={SPRING}
        className="flex items-baseline justify-between"
      >
        <div className="space-y-1">
          <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-foreground/60">
            CougarQuest · Mission Control
          </div>
          <div className="text-sm text-muted-foreground tabular">
            {today}
            <span className="mx-2 text-foreground/20">·</span>
            <span className="font-mono text-[12.5px]">{buildTag}</span>
          </div>
        </div>
        <div className="inline-flex items-center gap-2.5 shrink-0">
          <span className="relative flex h-2 w-2 shrink-0">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-cougar/70" />
            <span className="relative inline-flex h-2 w-2 rounded-full bg-cougar" />
          </span>
          <span className="text-[11px] font-bold uppercase tracking-[0.22em] text-foreground/70">
            Live
          </span>
        </div>
      </motion.header>

      {/* ---------- Hero number — points awarded, animated, then a hairline
                    completion meter under it. */}
      <motion.section
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.55, delay: 0.05 }}
        className="space-y-6"
      >
        <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-muted-foreground">
          Points awarded
        </div>

        <div
          className="font-black tabular leading-[0.85] tracking-[-0.05em] text-foreground"
          style={{ fontSize: 'clamp(72px, 14vw, 168px)' }}
        >
          {heroPoints.toLocaleString()}
        </div>

        <div className="flex items-baseline gap-4 pt-1">
          <div className="relative h-px flex-1 bg-foreground/10 overflow-hidden">
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: `${stats.completionRate}%` }}
              transition={{ duration: 1.0, delay: 0.4, ease: [0.32, 0.72, 0, 1] }}
              className="absolute inset-y-0 left-0 bg-cougar"
            />
          </div>
          <div className="text-sm text-muted-foreground tabular shrink-0">
            <span className="font-bold text-foreground tabular">{stats.completionRate}%</span>
            <span className="ml-1.5">of camp complete</span>
          </div>
        </div>
      </motion.section>

      {/* ---------- Inline stat row, no cards, separated by mid-dots. */}
      <motion.div
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.25 }}
        className="border-t border-foreground/10 pt-7 flex flex-wrap items-baseline gap-x-7 gap-y-4"
      >
        <Stat value={stats.totalUsers} label="Campers" />
        <Sep />
        <Stat value={stats.totalQuests} label="Quests" />
        <Sep />
        <Stat value={stats.totalCompletions} label="Completions" />
      </motion.div>

      {/* ---------- Camp leaders — flat rows, magazine numerals. */}
      <motion.section
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.35 }}
      >
        <div className="flex items-baseline justify-between border-t border-foreground/10 pt-7 pb-2">
          <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-foreground/60">
            Camp leaders
          </div>
          <Link
            to="/leaderboard"
            className="group text-[11px] font-bold uppercase tracking-[0.18em] text-cougar inline-flex items-center gap-1.5"
          >
            All ranks
            <ArrowRight className="h-3.5 w-3.5 transition-transform group-hover:translate-x-0.5" />
          </Link>
        </div>

        {topThree.length === 0 ? (
          <div className="text-sm text-muted-foreground py-8">No campers ranked yet.</div>
        ) : (
          <div>
            {topThree.map((u, i) => (
              <Link
                key={u.uid}
                to={`/campers/${u.uid}`}
                className="group grid grid-cols-[64px_minmax(0,1fr)_auto] items-baseline gap-6 py-6 border-t border-foreground/5 first:border-t-0 transition-colors"
              >
                <span className="text-[34px] font-extralight tabular text-foreground/35 leading-none group-hover:text-cougar transition-colors">
                  {String(i + 1).padStart(2, '0')}
                </span>
                <span className="text-xl font-semibold tracking-tight truncate group-hover:text-cougar transition-colors">
                  {displayNameFor(u)}
                </span>
                <div className="flex items-baseline gap-2 tabular">
                  <span className="text-[28px] font-black text-foreground leading-none">
                    {(u.points ?? 0).toLocaleString()}
                  </span>
                  <span className="text-[10px] font-bold uppercase tracking-[0.18em] text-muted-foreground">
                    PTS
                  </span>
                </div>
              </Link>
            ))}
          </div>
        )}
      </motion.section>

      {/* ---------- Ops — text-only command-line style links. */}
      <motion.section
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4, delay: 0.45 }}
        className="border-t border-foreground/10 pt-7"
      >
        <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-foreground/60 pb-3">
          Ops
        </div>
        <div className="space-y-0">
          <Op to="/quests/new" label="Provision a new quest" />
          <Op to="/broadcasts" label="Broadcast to camp" />
          <Op to="/campers" label="Manage roster" />
          <Op to="/settings" label="System settings" />
        </div>
      </motion.section>
    </div>
  )
}

function Stat({ value, label }: { value: number; label: string }) {
  const v = useCount(value, 750)
  return (
    <div className="inline-flex items-baseline gap-2">
      <span className="text-2xl font-bold tabular text-foreground">
        {v.toLocaleString()}
      </span>
      <span className="text-[11px] font-bold uppercase tracking-[0.16em] text-muted-foreground">
        {label}
      </span>
    </div>
  )
}

function Sep() {
  return <span className="text-foreground/25 select-none" aria-hidden>·</span>
}

function Op({ to, label }: { to: string; label: string }) {
  return (
    <Link
      to={to}
      className="group flex items-baseline gap-3 py-2.5 text-foreground/85 hover:text-cougar transition-colors"
    >
      <span className="text-cougar transition-transform group-hover:translate-x-0.5">→</span>
      <span className="text-base font-medium">{label}</span>
    </Link>
  )
}
