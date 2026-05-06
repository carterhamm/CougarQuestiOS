import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { onAuthStateChanged, signInWithPopup, signOut, type User } from 'firebase/auth'
import { doc, onSnapshot, setDoc } from 'firebase/firestore'
import { auth, db, googleProvider } from './firebase'

/* Bootstrap admin allowlist. Emails listed here are granted admin even
   before their Firestore user doc has isAdmin=true — solves the
   chicken-and-egg trap of "you need isAdmin in Firestore to use the
   dashboard, but you need the dashboard to write it." On first sign-in
   from an allowlisted email we also persist isAdmin=true to Firestore so
   subsequent sessions don't need this list. To onboard another admin: add
   their email here, sign them in once, then it can be removed. */
const ADMIN_EMAILS = new Set<string>([
  'carter.n.hammond@gmail.com',
])

interface AuthState {
  user: User | null
  isAdmin: boolean
  loading: boolean
  signIn: () => Promise<void>
  signOutNow: () => Promise<void>
}

const AuthCtx = createContext<AuthState | null>(null)

function isAllowlisted(email: string | null | undefined): boolean {
  return Boolean(email && ADMIN_EMAILS.has(email.toLowerCase()))
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [docIsAdmin, setDocIsAdmin] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const authSafety = window.setTimeout(() => {
      console.warn('[auth] onAuthStateChanged did not fire within 6s — forcing loading=false')
      setLoading(false)
    }, 6000)

    const unsub = onAuthStateChanged(auth, (u) => {
      window.clearTimeout(authSafety)
      console.log('[auth] onAuthStateChanged →', u ? `signed in as ${u.uid} <${u.email}>` : 'signed out')
      setUser(u)
      if (!u) {
        setDocIsAdmin(false)
        setLoading(false)
      } else {
        const updates: Record<string, unknown> = {}
        if (u.email) updates.email = u.email
        if (u.displayName) updates.name = u.displayName
        // Bootstrap admin into the user doc the first time an allowlisted
        // email signs in, so the dashboard sees isAdmin=true on subsequent
        // refreshes too (not just from this in-memory check).
        if (isAllowlisted(u.email)) updates.isAdmin = true
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
      setDocIsAdmin(Boolean(data?.isAdmin))
      setLoading(false)
    }, (err) => {
      resolved = true
      console.error('[auth] user doc subscribe error:', err)
      setLoading(false)
    })
    return () => { window.clearTimeout(safety); unsub() }
  }, [user])

  // Effective admin = Firestore admin OR allowlisted email. Either path
  // unblocks the dashboard; both can be true simultaneously after bootstrap.
  const isAdmin = docIsAdmin || isAllowlisted(user?.email)

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
