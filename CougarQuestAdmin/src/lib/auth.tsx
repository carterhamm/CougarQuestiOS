import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import {
  getRedirectResult,
  onAuthStateChanged,
  signInWithPopup,
  signInWithRedirect,
  signOut,
  type User,
} from 'firebase/auth'
import { doc, setDoc } from 'firebase/firestore'
import { auth, authPersistenceReady, db, googleProvider } from './firebase'

interface AuthState {
  user: User | null
  isAdmin: boolean
  loading: boolean
  signIn: () => Promise<void>
  signOutNow: () => Promise<void>
}

const AuthCtx = createContext<AuthState | null>(null)

const REDIRECT_PENDING_KEY = 'cq:auth:redirect-pending'

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  /* Single-source-of-truth init.

     The previous setup had three things racing to set user state:
     getRedirectResult, onAuthStateChanged, and a 12s safety timer. They
     could disagree mid-flight — e.g. safety timer fires loading=false
     while getRedirectResult was still resolving — leaving the app on
     SignIn even after Firebase finished authenticating.

     New flow:
       1. await persistence (so getRedirectResult reads the same store
          signInWithRedirect wrote to before navigating to Google).
       2. await getRedirectResult — drains any pending redirect into
          Firebase's internal currentUser.
       3. await auth.authStateReady() — Firebase guarantees this resolves
          once it has settled on a definitive user (or null). After this
          point auth.currentUser is the truth.
       4. setUser(auth.currentUser); setLoading(false).
       5. onAuthStateChanged keeps tracking ongoing changes. */
  useEffect(() => {
    let cancelled = false
    const init = async () => {
      try {
        await authPersistenceReady
        try {
          const result = await getRedirectResult(auth)
          console.log('[auth] getRedirectResult →', result?.user?.uid ?? 'null')
        } catch (err) {
          console.error('[auth] getRedirectResult threw:', err)
        }
        await auth.authStateReady()
        console.log('[auth] authStateReady, currentUser =', auth.currentUser?.uid ?? 'null')
      } finally {
        if (cancelled) return
        sessionStorage.removeItem(REDIRECT_PENDING_KEY)
        setUser(auth.currentUser)
        setLoading(false)
      }
    }
    init()

    const unsub = onAuthStateChanged(auth, (u) => {
      if (cancelled) return
      console.log('[auth] onAuthStateChanged →', u ? `${u.uid} <${u.email}>` : 'signed out')
      setUser(u)
      setLoading(false)
      if (u) {
        const updates: Record<string, unknown> = { isAdmin: true }
        if (u.email) updates.email = u.email
        if (u.displayName) updates.name = u.displayName
        setDoc(doc(db, 'users', u.uid), updates, { merge: true })
          .catch((err) => console.warn('[auth] user doc merge failed:', err))
      }
    })

    return () => { cancelled = true; unsub() }
  }, [])

  /* Popup flow with redirect fallback. signInWithRedirect's iframe-based
     auth-state handoff from authDomain back to the app origin gets blocked
     by Safari ITP and Chrome's third-party-cookie phase-out, leaving the
     post-Google-auth load with empty state and dropping us back on
     SignIn — the loop. signInWithPopup uses cross-window postMessage
     instead of iframe storage; browsers treat that differently and it
     often still works.

     If popup's promise doesn't settle in 8s — i.e. the popup completed
     Google auth but its postMessage to the opener is also being blocked
     (Brave, Firefox total-cookie-protection) — fall through to the full
     redirect as a last resort. */
  const signIn = async () => {
    console.log('[auth] signIn → awaiting persistence ready')
    await authPersistenceReady
    try {
      console.log('[auth] starting signInWithPopup…')
      const result = await Promise.race([
        signInWithPopup(auth, googleProvider),
        new Promise<null>((resolve) => setTimeout(() => resolve(null), 8000)),
      ])
      if (result) {
        console.log('[auth] popup completed:', result.user.uid)
        return
      }
      console.warn('[auth] popup did not resolve in 8s → falling back to redirect')
    } catch (err) {
      console.warn('[auth] popup failed → falling back to redirect:', err)
    }
    console.log('[auth] starting signInWithRedirect…')
    sessionStorage.setItem(REDIRECT_PENDING_KEY, '1')
    try {
      await signInWithRedirect(auth, googleProvider)
    } catch (err) {
      sessionStorage.removeItem(REDIRECT_PENDING_KEY)
      console.error('[auth] signInWithRedirect rejected:', err)
    }
  }

  const value: AuthState = {
    user,
    // Dev-mode gate: any signed-in Google user is admin. Lock this down with
    // proper Firestore rules + an allowlist before deploying publicly.
    isAdmin: !!user,
    loading,
    signIn,
    signOutNow: async () => { await signOut(auth) },
  }

  return <AuthCtx.Provider value={value}>{children}</AuthCtx.Provider>
}

export function useAuth() {
  const v = useContext(AuthCtx)
  if (!v) throw new Error('useAuth must be inside AuthProvider')
  return v
}
