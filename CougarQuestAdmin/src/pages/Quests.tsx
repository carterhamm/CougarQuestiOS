import { useEffect, useMemo, useRef, useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { motion } from 'motion/react'
import { Plus, Image as ImageIcon, ArrowUpRight } from 'lucide-react'
import type { Quest } from '@/lib/types'
import { useQuests, useUsers } from '@/lib/queries'

/* Cinematic horizontal reel of quest panels.
   Each quest is a tall photo column with the title overlaid; the entire
   archive scrolls horizontally with scroll-snap centering. The currently
   centered panel is fully bright and gets a cougar bar across the top
   (animated with motion's layoutId so it slides between panels). The
   rest dim and de-saturate. A live timeline at the bottom tracks
   scroll progress in real time and the centered panel index. */

const PANEL_W = 400
const PANEL_GAP = 20

export default function QuestsPage() {
  const navigate = useNavigate()
  const { data: quests = [], isLoading } = useQuests()
  const { data: users = [] } = useUsers()
  const [params] = useSearchParams()
  const search = params.get('q') ?? ''

  const completionsByTitle = useMemo(() => {
    const map = new Map<string, number>()
    for (const u of users) {
      for (const t of u.completedQuests ?? []) {
        map.set(t, (map.get(t) ?? 0) + 1)
      }
    }
    return map
  }, [users])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return quests
    return quests.filter((x) =>
      x.title.toLowerCase().includes(q) ||
      x.address.toLowerCase().includes(q) ||
      x.description.toLowerCase().includes(q),
    )
  }, [quests, search])

  const reelRef = useRef<HTMLDivElement>(null)
  const [activeId, setActiveId] = useState<string | null>(null)
  const [scrollProgress, setScrollProgress] = useState(0)

  // Detect which panel is currently centered → "active" treatment.
  useEffect(() => {
    const root = reelRef.current
    if (!root || filtered.length === 0) return
    const obs = new IntersectionObserver(
      (entries) => {
        let best: IntersectionObserverEntry | null = null
        for (const e of entries) {
          if (e.isIntersecting && (!best || e.intersectionRatio > best.intersectionRatio)) {
            best = e
          }
        }
        if (best) {
          const id = best.target.getAttribute('data-quest-id')
          if (id) setActiveId(id)
        }
      },
      { root, threshold: [0.55, 0.8, 1] },
    )
    root.querySelectorAll('[data-quest-id]').forEach((el) => obs.observe(el))
    return () => obs.disconnect()
  }, [filtered])

  // Smoothly track horizontal scroll for the bottom timeline bar.
  useEffect(() => {
    const root = reelRef.current
    if (!root) return
    const onScroll = () => {
      const max = root.scrollWidth - root.clientWidth
      setScrollProgress(max > 0 ? root.scrollLeft / max : 0)
    }
    root.addEventListener('scroll', onScroll, { passive: true })
    onScroll()
    return () => root.removeEventListener('scroll', onScroll)
  }, [filtered])

  // Arrow-key navigation through the reel — one panel per press.
  useEffect(() => {
    const root = reelRef.current
    if (!root) return
    const onKey = (e: KeyboardEvent) => {
      const tag = (document.activeElement as HTMLElement | null)?.tagName
      if (tag === 'INPUT' || tag === 'TEXTAREA') return
      if (e.key === 'ArrowRight') {
        root.scrollBy({ left: PANEL_W + PANEL_GAP, behavior: 'smooth' })
        e.preventDefault()
      } else if (e.key === 'ArrowLeft') {
        root.scrollBy({ left: -(PANEL_W + PANEL_GAP), behavior: 'smooth' })
        e.preventDefault()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  const activeIndex = activeId ? filtered.findIndex((q) => q.id === activeId) : -1
  const displayIndex = activeIndex >= 0 ? activeIndex : 0

  return (
    <div className="space-y-10 pb-12">
      <motion.header
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ type: 'spring', stiffness: 280, damping: 28 }}
        className="flex items-baseline justify-between"
      >
        <div>
          <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-foreground/60">
            Quest archive
          </div>
          <div className="text-sm text-muted-foreground tabular mt-1">
            {filtered.length} {filtered.length === 1 ? 'expedition' : 'expeditions'} across camp
          </div>
        </div>
        <Link
          to="/quests/new"
          className="group text-[11px] font-bold uppercase tracking-[0.18em] text-cougar inline-flex items-center gap-1.5"
        >
          <Plus className="h-3.5 w-3.5 transition-transform group-hover:rotate-90" />
          Provision new
        </Link>
      </motion.header>

      {isLoading ? (
        <div className="text-center py-24 text-sm text-muted-foreground">Scanning archive…</div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-24 text-sm text-muted-foreground">
          {search ? `No expeditions match "${search}".` : 'No quests yet — provision the first.'}
        </div>
      ) : (
        // Reel stays within AppShell's px-8 padding so panels can never
        // scroll into the sidebar's space.
        <div
          ref={reelRef}
          className="overflow-x-auto scrollbar-hide pb-8"
          style={{ scrollSnapType: 'x mandatory' }}
        >
          <div className="flex gap-5">
            {filtered.map((q, i) => (
                <QuestPanel
                  key={q.id}
                  quest={q}
                  index={i}
                  active={q.id === activeId}
                  completions={completionsByTitle.get(q.title) ?? 0}
                  onClick={() => navigate(`/quests/${q.id}`)}
                />
              ))}
            <NewPanel onClick={() => navigate('/quests/new')} />
          </div>
        </div>
      )}

      {filtered.length > 0 && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.35 }}
          className="flex items-center gap-5 border-t border-foreground/10 pt-6"
        >
          <div className="text-[11px] font-bold uppercase tracking-[0.22em] text-foreground/70 tabular shrink-0">
            {String(displayIndex + 1).padStart(2, '0')} / {String(filtered.length).padStart(2, '0')}
          </div>
          <div className="h-px flex-1 bg-foreground/10 relative overflow-hidden">
            <div
              className="absolute inset-y-0 left-0 bg-cougar transition-[width] duration-150 ease-out"
              style={{ width: `${scrollProgress * 100}%` }}
            />
          </div>
          <div className="hidden md:block text-[11px] font-bold uppercase tracking-[0.22em] text-muted-foreground shrink-0">
            Scroll · ← →
          </div>
        </motion.div>
      )}
    </div>
  )
}

