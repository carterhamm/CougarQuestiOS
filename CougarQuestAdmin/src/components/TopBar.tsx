import { useNavigate } from 'react-router-dom'
import {
  ArrowRightOnRectangleIcon,
  Cog6ToothIcon,
  ArrowTopRightOnSquareIcon,
} from '@heroicons/react/24/outline'
import { useAuth } from '@/lib/auth'
import { GlassMenuButton } from '@/lib/glass/GlassMenuButton'

export default function TopBar({ title }: { title: string }) {
  const { user, signOutNow } = useAuth()
  const navigate = useNavigate()

  const fullName = user?.displayName || user?.email || ''
  const firstName = fullName.split(' ')[0] || fullName

  // Width tuned to fit "<name> ▾" cleanly. Min 110 (matches demo's compact pill),
  // grows by ~7px per character beyond 6 chars so longer names don't truncate.
  const pillWidth = Math.min(180, Math.max(110, 80 + firstName.length * 7))

  return (
    <header className="h-16 sticky top-0 flex items-center justify-between px-6 border-b border-white/30" style={{ background: 'linear-gradient(to bottom, rgba(255,255,255,0.45), rgba(255,255,255,0.05))' }}>
      <h1 className="text-xl font-bold tracking-tight text-foreground/90">{title}</h1>

      <GlassMenuButton
        pillWidth={pillWidth}
        pillHeight={40}
        menuWidth={280}
        menuRadius={12}
        pillBaseTint={0}
        label={firstName || 'Menu'}
        menuHeader={
          <div style={{ textShadow: '0 1px 2px rgba(255,255,255,0.55)' }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: 'rgba(20,22,30,0.95)', lineHeight: 1.2 }}>
              {fullName || 'Admin'}
            </div>
            <div style={{ fontSize: 11.5, color: 'rgba(20,22,30,0.55)', marginTop: 2 }}>
              {user?.email}
            </div>
          </div>
        }
        menuItems={[
          {
            label: 'Settings',
            icon: <Cog6ToothIcon style={{ width: 16, height: 16 }} />,
            onClick: () => navigate('/settings'),
          },
          {
            label: 'Open camper site',
            icon: <ArrowTopRightOnSquareIcon style={{ width: 16, height: 16 }} />,
            onClick: () => window.open('https://cougarquest-62ba2.web.app', '_blank'),
          },
          { sep: true },
          {
            label: 'Sign out',
            icon: <ArrowRightOnRectangleIcon style={{ width: 16, height: 16 }} />,
            onClick: () => signOutNow(),
          },
        ]}
      />
    </header>
  )
}
