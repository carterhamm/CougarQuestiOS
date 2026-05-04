import { Card, CardHeader } from '@/components/ui/Card'
import { Input, Textarea, Label } from '@/components/ui/Input'
import { Button } from '@/components/ui/Button'
import { useState } from 'react'
import { MegaphoneIcon, ExclamationTriangleIcon } from '@heroicons/react/24/outline'

export default function BroadcastsPage() {
  const [title, setTitle] = useState('New quests available')
  const [body, setBody] = useState('Get a head start on new quests!')

  return (
    <div className="space-y-4 max-w-2xl">
      <Card>
        <CardHeader title="Send a push notification" />
        <div className="p-5 space-y-4">
          <div className="space-y-1.5">
            <Label>Title</Label>
            <Input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={64} />
          </div>
          <div className="space-y-1.5">
            <Label>Body</Label>
            <Textarea rows={3} value={body} onChange={(e) => setBody(e.target.value)} maxLength={240} />
          </div>

          <div className="rounded-2xl border bg-secondary/40 p-4 space-y-1">
            <div className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground">Preview</div>
            <div className="flex items-start gap-3 mt-1">
              <div className="h-10 w-10 rounded-xl bg-cougar text-white flex items-center justify-center font-black">CQ</div>
              <div className="flex-1 min-w-0">
                <div className="text-sm font-semibold line-clamp-1">{title || '—'}</div>
                <div className="text-sm text-muted-foreground line-clamp-2">{body || '—'}</div>
              </div>
              <span className="text-[11px] text-muted-foreground">now</span>
            </div>
          </div>

          <div className="rounded-xl bg-amber-500/10 text-amber-700 dark:text-amber-400 text-sm p-3 flex items-start gap-2">
            <ExclamationTriangleIcon className="h-4 w-4 mt-0.5 shrink-0" />
            <div>
              Sending requires the Cloud Function backing <code>NotificationService</code>. Wire up the call here once the
              function endpoint is deployed; this UI is ready for it.
            </div>
          </div>

          <div className="flex justify-end">
            <Button disabled>
              <MegaphoneIcon className="h-4 w-4" />
              Send to all signed-in campers
            </Button>
          </div>
        </div>
      </Card>
    </div>
  )
}
