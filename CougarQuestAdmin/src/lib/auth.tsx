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

  // Drain any pending redirect result on mount. After signInWithRedirect,
  // the page reloads here; this returns the just-signed-in user (and also
  // surfaces redirect-flow errors that would otherwise be silent).
  useEffect(() => {
    getRedirectResult(auth)
      .then((result) => {
        if (result) {
          console.log('[auth] redirect result:', result.user.uid, '<' + result.user.email + '>')
        }
      })
      .catch((err) => console.error('[auth] getRedirectResult ERROR:', err))
  }, [])

  useEffect(() => {
    const safety = window.setTimeout(() => {
      console.warn('[auth] onAuthStateChanged did not fire within 6s — forcing loading=false')
      setLoading(false)
    }, 6000)

    const unsub = onAuthStateChanged(auth, (u) => {
      window.clearTimeout(safety)
      console.log('[auth] onAuthStateChanged →', u ? `signed in as ${u.uid} <${u.email}>` : 'signed out')
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

    return () => { window.clearTimeout(safety); unsub() }
  }, [])

  /* signInWithPopup relies on third-party cookies / cross-window
     postMessage. Modern browsers block those by default (Safari, Firefox,
     Brave; Chrome incognito), which makes the popup *appear* to complete
     but the auth state never propagates back to the main window — exactly
     the symptom we've been seeing. signInWithRedirect navigates the whole
     tab through Google's auth and returns to our origin with the session
     attached; it doesn't need third-party cookies and is the recommended
     flow for embedded / localhost / private-browsing scenarios.

     We try the popup first because it's a nicer UX when it works, and
     fall back to redirect on any popup failure (blocked, closed, internal
     error, network). */
  const signIn = async () => {
    try {
      console.log('[auth] starting signInWithPopup…')
      const result = await signInWithPopup(auth, googleProvider)
      console.log('[auth] popup completed:', result.user.uid, '<' + result.user.email + '>')
      setUser(result.user)
      setLoading(false)
    } catch (err) {
      console.warn('[auth] popup failed → falling back to redirect:', err)
      try {
        await signInWithRedirect(auth, googleProvider)
        // page navigates to Google; nothing after this line will run
      } catch (err2) {
        console.error('[auth] signInWithRedirect ALSO failed:', err2)
      }
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
