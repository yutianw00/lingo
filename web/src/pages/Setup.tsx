import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api, type Lang } from '../api'
import { useApp } from '../context'
import { LANGS, SELF_NAME, STRINGS } from '../i18n'
import { LangBadge } from '../ui'

export default function Setup() {
  const { me, setMe } = useApp()
  const nav = useNavigate()
  const [native, setNative] = useState<Lang>(me.native)
  const [target, setTarget] = useState<Lang>(me.target === me.native ? LANGS.find((l) => l !== me.native)! : me.target)
  const [saving, setSaving] = useState(false)
  const [err, setErr] = useState(false)
  const t = STRINGS[native] // preview the UI in the language being picked

  const pickNative = (l: Lang) => {
    setNative(l)
    if (target === l) setTarget(LANGS.find((x) => x !== l)!)
  }

  const save = async () => {
    setSaving(true)
    setErr(false)
    try {
      setMe(await api.saveMe({ native, target }))
      nav('/')
    } catch {
      setErr(true)
    } finally {
      setSaving(false)
    }
  }

  const grid = (sel: Lang, onPick: (l: Lang) => void, disabled?: Lang) => (
    <div className="lang-grid">
      {LANGS.map((l) => (
        <button key={l} className={`lang-opt${sel === l ? ' on' : ''}`} disabled={l === disabled} onClick={() => onPick(l)}>
          <LangBadge lang={l} />
          <span>
            {t.langName[l]}
            <small>{SELF_NAME[l]}</small>
          </span>
        </button>
      ))}
    </div>
  )

  return (
    <div className="app">
      <div className="topbar">
        {me.onboarded && (
          <button className="icon-btn" onClick={() => nav('/')} aria-label="back">
            ←
          </button>
        )}
        <h1>{t.getStarted}</h1>
      </div>
      <h2>{t.myLanguage}</h2>
      {grid(native, pickNative)}
      <h2>{t.iWantToLearn}</h2>
      {grid(target, setTarget, native)}
      <p className="pair-summary">{t.learningPair(t.langName[native], t.langName[target])}</p>
      {err && <p className="err">{t.error}</p>}
      <div className="bottom">
        <button className="btn" onClick={save} disabled={saving}>
          {me.onboarded ? t.save : t.start}
        </button>
      </div>
    </div>
  )
}
