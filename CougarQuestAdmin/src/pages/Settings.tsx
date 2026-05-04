import { Card, CardHeader } from '@/components/ui/Card'
import { useAuth } from '@/lib/auth'
import { ShieldExclamationIcon } from '@heroicons/react/24/outline'

export default function SettingsPage() {
  const { user } = useAuth()
  return (
    <div className="space-y-4 max-w-2xl">
      <Card>
        <CardHeader title="Signed in as" />
        <div className="p-5 flex items-center gap-4">
          <div className="h-12 w-12 rounded-full bg-cougar text-white font-bold flex items-center justify-center">
            {(user?.displayName || user?.email || '?').slice(0, 1).toUpperCase()}
          </div>
          <div className="min-w-0">
            <div className="font-semibold truncate">{user?.displayName}</div>
            <div className="text-sm text-muted-foreground truncate">{user?.email}</div>
          </div>
        </div>
      </Card>

      <Card>
        <CardHeader title="Security" />
        <div className="p-5 space-y-3">
          <div className="rounded-xl bg-destructive/10 text-destructive text-sm p-3 flex items-start gap-2">
            <ShieldExclamationIcon className="h-4 w-4 mt-0.5 shrink-0" />
            <div>
              <div className="font-semibold">Firestore rules are wide open.</div>
              <div>
                <code>firestore.rules</code> currently allows any client to read/write. Tighten writes on{' '}
                <code>quests/*</code> and <code>users/*/points</code> behind <code>request.auth.token.admin == true</code>{' '}
                before going to production.
              </div>
            </div>
          </div>

          <p className="text-sm text-muted-foreground">
            Admin access is controlled by the <code>isAdmin</code> field on each user's Firestore document. Toggle it from the{' '}
            <strong>Campers</strong> page.
          </p>
        </div>
      </Card>
    </div>
  )
}
