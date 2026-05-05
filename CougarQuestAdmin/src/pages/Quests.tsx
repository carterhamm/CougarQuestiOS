import { useMemo } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { Plus, Image as ImageIcon } from 'lucide-react'
import { motion } from 'motion/react'
import type { Quest } from '@/lib/types'
import { useQuests, useUsers } from '@/lib/queries'
import { Button } from '@/components/ui/Button'

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
    return quests.filter(
      (x) =>
        x.title.toLowerCase().includes(q) ||
        x.address.toLowerCase().includes(q) ||
        x.description.toLowerCase().includes(q),
    )
  }, [quests, search])

  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 280, damping: 26 }}
      className="space-y-5"
    >
      <div className="flex items-center justify-end">
        <Button onClick={() => navigate('/quests/new')}>
          <Plus className="h-4 w-4" />
          New quest
        </Button>
      </div>

      {isLoading ? (
        <div className="text-center py-16 text-muted-foreground text-sm">Loading…</div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16 text-muted-foreground text-sm">
          {search ? 'No quests match.' : 'No quests yet — add the first one.'}
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {filtered.map((q, i) => (
            <QuestCard
              key={q.id}
              quest={q}
              completions={completionsByTitle.get(q.title) ?? 0}
              delay={Math.min(i, 8) * 0.04}
              onClick={() => navigate(`/quests/${q.id}`)}
            />
          ))}
        </div>
      )}
    </motion.div>
  )
}

function QuestCard({
  quest, completions, delay, onClick,
}: {
  quest: Quest
  completions: number
  delay: number
  onClick: () => void
}) {
  return (
    <motion.button
      type="button"
      onClick={onClick}
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 320, damping: 28, delay }}
      whileHover={{ y: -2 }}
      className="group glass-tile rounded-3xl border bg-card text-left overflow-hidden transition-shadow hover:shadow-lg flex flex-col"
    >
      <div
        className="relative aspect-[16/10] w-full overflow-hidden bg-secondary [transform:translateZ(0)] [will-change:transform] [-webkit-mask-image:-webkit-radial-gradient(white,black)]"
      >
        {quest.photoURL ? (
          <img
            src={quest.photoURL}
            alt={quest.title}
            loading="lazy"
            decoding="async"
            className="absolute inset-0 h-full w-full object-cover transition-transform duration-500 ease-out group-hover:scale-[1.04] [backface-visibility:hidden]"
            onError={(e) => { (e.currentTarget as HTMLImageElement).style.display = 'none' }}
          />
        ) : (
          <div className="absolute inset-0 flex items-center justify-center text-muted-foreground">
            <ImageIcon className="h-8 w-8" />
          </div>
        )}
        <div className="absolute top-3 right-3 rounded-full bg-black/55 backdrop-blur text-white text-xs font-semibold px-2.5 py-1 tabular">
          {completions}
        </div>
      </div>
      <div className="p-4 space-y-1 flex-1">
        <div className="font-semibold tracking-tight truncate">
          {quest.title || <span className="text-muted-foreground italic">untitled</span>}
        </div>
        <div className="text-xs text-muted-foreground line-clamp-1">
          {quest.address || quest.description || '—'}
        </div>
      </div>
    </motion.button>
  )
}
