import { NavLink, useLocation, useNavigate } from 'react-router-dom'
import { motion, AnimatePresence } from 'motion/react'
import {
  LayoutDashboard, Map, Users, Trophy, Megaphone,
  Settings as SettingsIcon, Sun, Moon, ArrowRightFromLine,
} from 'lucide-react'
import { useState } from 'react'
import { useTheme } from '@/lib/theme'
import { useAuth } from '@/lib/auth'
import logoLight from '@/assets/CougarQuestLogo-Light.png'
import logoDark from '@/assets/CougarQuestLogo-Dark.png'

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
  const { user, signOutNow } = useAuth()
  const location = useLocation()
  const navigate = useNavigate()
  const [settingsOpen, setSettingsOpen] = useState(false)

  const logoSrc = theme === 'dark' ? logoDark : logoLight

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
    // Active tab: cougar glow halo PLUS the glass-cougar rim (combined so the
    // class-level box-shadow isn't overridden).
    boxShadow: isActive
      ? theme === 'dark'
        ? 'inset 0 0 0 0.84px rgb(130 175 255 / 0.7), 0 4px 12px rgba(0, 71, 186, 0.30)'
        : 'inset 0 0 0 0.84px rgb(0 71 186 / 0.85), 0 4px 12px rgba(0, 71, 186, 0.22)'
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
        // Drop shadow + inset cougar rim. Inline style wins over the class
        // box-shadow, so combine them here.
        boxShadow: theme === 'dark'
          ? 'inset 0 0 0 0.84px rgb(130 175 255 / 0.55), 0 8px 32px rgba(0, 0, 0, 0.5)'
          : 'inset 0 0 0 0.84px rgb(0 71 186 / 0.65), 0 8px 32px rgba(0, 30, 80, 0.12)',
        zIndex: 40,
      }}
      className="glass-tile glass-cougar hidden md:flex flex-col overflow-hidden"
    >
      {/* Brand */}
      <button
        onClick={() => navigate('/')}
        className="flex items-center gap-3 px-6 pt-6 pb-3 hover:opacity-80 transition"
      >
        <img src={logoSrc} alt="CougarQuest" className="h-8 w-8 object-contain shrink-0" />
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
              className={`flex items-center gap-3 px-5 py-2.5 text-sm font-medium transition-all duration-200${isActive ? ' glass-tile glass-cougar' : ''}`}
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

      {/* Theme toggle + Settings */}
      <div className="p-4 space-y-2">
        <button
          onClick={toggleTheme}
          className="flex items-center gap-3 w-full px-5 py-2.5 text-sm font-medium transition-all duration-200 focus:outline-none"
          style={{ background: 'transparent', borderRadius: '20px', color: 'var(--text-secondary)' }}
          onMouseEnter={(e) => {
            e.currentTarget.style.backgroundColor = theme === 'dark'
              ? 'rgba(0, 71, 186, 0.14)'
              : 'rgba(0, 71, 186, 0.06)'
          }}
          onMouseLeave={(e) => { e.currentTarget.style.backgroundColor = 'transparent' }}
        >
          {theme === 'light' ? <Moon className="w-5 h-5" /> : <Sun className="w-5 h-5" />}
          <span>{theme === 'light' ? 'Dark Mode' : 'Light Mode'}</span>
          <kbd className="ml-auto text-[10px] uppercase tracking-widest font-bold rounded-md border px-1.5 py-0.5" style={{ borderColor: 'hsl(var(--border))', color: 'var(--text-muted)' }}>
            D
          </kbd>
        </button>

        <button
          onClick={() => setSettingsOpen((v) => !v)}
          className="flex items-center gap-3 w-full px-5 py-2.5 text-sm font-medium transition-all duration-200 focus:outline-none"
          style={{
            background: settingsOpen
              ? (theme === 'dark' ? 'rgba(0, 71, 186, 0.18)' : 'rgba(0, 71, 186, 0.08)')
              : 'transparent',
            borderRadius: '20px',
            color: 'var(--text-secondary)',
          }}
          onMouseEnter={(e) => {
            if (!settingsOpen) {
              e.currentTarget.style.backgroundColor = theme === 'dark'
                ? 'rgba(0, 71, 186, 0.14)'
                : 'rgba(0, 71, 186, 0.06)'
            }
          }}
          onMouseLeave={(e) => {
            if (!settingsOpen) e.currentTarget.style.backgroundColor = 'transparent'
          }}
        >
          <SettingsIcon className="w-5 h-5" />
          <span>Settings</span>
        </button>

        <AnimatePresence initial={false}>
          {settingsOpen && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              transition={{ type: 'spring', stiffness: 360, damping: 30 }}
              className="overflow-hidden"
            >
              <button
                onClick={() => signOutNow()}
                className="flex items-center gap-3 w-full px-5 py-2.5 text-sm font-medium transition-all duration-200 mt-1"
                style={{ background: 'transparent', borderRadius: '20px', color: 'hsl(var(--destructive))' }}
                onMouseEnter={(e) => { e.currentTarget.style.backgroundColor = 'hsl(var(--destructive) / 0.10)' }}
                onMouseLeave={(e) => { e.currentTarget.style.backgroundColor = 'transparent' }}
              >
                <ArrowRightFromLine className="w-5 h-5" />
                <span>Sign out</span>
              </button>
            </motion.div>
          )}
        </AnimatePresence>

        {/* User chip */}
        <div className="mt-3 flex items-center gap-2.5 px-3 py-2 rounded-2xl" style={{ background: theme === 'dark' ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)' }}>
          <div className="h-8 w-8 rounded-full bg-cougar text-white text-xs font-bold flex items-center justify-center shrink-0">
            {(user?.displayName || user?.email || '?').slice(0, 1).toUpperCase()}
          </div>
          <div className="min-w-0 flex-1">
            <div className="text-xs font-semibold truncate" style={{ color: 'var(--text-primary)' }}>{user?.displayName || 'Admin'}</div>
            <div className="text-[10px] truncate" style={{ color: 'var(--text-muted)' }}>{user?.email}</div>
          </div>
        </div>
      </div>
    </motion.aside>
  )
}
