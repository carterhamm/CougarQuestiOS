import { useMemo, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  serverTimestamp,
  updateDoc,
} from 'firebase/firestore'
import { ref as storageRef, uploadBytes, getDownloadURL, deleteObject } from 'firebase/storage'
import { PlusIcon, MagnifyingGlassIcon, TrashIcon, PhotoIcon } from '@heroicons/react/24/outline'
import { db, storage } from '@/lib/firebase'
import type { Quest } from '@/lib/types'
import { useQuests, useUsers } from '@/lib/queries'
import { Button } from '@/components/ui/Button'
import { Input, Textarea, Label } from '@/components/ui/Input'
import { Drawer } from '@/components/ui/Drawer'
import { Card } from '@/components/ui/Card'

const blank: Quest = {
  id: '',
  title: '',
  address: '',
  description: '',
  mapsLink: '',
  plusCode: '',
  photoURL: '',
}

export default function QuestsPage() {
  const { data: quests = [], isLoading } = useQuests()
  const { data: users = [] } = useUsers()
  const [search, setSearch] = useState('')
  const [editing, setEditing] = useState<Quest | null>(null)

  const completionsByTitle = useMemo(() => {
    const map = new Map<string, number>()
    for (const u of users) {
      for (const t of u.completedQuests ?? []) {
        map.set(t, (map.get(t) ?? 0) + 1)
      }
    }
    return map
  }, [users])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return quests
    return quests.filter(
      (x) =>
        x.title.toLowerCase().includes(q) ||
        x.address.toLowerCase().includes(q) ||
        x.description.toLowerCase().includes(q),
    )
  }, [quests, search])

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <div className="relative flex-1 max-w-md">
          <MagnifyingGlassIcon className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search quests"
            className="pl-9"
          />
        </div>
        <Button onClick={() => setEditing({ ...blank })}>
          <PlusIcon className="h-4 w-4" />
          New quest
        </Button>
      </div>

      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              <tr className="border-b">
                <th className="px-5 py-3 w-16"></th>
                <th className="px-5 py-3">Title</th>
                <th className="px-5 py-3">Address</th>
                <th className="px-5 py-3 text-right">Completions</th>
              </tr>
            </thead>
            <tbody>
              {isLoading && (
                <tr><td colSpan={4} className="px-5 py-12 text-center text-muted-foreground">Loading…</td></tr>
              )}
              {!isLoading && filtered.length === 0 && (
                <tr><td colSpan={4} className="px-5 py-12 text-center text-muted-foreground">
                  {search ? 'No quests match.' : 'No quests yet — add the first one.'}
                </td></tr>
              )}
              {filtered.map((q) => (
                <tr
                  key={q.id}
                  onClick={() => setEditing(q)}
                  className="border-b last:border-0 hover:bg-secondary/50 cursor-pointer"
                >
                  <td className="px-5 py-3">
                    <Thumb url={q.photoURL} title={q.title} />
                  </td>
                  <td className="px-5 py-3">
                    <div className="font-semibold">{q.title || <span className="text-muted-foreground italic">untitled</span>}</div>
                    <div className="text-xs text-muted-foreground line-clamp-1">{q.description}</div>
                  </td>
                  <td className="px-5 py-3 text-muted-foreground">
                    <div className="line-clamp-1">{q.address || '—'}</div>
                    {q.plusCode && <div className="text-xs">{q.plusCode}</div>}
                  </td>
                  <td className="px-5 py-3 text-right tabular font-semibold">
                    {completionsByTitle.get(q.title) ?? 0}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <QuestEditor quest={editing} onClose={() => setEditing(null)} />
    </div>
  )
}

function Thumb({ url, title }: { url?: string; title: string }) {
  if (!url) {
    return (
      <div className="h-12 w-12 rounded-lg bg-secondary flex items-center justify-center text-muted-foreground">
        <PhotoIcon className="h-5 w-5" />
      </div>
    )
  }
  return (
    <img
      src={url}
      alt={title}
      data-liquid-glass
      crossOrigin="anonymous"
      className="h-12 w-12 rounded-lg object-cover"
      onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }}
    />
  )
}

