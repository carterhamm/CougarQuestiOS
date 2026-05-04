import { initializeApp } from 'firebase/app'
import { getAuth, GoogleAuthProvider } from 'firebase/auth'
import { getFirestore } from 'firebase/firestore'
import { getStorage } from 'firebase/storage'

const firebaseConfig = {
  apiKey: 'AIzaSyB05BESHEsgffXXfSPDjt8wvPWxTXG9da0',
  authDomain: 'cougarquest-62ba2.firebaseapp.com',
  projectId: 'cougarquest-62ba2',
  storageBucket: 'cougarquest-62ba2.firebasestorage.app',
  messagingSenderId: '930268237097',
  appId: '1:930268237097:web:3a0a7050ef9923e784bb38',
}

export const app = initializeApp(firebaseConfig)
export const auth = getAuth(app)
export const db = getFirestore(app)
export const storage = getStorage(app, 'gs://cougarquest-62ba2.firebasestorage.app')
export const googleProvider = new GoogleAuthProvider()
