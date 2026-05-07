import { useEffect } from 'react'
import { Outlet, useLocation } from 'react-router-dom'
import { AnimatePresence, motion } from 'motion/react'
import Sidebar from './Sidebar'
import TopBar from './TopBar'
import { captureViewport } from '@/lib/glass/useBackgroundCapture'
import { SubviewProvider } from '@/lib/subview'

const titleMap: Record<string, string> = {
  '/':            'Overview',
  '/quests':      'Quests',
  '/campers':     'Campers',
  '/leaderboard': 'Leaderboard',
  '/broadcasts':  'Broadcasts',
  '/settings':    'Settings',
}

function recaptureOnIdle() {
  const idle = (window as unknown as { requestIdleCallback?: (cb: () => void) => void }).requestIdleCallback
  if (idle) idle(() => captureViewport())
  else captureViewport()
}

function titleFor(pathname: string): string {
  const seg = '/' + (pathname.split('/')[1] || '')
  if (seg === '/quests' && pathname !== '/quests') return 'Quests'
  if (seg === '/campers' && pathname !== '/campers') return 'Campers'
  return titleMap[pathname.replace(/\/$/, '') || '/'] ?? titleMap[seg] ?? 'CougarQuest Admin'
}

export default function AppShell() {
  const loc = useLocation()
  const title = titleFor(loc.pathname)

  // Re-capture the page texture on route change so the Liquid Glass
  // shader has a fresh background to refract through. Multiple staggered
  // captures cover DOM mount, query hydration, and slow Firestore loads.
  useEffect(() => {
    const t1 = window.setTimeout(recaptureOnIdle,  60)
    const t2 = window.setTimeout(recaptureOnIdle, 600)
    const t3 = window.setTimeout(recaptureOnIdle, 1800)
    const t4 = window.setTimeout(recaptureOnIdle, 4000)
    return () => {
      window.clearTimeout(t1); window.clearTimeout(t2)
      window.clearTimeout(t3); window.clearTimeout(t4)
    }
  }, [loc.pathname])

  // Wagevo layout: floating sidebar (16px margin) + main with marginLeft 300.
  // TopBar lives inside <main> as a sticky first child so page content
  // scrolls *under* it. With TopBar as a flex sibling above main, the
  // 80px header slot would always show whatever's behind the TopBar
  // element (the AppShell's bg-primary, which is solid black in dark mode)
  // — content could never reach behind the bar, so any opacity/mask fade
  // on the TopBar would just reveal solid black instead of page content.
  return (
    <SubviewProvider>
      <div className="h-screen" style={{ backgroundColor: 'var(--bg-primary)', color: 'var(--text-primary)' }}>
        <Sidebar />
        <div style={{ marginLeft: 300 }} className="h-screen">
          <main className="h-full overflow-y-auto wg-scrollbar">
            <TopBar title={title} />
            <AnimatePresence mode="wait">
              <motion.div
                key={loc.pathname}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -8 }}
                transition={{ duration: 0.18, ease: [0.32, 0.72, 0, 1] }}
                className="max-w-7xl mx-auto px-8 py-8"
              >
                <Outlet />
              </motion.div>
            </AnimatePresence>
          </main>
        </div>
      </div>
    </SubviewProvider>
  )
}