function QuestEditor({ quest, onClose }: { quest: Quest | null; onClose: () => void }) {
  const open = quest !== null
  const isNew = !quest?.id
  const qc = useQueryClient()

  const [form, setForm] = useState<Quest>(quest ?? blank)
  const [photoFile, setPhotoFile] = useState<File | null>(null)
  const [photoPreview, setPhotoPreview] = useState<string>('')

  // Sync form when quest changes
  useMemo(() => {
    if (quest) { setForm(quest); setPhotoFile(null); setPhotoPreview('') }
  }, [quest])

  const save = useMutation({
    mutationFn: async () => {
      const data = {
        title: form.title,
        address: form.address,
        description: form.description,
        mapsLink: form.mapsLink,
        plusCode: form.plusCode,
        photoURL: form.photoURL,
      }
      let id = form.id
      if (isNew) {
        const newDoc = await addDoc(collection(db, 'quests'), {
          ...data,
          createdAt: serverTimestamp(),
        })
        id = newDoc.id
        await updateDoc(doc(db, 'quests', id), { id })
      } else {
        await updateDoc(doc(db, 'quests', id), data)
      }
      if (photoFile) {
        const ref = storageRef(storage, `questPhotos/${id}.jpg`)
        await uploadBytes(ref, photoFile, { contentType: photoFile.type || 'image/jpeg' })
        const url = await getDownloadURL(ref)
        await updateDoc(doc(db, 'quests', id), { photoURL: url })
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['quests'] })
      onClose()
    },
  })

  const remove = useMutation({
    mutationFn: async () => {
      if (!form.id) return
      await deleteDoc(doc(db, 'quests', form.id))
      try { await deleteObject(storageRef(storage, `questPhotos/${form.id}.jpg`)) } catch { /* ignore */ }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['quests'] })
      onClose()
    },
  })

  function onPickPhoto(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setPhotoFile(file)
    setPhotoPreview(URL.createObjectURL(file))
  }

  const previewUrl = photoPreview || form.photoURL

  return (
    <Drawer
      open={open}
      onClose={onClose}
      title={isNew ? 'New quest' : 'Edit quest'}
      footer={
        <div className="flex items-center justify-between">
          {!isNew ? (
            <Button
              variant="destructive"
              size="sm"
              onClick={() => {
                if (confirm(`Delete "${form.title}"? This cannot be undone.`)) remove.mutate()
              }}
              disabled={remove.isPending}
            >
              <TrashIcon className="h-4 w-4" />
              Delete
            </Button>
          ) : <span />}
          <div className="flex items-center gap-2">
            <Button variant="ghost" size="sm" onClick={onClose}>Cancel</Button>
            <Button size="sm" onClick={() => save.mutate()} disabled={save.isPending || !form.title.trim()}>
              {save.isPending ? 'Saving…' : (isNew ? 'Create quest' : 'Save changes')}
            </Button>
          </div>
        </div>
      }
    >
      <div className="space-y-5">
        <div>
          <Label>Photo</Label>
          <div className="mt-2">
            {previewUrl ? (
              <div className="relative rounded-2xl overflow-hidden">
                <img src={previewUrl} alt="" data-liquid-glass crossOrigin="anonymous" className="w-full h-48 object-cover" />
                <label className="absolute bottom-2 right-2 bg-black/60 text-white text-xs font-semibold px-3 py-1.5 rounded-lg cursor-pointer hover:bg-black/80">
                  Replace
                  <input type="file" accept="image/*" className="hidden" onChange={onPickPhoto} />
                </label>
              </div>
            ) : (
              <label className="flex flex-col items-center justify-center w-full h-48 border-2 border-dashed rounded-2xl cursor-pointer hover:bg-secondary/50 transition">
                <PhotoIcon className="h-8 w-8 text-muted-foreground" />
                <span className="mt-2 text-sm text-muted-foreground">Click to upload</span>
                <input type="file" accept="image/*" className="hidden" onChange={onPickPhoto} />
              </label>
            )}
          </div>
        </div>

        <Field label="Title">
          <Input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="e.g. Marriott Center" />
        </Field>

        <Field label="Description">
          <Textarea
            rows={4}
            value={form.description}
            onChange={(e) => setForm({ ...form, description: e.target.value })}
            placeholder="Briefly describe what campers will do here"
          />
        </Field>

        <Field label="Address">
          <Input value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} placeholder="1450 N University Ave, Provo, UT" />
        </Field>

        <div className="grid grid-cols-2 gap-3">
          <Field label="Maps link">
            <Input value={form.mapsLink} onChange={(e) => setForm({ ...form, mapsLink: e.target.value })} placeholder="https://maps.apple.com/?q=…" />
          </Field>
          <Field label="Plus code">
            <Input value={form.plusCode} onChange={(e) => setForm({ ...form, plusCode: e.target.value })} placeholder="7FG9+V6 Provo" />
          </Field>
        </div>

        {save.isError && (
          <div className="rounded-xl bg-destructive/10 text-destructive text-sm p-3">
            {(save.error as Error)?.message || 'Save failed.'}
          </div>
        )}
      </div>
    </Drawer>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="space-y-1.5">
      <Label>{label}</Label>
      {children}
    </div>
  )
}
