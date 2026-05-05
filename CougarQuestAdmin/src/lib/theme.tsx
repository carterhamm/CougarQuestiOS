import { createContext, useContext, useEffect, useState, useCallback, useMemo, type ReactNode } from 'react'

type Theme = 'light' | 'dark'

interface ThemeContextType {
  theme: Theme
  toggleTheme: () => void
  setTheme: (theme: Theme) => void
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined)

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(() => {
    if (typeof window === 'undefined') return 'light'
    const saved = localStorage.getItem('theme') as Theme | null
    if (saved === 'light' || saved === 'dark') return saved
    return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
  })

  useEffect(() => {
    const root = document.documentElement
    root.classList.remove('light', 'dark')
    root.classList.add(theme)
    localStorage.setItem('theme', theme)
  }, [theme])

  // View Transitions API → smooth crossfade between modes when supported.
  const setTheme = useCallback((next: Theme) => {
    type DocVT = Document & { startViewTransition?: (cb: () => void) => unknown }
    const doc = document as DocVT
    if (typeof doc.startViewTransition === 'function') {
      doc.startViewTransition!(() => setThemeState(next))
    } else {
      setThemeState(next)
    }
  }, [])

  const toggleTheme = useCallback(() => setTheme(theme === 'light' ? 'dark' : 'light'), [theme, setTheme])

  // Global D-key shortcut (Wagevo-style). Ignored when typing in inputs.
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key !== 'd' && e.key !== 'D') return
      if (e.metaKey || e.ctrlKey || e.altKey) return
      const t = e.target as HTMLElement | null
      const tag = t?.tagName
      if (tag === 'INPUT' || tag === 'TEXTAREA' || (t && t.isContentEditable)) return
      e.preventDefault()
      toggleTheme()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [toggleTheme])

  const value = useMemo(() => ({ theme, toggleTheme, setTheme }), [theme, toggleTheme, setTheme])
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
}

export function useTheme() {
  const ctx = useContext(ThemeContext)
  if (!ctx) throw new Error('useTheme must be inside ThemeProvider')
  return ctx
}
