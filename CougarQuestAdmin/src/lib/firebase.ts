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

/* Single persistence: IndexedDB-backed browserLocal. signInWithRedirect
   needs a *single, consistent* persistence between the call (state
   stored) and the post-redirect read (state retrieved); a fallback
   ladder can land sign-in on one rung and the post-return load on
   another, dropping the redirect state on the floor. If IndexedDB is
   genuinely wedged, fall to inMemory only as a last resort to keep the
   app loadable — sign-in won't survive the redirect in that mode and
   the user has to clear site data. */
export const authPersistenceReady = setPersistence(auth, browserLocalPersistence)
  .then(() => { console.log('[firebase] persistence: browserLocal') })
  .catch((err) => {
    console.warn('[firebase] browserLocalPersistence failed → falling back to inMemory:', err)
    return setPersistence(auth, inMemoryPersistence).then(
      () => { console.log('[firebase] persistence: inMemory (signInWithRedirect WILL NOT survive)') },
      (err2) => { console.error('[firebase] inMemoryPersistence ALSO failed:', err2) },
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
