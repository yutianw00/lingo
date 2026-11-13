import { useCallback, useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api, speak, type AnswerResult, type Question } from '../api'
import { useApp } from '../context'
import { Centered, Progress } from '../ui'

export default function Quiz() {
  const { me, t } = useApp()
  const nav = useNavigate()
  const [qs, setQs] = useState<Question[] | null>(null)
  const [err, setErr] = useState(false)
  const [n, setN] = useState(0)
  const [sel, setSel] = useState<string | null>(null)
  const [result, setResult] = useState<AnswerResult | null>(null)
  const [showTr, setShowTr] = useState(false)
  const [checking, setChecking] = useState(false)
  const [score, setScore] = useState(0)
  const startedAt = useRef(performance.now())

  const load = useCallback(() => {
    setQs(null)
    setErr(false)
    api.quizSession(10).then(
      (q) => {
        setQs(q)
        setN(0)
        setScore(0)
      },
      () => setErr(true),
    )
  }, [])
  useEffect(load, [load])

  useEffect(() => {
    setSel(null)
    setResult(null)
    setShowTr(false)
    startedAt.current = performance.now()
  }, [n, qs])

  const check = async () => {
    if (!qs || sel === null || result || checking) return
    setChecking(true)
    try {
      const r = await api.answer(qs[n].id, { choice: sel, elapsed_ms: Math.round(performance.now() - startedAt.current) })
      setResult(r)
      if (r.correct) setScore((s) => s + 1)
      speak(r.full_sentence, me.target)
    } catch {
      setErr(true)
    } finally {
      setChecking(false)
    }
  }

  // Enter = check / continue, 1-4 = pick an option.
  const keys = useRef<{ check: () => void; next: () => void; pick: (k: number) => void }>(null!)
  keys.current = {
    check,
    next: () => setN((x) => x + 1),
    pick: (k) => {
      const o = qs?.[n]?.options[k]
      if (o && !result) setSel(o.text)
    },
  }
  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      if (e.key === 'Enter') (result ? keys.current.next : keys.current.check)()
      else if (/^[1-4]$/.test(e.key)) keys.current.pick(+e.key - 1)
    }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [result])

  if (err)
    return (
      <Centered>
        <p>{t.error}</p>
        <button className="btn" onClick={load}>
          {t.retry}
        </button>
      </Centered>
    )
  if (!qs) return <Centered>{t.loading}</Centered>
  if (qs.length === 0)
    return (
      <Centered>
        <p>{t.quizLocked}</p>
        <button className="btn" onClick={() => nav('/swipe')}>
          {t.goSwipe}
        </button>
      </Centered>
    )

  if (n >= qs.length)
    return (
      <div className="app">
        <div className="topbar">
          <button className="icon-btn" onClick={() => nav('/')} aria-label="close">
            ✕
          </button>
          <Progress value={1} />
        </div>
        <div className="done">
          <div className="big">🏆</div>
          <h1>{t.quizDone}</h1>
          <p className="muted">
            {t.accuracy(Math.round((score / Math.max(qs.length, 1)) * 100))} · {t.quizDoneHint}
          </p>
          <button className="btn" onClick={load}>
            {t.again}
          </button>
          <button className="btn ghost" onClick={() => nav('/')}>
            {t.backHome}
          </button>
        </div>
      </div>
    )

  const q = qs[n]
  const isFill = q.kind === 'fill'
  const legacy = !q.id.includes('-') // aligned 4-language content has plain ids (f01, n01)
  const typeLabel = legacy ? (isFill ? t.fill : t.next) : t.skill[q.skill]
  const hint = q.skill === 'vocab' ? t.vocabHint : isFill ? (legacy ? t.fillHint : t.formHint) : t.nextHint
  // Vocabulary cloze tests recall of a meaning, so the translation is shown up front.
  const translationShown = showTr || !!result || q.skill === 'vocab'
  const [before, after] = isFill ? q.prompt.split('___') : [q.prompt, '']

  const optClass = (text: string) => {
    if (!result) return sel === text ? ' sel' : ''
    if (text === result.answer) return ' right'
    if (text === sel) return ' wrong'
    return ''
  }

  return (
    <div className="app">
      <div className="topbar">
        <button className="icon-btn" onClick={() => nav('/')} aria-label="close">
          ✕
        </button>
        <Progress value={n / qs.length} />
      </div>

      <div>
        <span className="type">{typeLabel}</span>
        {!legacy && <span className="type lv">{t.lv(q.difficulty_level)}</span>}
        <div className="muted hint-line">{hint}</div>
      </div>
      <div className="q">
        {isFill ? (
          <>
            {before}
            <span className="blank">{(result ? result.answer : sel) ?? ' '}</span>
            {after}
          </>
        ) : (
          q.prompt
        )}
        <button className="speak inline" onClick={() => speak(isFill ? q.prompt.replace('___', '…') : q.prompt, me.target)}>
          🔊
        </button>
      </div>
      <button className="trans" onClick={() => setShowTr(true)}>
        {translationShown ? q.translation : `👁 ${t.showTranslation}`}
      </button>

      <div className={`opts${isFill ? ' words' : ''}`}>
        {q.options.map((o) => (
          <button key={o.text} className={`opt${optClass(o.text)}`} disabled={!!result} onClick={() => setSel(o.text)}>
            {o.text}
            {!isFill && result && o.translation && <small>{o.translation}</small>}
          </button>
        ))}
      </div>

      <div className="bottom">
        {!result && (
          <button className="btn" disabled={sel === null || checking} onClick={check}>
            {t.check}
          </button>
        )}
      </div>

      <div className={`sheet${result ? ' show' : ''}${result?.correct ? ' ok' : ' ko'}`}>
        {result && (
          <div className="in">
            <h3>{result.correct ? `✓ ${t.correct}` : `✕ ${t.correctAnswer}${result.answer}`}</h3>
            <p onClick={() => speak(result.full_sentence, me.target)} className="clickable">
              🔊 {result.full_sentence}
              <br />
              <span className="muted">{result.translation}</span>
            </p>
            <button className={`btn ${result.correct ? 'good' : 'bad'}`} onClick={() => setN(n + 1)}>
              {t.continue}
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
