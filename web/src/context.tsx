import { createContext, useContext } from 'react'
import type { Me } from './api'
import type { Strings } from './i18n'

export interface AppCtx {
  me: Me
  setMe: (m: Me) => void
  t: Strings
}

export const Ctx = createContext<AppCtx | null>(null)

export function useApp(): AppCtx {
  const v = useContext(Ctx)
  if (!v) throw new Error('useApp outside provider')
  return v
}
