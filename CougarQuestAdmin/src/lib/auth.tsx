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
    const unsub = onAuthStateChanged(auth, (u) => {
      setUser(u)
      if (!u) {
        setIsAdmin(false)
        setLoading(false)
      } else {
        const updates: Record<string, string> = {}
        if (u.email) updates.email = u.email
        if (u.displayName) updates.name = u.displayName
        if (Object.keys(updates).length) {
          setDoc(doc(db, 'users', u.uid), updates, { merge: true }).catch(() => {})
        }
      }
    })
    return () => unsub()
  }, [])

  useEffect(() => {
    if (!user) return
    const unsub = onSnapshot(doc(db, 'users', user.uid), (snap) => {
      setIsAdmin(Boolean(snap.data()?.isAdmin))
      setLoading(false)
    }, () => setLoading(false))
    return () => unsub()
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
