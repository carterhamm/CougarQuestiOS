import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import {
  addDoc, collection, deleteDoc, doc, serverTimestamp, updateDoc,
} from 'firebase/firestore'
import { ref as storageRef, uploadBytes, getDownloadURL, deleteObject } from 'firebase/storage'
import { Trash2, Image as ImageIcon } from 'lucide-react'
import { motion } from 'motion/react'
import { db, storage } from '@/lib/firebase'
import type { Quest } from '@/lib/types'
import { useQuests } from '@/lib/queries'
import { Button } from '@/components/ui/Button'
import { Input, Textarea, Label } from '@/components/ui/Input'
import { appleMapsUrlToPlusCode } from '@/lib/maps'
import { useSubview } from '@/lib/subview'

const blank: Quest = {
  id: '', title: '', address: '', description: '',
  mapsLink: '', plusCode: '', photoURL: '',
}

export default function QuestEditor() {
  const { id } = useParams<{ id: string }>()
  const isNew = !id || id === 'new'
  const navigate = useNavigate()
  const qc = useQueryClient()
  const { data: quests = [] } = useQuests()

  const initialQuest = useMemo(() => {
    if (isNew) return blank
    return quests.find((q) => q.id === id) ?? blank
  }, [isNew, id, quests])

  const [form, setForm] = useState<Quest>(initialQuest)
  const [photoFile, setPhotoFile] = useState<File | null>(null)
  const [photoPreview, setPhotoPreview] = useState<string>('')

  useEffect(() => {
    if (!isNew && initialQuest.id) setForm(initialQuest)
  }, [isNew, initialQuest])

  // Hand the TopBar a back-pill (left) + centered title (middle).
  useSubview({
    title: isNew ? 'New quest' : (form.title || 'Edit quest'),
    backTo: '/quests',
    backLabel: 'Quests',
  })

  const save = useMutation({
    mutationFn: async () => {
      const data = {
        title: form.title, address: form.address, description: form.description,
        mapsLink: form.mapsLink, plusCode: form.plusCode, photoURL: form.photoURL,
      }
      let questId = form.id
      if (isNew) {
        const newDoc = await addDoc(collection(db, 'quests'), { ...data, createdAt: serverTimestamp() })
        questId = newDoc.id
        await updateDoc(doc(db, 'quests', questId), { id: questId })
      } else {
        await updateDoc(doc(db, 'quests', questId), data)
      }
      if (photoFile) {
        const ref = storageRef(storage, `questPhotos/${questId}.jpg`)
        await uploadBytes(ref, photoFile, { contentType: photoFile.type || 'image/jpeg' })
        const url = await getDownloadURL(ref)
        await updateDoc(doc(db, 'quests', questId), { photoURL: url })
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['quests'] })
      navigate('/quests')
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
      navigate('/quests')
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
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ type: 'spring', stiffness: 280, damping: 26 }}
      className="space-y-6 max-w-3xl mx-auto"
    >
      <div className="flex items-center justify-end gap-2">
        {!isNew && (
          <Button
            variant="destructive"
            size="md"
            onClick={() => {
              if (confirm(`Delete "${form.title}"? This cannot be undone.`)) remove.mutate()
            }}
            disabled={remove.isPending}
          >
            <Trash2 className="h-4 w-4" />
            Delete
          </Button>
        )}
        <Button
          size="md"
          onClick={() => save.mutate()}
          disabled={save.isPending || !form.title.trim()}
        >
          {save.isPending ? 'Saving…' : isNew ? 'Create quest' : 'Save changes'}
        </Button>
      </div>

      {/* Photo */}
      <div className="space-y-2">
        <Label>Photo</Label>
        {previewUrl ? (
          <div className="relative rounded-3xl overflow-hidden">
            <img src={previewUrl} alt="" data-liquid-glass className="w-full h-72 object-cover" />
            <label className="absolute bottom-3 right-3 bg-black/60 text-white text-xs font-semibold px-3 py-1.5 rounded-full cursor-pointer hover:bg-black/80">
              Replace
              <input type="file" accept="image/*" className="hidden" onChange={onPickPhoto} />
            </label>
          </div>
        ) : (
          <label className="flex flex-col items-center justify-center w-full h-72 border-2 border-dashed rounded-3xl cursor-pointer hover:bg-secondary/50 transition">
            <ImageIcon className="h-8 w-8 text-muted-foreground" />
            <span className="mt-2 text-sm text-muted-foreground">Click to upload</span>
            <input type="file" accept="image/*" className="hidden" onChange={onPickPhoto} />
          </label>
        )}
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
          <Input
            value={form.mapsLink}
            placeholder="https://maps.apple.com/?ll=… or maps.apple/p/…"
            onChange={(e) => {
              const v = e.target.value
              setForm({ ...form, mapsLink: v })
              appleMapsUrlToPlusCode(v).then((code) => {
                if (code) setForm((prev) => ({ ...prev, mapsLink: v, plusCode: code }))
              })
            }}
          />
        </Field>
        <Field label="Plus code">
          <Input value={form.plusCode} onChange={(e) => setForm({ ...form, plusCode: e.target.value })} placeholder="7FG9+V6 Provo" />
        </Field>
      </div>

      {save.isError && (
        <div className="rounded-2xl bg-destructive/10 text-destructive text-sm p-3">
          {(save.error as Error)?.message || 'Save failed.'}
        </div>
      )}
    </motion.div>
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
