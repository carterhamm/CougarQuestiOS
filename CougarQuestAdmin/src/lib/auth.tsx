import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { onAuthStateChanged, signInWithPopup, signOut, type User } from 'firebase/auth'
import { doc, onSnapshot, setDoc } from 'firebase/firestore'
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
  const [isAdmin, setIsAdmin] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const authSafety = window.setTimeout(() => {
      console.warn('[auth] onAuthStateChanged did not fire within 6s — forcing loading=false')
      setLoading(false)
    }, 6000)

    const unsub = onAuthStateChanged(auth, (u) => {
      window.clearTimeout(authSafety)
      console.log('[auth] onAuthStateChanged →', u ? `signed in as ${u.uid}` : 'signed out')
      setUser(u)
      if (!u) {
        setIsAdmin(false)
        setLoading(false)
      } else {
        const updates: Record<string, string> = {}
        if (u.email) updates.email = u.email
        if (u.displayName) updates.name = u.displayName
        if (Object.keys(updates).length) {
          setDoc(doc(db, 'users', u.uid), updates, { merge: true })
            .catch((err) => console.warn('[auth] user doc merge failed:', err))
        }
      }
    })
    return () => { window.clearTimeout(authSafety); unsub() }
  }, [])

  useEffect(() => {
    if (!user) return
    let resolved = false
    const safety = window.setTimeout(() => {
      if (!resolved) {
        console.warn('[auth] user doc snapshot did not fire within 5s — forcing loading=false')
        setLoading(false)
      }
    }, 5000)
    const unsub = onSnapshot(doc(db, 'users', user.uid), (snap) => {
      resolved = true
      const data = snap.data()
      console.log('[auth] user doc snapshot:', data ? { isAdmin: Boolean(data.isAdmin) } : '<doc does not exist>')
      setIsAdmin(Boolean(data?.isAdmin))
      setLoading(false)
    }, (err) => {
      resolved = true
      console.error('[auth] user doc subscribe error:', err)
      setLoading(false)
    })
    return () => { window.clearTimeout(safety); unsub() }
  }, [user])

  const value: AuthState = {
    user,
    isAdmin,
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
