import type { Timestamp } from 'firebase/firestore'

export interface Quest {
  id: string
  title: string
  address: string
  description: string
  mapsLink: string
  plusCode: string
  photoURL: string
  createdAt?: Timestamp | Date | null
  completedAt?: Timestamp | Date | null
}

export interface UserProfile {
  uid: string
  name?: string
  firstName?: string
  lastName?: string
  phoneNumber?: string
  sons?: string[]
  points?: number
  completedQuests?: string[]
  teamName?: string
  grandpa?: string
  isAdmin?: boolean
  fcmToken?: string
}
