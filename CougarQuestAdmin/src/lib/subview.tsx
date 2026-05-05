import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'

interface SubviewState {
  /** Title shown centered in the TopBar (e.g. quest name, camper team). */
  title: string
  /** Path the back-pill should navigate to. */
  backTo: string
  /** Optional shorter label for the back pill. Defaults to "Back". */
  backLabel?: string
}

interface SubviewCtx {
  subview: SubviewState | null
  set: (s: SubviewState | null) => void
}

const Ctx = createContext<SubviewCtx | null>(null)

export function SubviewProvider({ children }: { children: ReactNode }) {
  const [subview, set] = useState<SubviewState | null>(null)
  return <Ctx.Provider value={{ subview, set }}>{children}</Ctx.Provider>
}

export function useSubviewState() {
  const v = useContext(Ctx)
  if (!v) throw new Error('useSubviewState must be inside SubviewProvider')
  return v.subview
}

/**
 * Call from a full-screen subview (Quest editor, Camper detail, …) to take
 * over the TopBar with a back-pill on the left and a centered title. Pass
 * `null`-equivalent (omit) to clear; the hook clears on unmount automatically.
 */
export function useSubview(state: SubviewState | null) {
  const ctx = useContext(Ctx)
  if (!ctx) throw new Error('useSubview must be inside SubviewProvider')
  const { set } = ctx
  const key = state ? `${state.title}|${state.backTo}|${state.backLabel ?? ''}` : 'null'
  useEffect(() => {
    set(state)
    return () => set(null)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key])
}
