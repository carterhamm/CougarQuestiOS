import { NavLink } from 'react-router-dom'
import {
  HomeIcon,
  MapIcon,
  UsersIcon,
  TrophyIcon,
  MegaphoneIcon,
  Cog6ToothIcon,
} from '@heroicons/react/24/outline'
import { cn } from '@/lib/utils'

const items = [
  { to: '/',            label: 'Overview',    icon: HomeIcon },
  { to: '/quests',      label: 'Quests',      icon: MapIcon },
  { to: '/campers',     label: 'Campers',     icon: UsersIcon },
  { to: '/leaderboard', label: 'Leaderboard', icon: TrophyIcon },
  { to: '/broadcasts',  label: 'Broadcasts',  icon: MegaphoneIcon },
  { to: '/settings',    label: 'Settings',    icon: Cog6ToothIcon },
] as const

export default function Sidebar() {
  return (
    <aside className="hidden md:flex w-60 shrink-0 flex-col border-r bg-white/65 backdrop-blur-xl backdrop-saturate-150">
      <div className="h-16 flex items-center px-5 border-b">
        <span className="text-xl font-extrabold tracking-tight text-cougar">
          CougarQuest
        </span>
        <span className="ml-2 text-[10px] font-bold uppercase tracking-widest text-muted-foreground bg-secondary rounded px-1.5 py-0.5">
          Admin
        </span>
      </div>
      <nav className="flex-1 p-3 space-y-1">
        {items.map(({ to, label, icon: Icon }) => (
          <NavLink
            key={to}
            to={to}
            end={to === '/'}
            className={({ isActive }) =>
              cn(
                'group flex items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium transition',
                isActive
                  ? 'bg-cougar/10 text-cougar'
                  : 'text-muted-foreground hover:bg-secondary hover:text-foreground',
              )
            }
          >
            <Icon className="h-5 w-5" />
            {label}
          </NavLink>
        ))}
      </nav>
      <div className="p-4 text-[11px] text-muted-foreground border-t">
        BYU Sports Camps
      </div>
    </aside>
  )
}
