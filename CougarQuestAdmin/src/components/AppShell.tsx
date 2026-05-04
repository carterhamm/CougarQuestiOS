import { useEffect } from 'react'
import { Outlet, useLocation } from 'react-router-dom'
import Sidebar from './Sidebar'
import TopBar from './TopBar'
import { captureViewport } from '@/lib/glass/useBackgroundCapture'

const titleMap: Record<string, string> = {
  '/':            'Overview',
  '/quests':      'Quests',
  '/campers':     'Campers',
  '/leaderboard': 'Leaderboard',
  '/broadcasts':  'Broadcasts',
  '/settings':    'Settings',
}

export default function AppShell() {
  const loc = useLocation()
  const title = titleMap[loc.pathname.replace(/\/$/, '') || '/'] ?? 'CougarQuest Admin'

  // Refresh the Liquid Glass texture when the route changes. Wait a beat for
  // the new page to mount + lay out, then capture on idle so the html2canvas
  // freeze doesn't compete with the transition.
  useEffect(() => {
    const t = window.setTimeout(() => {
      const idle = (window as unknown as { requestIdleCallback?: (cb: () => void) => void }).requestIdleCallback
      if (idle) idle(() => captureViewport())
      else captureViewport()
    }, 380)
    return () => window.clearTimeout(t)
  }, [loc.pathname])

  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar />
      <div className="flex-1 flex flex-col min-w-0">
        <TopBar title={title} />
        <main className="flex-1 overflow-y-auto">
          <div className="mx-auto max-w-7xl px-6 py-6">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  )
}
