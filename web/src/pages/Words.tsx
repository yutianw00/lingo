import { useEffect, useMemo, useState } from 'react'
import { api, speak, type Level, type WordCard } from '../api'
import { useApp } from '../context'
import type { Strings } from '../i18n'
import { Centered, LEVEL_COLOR, TabBar } from '../ui'

type Filter = 'all' | Level | 'due'
const FILTERS: Filter[] = ['all', 'new', 'learning', 'familiar', 'mastered', 'due']

function dueLabel(w: WordCard, now: number, t: Strings): { text: string; now: boolean } {
  if (w.due === null) return { text: t.notLearned, now: false }
  const secs = w.due - now
  if (secs <= 0) return { text: t.dueNow, now: true }
  if (secs < 86400) return { text: t.inHours(Math.max(1, Math.round(secs / 3600))), now: false }
  return { text: t.inDays(Math.round(secs / 86400)), now: false }
}

export default function Words() {
  const { me, t } = useApp()
  const [words, setWords] = useState<WordCard[] | null>(null)
  const [err, setErr] = useState(false)
  const [filter, setFilter] = useState<Filter>('all')
  const [q, setQ] = useState('')

  useEffect(() => {
    api.words().then(setWords, () => setErr(true))
  }, [])

  const [now] = useState(() => Date.now() / 1000)
  const shown = useMemo(() => {
    if (!words) return []
    const needle = q.trim().toLowerCase()
    return words.filter((w) => {
      if (filter === 'due' ? !(w.due !== null && w.due <= now) : filter !== 'all' && w.level !== filter) return false
      return !needle || w.word.toLowerCase().includes(needle) || w.meaning.toLowerCase().includes(needle)
    })
  }, [words, filter, q, now])

  if (err) return <Centered>{t.error}</Centered>
  if (!words) return <Centered>{t.loading}</Centered>

  const label = (f: Filter) => (f === 'all' ? t.all : f === 'due' ? t.dueNow : t.level[f])

  return (
    <div className="app">
      <div className="topbar">
        <h1>{t.wordsTitle}</h1>
        <span className="muted push">
          {t.langName[me.target]} · {t.total(words.length)}
        </span>
      </div>
      <input className="search" placeholder={`🔍 ${t.search}`} value={q} onChange={(e) => setQ(e.target.value)} />
      <div className="chips">
        {FILTERS.map((f) => (
          <button key={f} className={`chip${filter === f ? ' on' : ''}`} onClick={() => setFilter(f)}>
            {label(f)}
          </button>
        ))}
      </div>
      <div className="list">
        {shown.length === 0 && <div className="row muted">{t.noMatch}</div>}
        {shown.map((w) => {
          const d = dueLabel(w, now, t)
          return (
            <div className="row" key={w.id} onClick={() => speak(w.word, me.target)}>
              <div className="grow">
                <div className="w">{w.word}</div>
                <div className="z">{w.meaning}</div>
              </div>
              <div className="r">
                <div className="meter">
                  <i style={{ width: `${Math.max(w.mastery, 4)}%`, background: LEVEL_COLOR[w.level] }} />
                </div>
                <div className={`due${d.now ? ' now' : ''}`}>
                  {t.level[w.level]}
                  {w.level !== 'new' && ` ${w.mastery}`} · {d.text}
                </div>
              </div>
            </div>
          )
        })}
      </div>
      <TabBar />
    </div>
  )
}