interface PanelProps {
  quest: Quest
  index: number
  active: boolean
  completions: number
  onClick: () => void
}

function QuestPanel({ quest, index, active, completions, onClick }: PanelProps) {
  const number = String(index + 1).padStart(2, '0')
  const code = quest.plusCode || `Q·${number}`

  return (
    <motion.button
      type="button"
      data-quest-id={quest.id}
      onClick={onClick}
      initial={{ opacity: 0, y: 24 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        type: 'spring',
        stiffness: 260,
        damping: 28,
        delay: Math.min(index, 6) * 0.04,
      }}
      className="group relative shrink-0 rounded-3xl overflow-hidden bg-foreground/5 text-left"
      style={{ width: PANEL_W, height: 560, scrollSnapAlign: 'center' }}
    >
      {quest.photoURL ? (
        <img
          src={quest.photoURL}
          alt={quest.title}
          crossOrigin="anonymous"
          loading="lazy"
          decoding="async"
          className="absolute inset-0 w-full h-full object-cover transition-[filter] duration-700"
          style={{
            animation: `kenburns 28s ${(index * 1.7) % 14}s ease-in-out infinite alternate`,
            filter: active ? 'brightness(1)' : 'brightness(0.55) saturate(0.85)',
          }}
          onError={(e) => { (e.currentTarget as HTMLImageElement).style.display = 'none' }}
        />
      ) : (
        <div className="absolute inset-0 flex items-center justify-center text-foreground/30">
          <ImageIcon className="h-10 w-10" />
        </div>
      )}

      <div className="absolute inset-x-0 top-0 h-32 bg-gradient-to-b from-black/55 to-transparent" />
      <div className="absolute inset-x-0 bottom-0 h-2/3 bg-gradient-to-t from-black/85 via-black/45 to-transparent" />

      <div className="absolute top-5 left-6 right-6 flex items-start justify-between text-white">
        <span className="text-[44px] font-extralight tabular leading-none drop-shadow-md">
          {number}
        </span>
        <span className="font-mono text-[11px] uppercase tracking-[0.18em] text-white/75 mt-2">
          {code}
        </span>
      </div>

      <div className="absolute bottom-0 inset-x-0 p-6 text-white">
        <div className="text-[28px] font-black tracking-tight leading-[1.05] line-clamp-2 drop-shadow-md">
          {quest.title || 'Untitled expedition'}
        </div>
        {quest.address && (
          <div className="text-[12.5px] text-white/75 mt-2 line-clamp-1">
            {quest.address}
          </div>
        )}
        <div className="flex items-baseline justify-between gap-3 mt-5">
          <div className="flex items-baseline gap-1.5 tabular">
            <span className="text-2xl font-black drop-shadow">{completions}</span>
            <span className="text-[10px] font-bold uppercase tracking-[0.18em] text-white/65">
              completions
            </span>
          </div>
          <span className="inline-flex items-center gap-1 text-[10px] font-bold uppercase tracking-[0.18em] text-white/0 group-hover:text-white/85 transition-colors">
            Open <ArrowUpRight className="h-3 w-3" />
          </span>
        </div>
      </div>

      {active && (
        <motion.div
          layoutId="quest-active-bar"
          className="absolute top-0 inset-x-0 h-0.5 bg-cougar"
          transition={{ type: 'spring', stiffness: 380, damping: 32 }}
        />
      )}
    </motion.button>
  )
}

function NewPanel({ onClick }: { onClick: () => void }) {
  return (
    <motion.button
      type="button"
      onClick={onClick}
      initial={{ opacity: 0, y: 24 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 260, damping: 28, delay: 0.3 }}
      className="group relative shrink-0 rounded-3xl border border-dashed border-foreground/15 hover:border-cougar/55 transition-colors flex flex-col items-center justify-center gap-3 text-foreground/45 hover:text-cougar"
      style={{ width: PANEL_W, height: 560, scrollSnapAlign: 'center' }}
    >
      <Plus className="h-10 w-10 transition-transform duration-300 group-hover:rotate-90" />
      <div className="text-[11px] font-bold uppercase tracking-[0.22em]">
        Provision a new expedition
      </div>
    </motion.button>
  )
}
