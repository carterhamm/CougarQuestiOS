import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from '@/lib/auth'
import AppShell from '@/components/AppShell'
import SignIn from '@/pages/SignIn'
import Overview from '@/pages/Overview'
import Quests from '@/pages/Quests'
import Campers from '@/pages/Campers'
import Leaderboard from '@/pages/Leaderboard'
import Broadcasts from '@/pages/Broadcasts'
import Settings from '@/pages/Settings'

export default function App() {
  const { user, isAdmin, loading } = useAuth()

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <div className="h-8 w-8 rounded-full border-2 border-cougar border-t-transparent animate-spin" />
      </div>
    )
  }

  if (!user || !isAdmin) {
    return <SignIn />
  }

  return (
    <Routes>
      <Route element={<AppShell />}>
        <Route index element={<Overview />} />
        <Route path="quests" element={<Quests />} />
        <Route path="campers" element={<Campers />} />
        <Route path="leaderboard" element={<Leaderboard />} />
        <Route path="broadcasts" element={<Broadcasts />} />
        <Route path="settings" element={<Settings />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  )
}
