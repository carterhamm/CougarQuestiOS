import { NavLink, useLocation, useNavigate } from 'react-router-dom'
import { motion } from 'motion/react'
import {
  LayoutDashboard, Map, Users, Trophy, Megaphone,
  Sun, Moon,
} from 'lucide-react'
import { useTheme } from '@/lib/theme'
import logoFs from '@/assets/FathersAndSonsLogo.png'

const navItems = [
  { to: '/',            label: 'Overview',    icon: LayoutDashboard },
  { to: '/quests',      label: 'Quests',      icon: Map },
  { to: '/campers',     label: 'Campers',     icon: Users },
  { to: '/leaderboard', label: 'Leaderboard', icon: Trophy },
  { to: '/broadcasts',  label: 'Broadcasts',  icon: Megaphone },
] as const

/**
 * Floating Wagevo-style sidebar, Cougar Blue branded.
 * - position: fixed with 16px margin all around, 36px corner radius
 * - Liquid Glass border via padding-box / border-box gradient trick
 * - active nav items get accent bg + ring/glow box-shadow
 * - settings panel at bottom expands to reveal sign-out
 */
export default function Sidebar() {
  const { theme, toggleTheme } = useTheme()
  const location = useLocation()
  const navigate = useNavigate()

  const logoSrc = logoFs

  // Wagevo's signature glass-border: padding-box layer = surface,
  // border-box layer = the gradient rim that shows through the transparent border.
  const sidebarBackground = theme === 'dark'
    ? `linear-gradient(to bottom right, rgba(15, 17, 22, 0.78), rgba(8, 10, 14, 0.86)) padding-box,
       linear-gradient(145deg, rgba(0, 71, 186, 0.55), rgba(255, 255, 255, 0.18), rgba(0, 71, 186, 0.30), rgba(255, 255, 255, 0.0)) border-box`
    : `linear-gradient(to bottom right, rgba(255, 255, 255, 0.85), rgba(245, 248, 255, 0.72)) padding-box,
       linear-gradient(145deg, rgba(0, 71, 186, 0.45), rgba(255, 255, 255, 0.7), rgba(0, 71, 186, 0.30), rgba(255, 255, 255, 0.0)) border-box`

  const navItemStyle = (isActive: boolean) => ({
    backgroundColor: isActive
      ? (theme === 'dark' ? 'rgba(0, 71, 186, 0.22)' : 'rgba(0, 71, 186, 0.10)')
      : 'transparent',
    // Active tab: cougar glow halo only — the rim itself is class-driven.
    boxShadow: isActive
      ? theme === 'dark'
        ? '0 4px 12px rgba(0, 71, 186, 0.30)'
        : '0 4px 12px rgba(0, 71, 186, 0.22)'
      : 'none',
    color: isActive
      ? (theme === 'dark' ? '#ffffff' : 'hsl(var(--primary))')
      : 'var(--text-secondary)',
    borderRadius: '20px',
  })

  return (
    <motion.aside
      data-liquid-glass
      initial={false}
      animate={{ borderRadius: 36 }}
      style={{
        position: 'fixed',
        left: 16,
        top: 16,
        bottom: 16,
        width: 268,
        background: sidebarBackground,
        backdropFilter: 'blur(20px) saturate(180%)',
        WebkitBackdropFilter: 'blur(20px) saturate(180%)',
        border: '1px solid transparent',
        boxShadow: theme === 'dark'
          ? '0 8px 32px rgba(0, 0, 0, 0.5)'
          : '0 8px 32px rgba(0, 30, 80, 0.12)',
        zIndex: 40,
      }}
      className="glass-tile glass-cougar hidden md:flex flex-col overflow-hidden"
    >
      {/* Brand */}
      <button
        onClick={() => navigate('/')}
        className="flex items-center gap-3 px-6 pt-6 pb-3 hover:opacity-80 transition"
      >
        <img src={logoSrc} alt="CougarQuest" className="h-11 w-11 object-contain shrink-0" />
        <div className="flex flex-col leading-tight text-left">
          <h1 className="text-lg font-semibold" style={{ color: 'var(--text-primary)' }}>CougarQuest</h1>
          <span className="text-[10px] font-bold uppercase tracking-[0.18em]" style={{ color: 'var(--text-muted)' }}>
            Admin
          </span>
        </div>
      </button>

      {/* Nav */}
      <nav className="flex-1 p-4 space-y-1 scrollbar-hide overflow-auto" style={{ scrollbarWidth: 'none' }}>
        {navItems.map(({ to, label, icon: Icon }) => {
          const isActive = to === '/' ? location.pathname === '/' : location.pathname.startsWith(to)
          return (
            <NavLink
              key={to}
              to={to}
              end={to === '/'}
              style={navItemStyle(isActive)}
              className={`flex items-center gap-3 px-5 py-2.5 text-sm font-medium transition-all duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-cougar focus-visible:ring-offset-2 focus-visible:ring-offset-transparent${isActive ? ' glass-tile glass-cougar' : ''}`}
              onMouseEnter={(e) => {
                if (!isActive) {
                  e.currentTarget.style.backgroundColor = theme === 'dark'
                    ? 'rgba(0, 71, 186, 0.14)'
                    : 'rgba(0, 71, 186, 0.06)'
                }
              }}
              onMouseLeave={(e) => {
                if (!isActive) e.currentTarget.style.backgroundColor = 'transparent'
              }}
            >
              <Icon className="w-5 h-5" />
              <span>{label}</span>
            </NavLink>
          )
        })}
      </nav>

      {/* One discreet control at the bottom — theme toggle. Identity, sign-out,
          and the settings page all live in the glass menu in the topbar; no
          reason to duplicate them here. */}
      <div className="p-5 flex items-center justify-between">
        <button
          onClick={toggleTheme}
          aria-label="Toggle theme"
          className="inline-flex items-center gap-2 h-9 px-3 rounded-full text-sm font-medium transition-colors"
          style={{ color: 'var(--text-secondary)' }}
          onMouseEnter={(e) => {
            e.currentTarget.style.backgroundColor = theme === 'dark'
              ? 'rgba(0, 71, 186, 0.14)'
              : 'rgba(0, 71, 186, 0.06)'
          }}
          onMouseLeave={(e) => { e.currentTarget.style.backgroundColor = 'transparent' }}
        >
          {theme === 'light' ? <Moon className="w-4 h-4" /> : <Sun className="w-4 h-4" />}
          <span className="text-[11px] font-bold uppercase tracking-[0.16em]">
            {theme === 'light' ? 'Dark' : 'Light'}
          </span>
        </button>
        <kbd
          className="text-[10px] uppercase tracking-widest font-bold rounded-md border px-1.5 py-0.5"
          style={{ borderColor: 'hsl(var(--border))', color: 'var(--text-muted)' }}
        >
          D
        </kbd>
      </div>
    </motion.aside>
  )
}
