import { useCallback, useRef, useState } from 'react'
import { NavLink } from 'react-router-dom'
import type { Lang, Level } from './api'
import { useApp } from './context'

export const LEVEL_COLOR: Record<Level, string> = {
  new: 'var(--lv0)',
  learning: 'var(--lv1)',
  familiar: 'var(--lv2)',
  mastered: 'var(--lv3)',
}

export function LangBadge({ lang, small }: { lang: Lang; small?: boolean }) {
  return <span className={`lang-badge lang-${lang}${small ? ' sm' : ''}`}>{lang.toUpperCase()}</span>
}

export function TabBar() {
  const { t } = useApp()
  return (
    <nav className="tabbar">
      <NavLink to="/" end>
        <span>🏠</span>
        {t.tabLearn}
      </NavLink>
      <NavLink to="/words">
        <span>📚</span>
        {t.tabWords}
      </NavLink>
    </nav>
  )
}

export function Progress({ value }: { value: number }) {
  return (
    <div className="progress">
      <i style={{ width: `${Math.min(100, Math.max(0, value * 100))}%` }} />
    </div>
  )
}

export function LevelBars({ level }: { level: Level }) {
  const n = { new: 0, learning: 1, familiar: 2, mastered: 3 }[level]
  return (
    <span className="lvl">
      {[0, 1, 2].map((k) => (
        <i key={k} style={{ background: k < n ? LEVEL_COLOR[level] : undefined }} />
      ))}
    </span>
  )
}

export function Centered({ children }: { children: React.ReactNode }) {
  return <div className="centered">{children}</div>
}

export function useToast(): [string | null, (msg: string) => void] {
  const [msg, setMsg] = useState<string | null>(null)
  const timer = useRef<number | undefined>(undefined)
  const show = useCallback((m: string) => {
    setMsg(m)
    window.clearTimeout(timer.current)
    timer.current = window.setTimeout(() => setMsg(null), 1500)
  }, [])
  return [msg, show]
}

export function Toast({ msg }: { msg: string | null }) {
  return <div className={`toast${msg ? ' show' : ''}`}>{msg}</div>
}

export const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))
