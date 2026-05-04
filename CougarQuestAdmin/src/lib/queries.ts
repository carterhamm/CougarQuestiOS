import { useQuery } from '@tanstack/react-query'
import { collection, getDocs, orderBy, query } from 'firebase/firestore'
import { db } from './firebase'
import type { Quest, UserProfile } from './types'

export function useQuests() {
  return useQuery<Quest[]>({
    queryKey: ['quests'],
    queryFn: async () => {
      const snap = await getDocs(collection(db, 'quests'))
      return snap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<Quest, 'id'>) }))
    },
  })
}

export function useUsers() {
  return useQuery<UserProfile[]>({
    queryKey: ['users'],
    queryFn: async () => {
      const snap = await getDocs(query(collection(db, 'users'), orderBy('points', 'desc')))
      return snap.docs.map((d) => ({ uid: d.id, ...(d.data() as Omit<UserProfile, 'uid'>) }))
    },
  })
}

export function displayNameFor(u: UserProfile): string {
  const team = (u.teamName || '').trim()
  if (team) return team
  const first = (u.firstName || u.name || '').trim()
  const sons = (u.sons || []).map((s) => s.trim()).filter(Boolean)
  const all = first ? [first, ...sons] : sons
  if (all.length === 0) return 'Unnamed user'
  if (all.length === 1) return all[0]
  if (all.length === 2) return `${all[0]} and ${all[1]}`
  return `${all.slice(0, -1).join(', ')}, and ${all[all.length - 1]}`
}
