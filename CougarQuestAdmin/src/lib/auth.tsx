import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { onAuthStateChanged, signInWithPopup, signOut, type User } from 'firebase/auth'
import { doc, setDoc } from 'firebase/firestore'
import { auth, db, googleProvider } from './firebase'

interface AuthState {
  user: User | null
  isAdmin: boolean
  loading: boolean
  signIn: () => Promise<void>
  signOutNow: () => Promise<void>
}

const AuthCtx = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const safety = window.setTimeout(() => {
      console.warn('[auth] onAuthStateChanged did not fire within 6s — forcing loading=false')
      setLoading(false)
    }, 6000)

    const unsub = onAuthStateChanged(auth, (u) => {
      window.clearTimeout(safety)
      console.log('[auth] →', u ? `signed in as ${u.uid} <${u.email}>` : 'signed out')
      setUser(u)
      // Always release the spinner the moment auth resolves — the snapshot
      // subscription used to gate this and would silently time out at 5s,
      // leaving the SignIn screen showing even though the user was logged
      // in. Now we don't depend on Firestore to render the dashboard.
      setLoading(false)

      if (u) {
        // Persist email/displayName to the user doc so the Roster shows
        // proper contact info, and stamp isAdmin=true so the doc reflects
        // their access level in queries elsewhere.
        const updates: Record<string, unknown> = { isAdmin: true }
        if (u.email) updates.email = u.email
        if (u.displayName) updates.name = u.displayName
        setDoc(doc(db, 'users', u.uid), updates, { merge: true })
          .catch((err) => console.warn('[auth] user doc merge failed:', err))
      }
    })

    return () => { window.clearTimeout(safety); unsub() }
  }, [])

  const value: AuthState = {
    user,
    // Dev-mode gate: any signed-in Google user is admin. Lock this down with
    // proper Firestore rules + an allowlist before deploying publicly.
    isAdmin: !!user,
    loading,
    signIn: async () => { await signInWithPopup(auth, googleProvider) },
    signOutNow: async () => { await signOut(auth) },
  }

  return <AuthCtx.Provider value={value}>{children}</AuthCtx.Provider>
}

export function useAuth() {
  const v = useContext(AuthCtx)
  if (!v) throw new Error('useAuth must be inside AuthProvider')
  return v
}
