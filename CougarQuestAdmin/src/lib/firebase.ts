import { initializeApp } from 'firebase/app'
import {
  GoogleAuthProvider,
  browserLocalPersistence,
  getAuth,
  inMemoryPersistence,
  setPersistence,
} from 'firebase/auth'
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

console.log('[firebase] initializeApp')
export const app = initializeApp(firebaseConfig)
export const auth = getAuth(app)
console.log('[firebase] getAuth ready')

/* If Firebase Auth's IndexedDB-backed persistence fails to initialize —
   most often because the browser's IndexedDB is locked, corrupt, blocked
   by an extension, or unavailable in a private window — onAuthStateChanged
   never fires and the whole app sits at the spinner. Try local persistence
   first; if the promise rejects, fall back to in-memory persistence so
   auth at least *initializes* (sessions don't persist across reloads in
   that case, but the app loads). */
setPersistence(auth, browserLocalPersistence)
  .then(() => console.log('[firebase] persistence: browserLocal'))
  .catch((err) => {
    console.warn('[firebase] browserLocalPersistence failed → falling back to inMemory:', err)
    return setPersistence(auth, inMemoryPersistence).then(
      () => console.log('[firebase] persistence: inMemory (sessions will not persist this run)'),
      (err2) => console.error('[firebase] inMemoryPersistence ALSO failed:', err2),
    )
  })

/* Surface whether the auth-state-ready promise ever resolves so a hung
   init leaves a visible trace. */
auth.authStateReady().then(
  () => console.log('[firebase] authStateReady resolved, currentUser =', auth.currentUser?.uid ?? 'null'),
  (err) => console.error('[firebase] authStateReady REJECTED:', err),
)

export const db = getFirestore(app)
export const storage = getStorage(app, 'gs://cougarquest-62ba2.firebasestorage.app')
export const googleProvider = new GoogleAuthProvider()
