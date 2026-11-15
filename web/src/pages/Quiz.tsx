import { useCallback, useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api, speak, type AnswerResult, type Question, type QuestionWords, type WordToken } from '../api'
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
  const [words, setWords] = useState<QuestionWords | null>(null)
  const [picked, setPicked] = useState<number | null>(null) // index into words.tokens
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
    setWords(null)
    setPicked(null)
    startedAt.current = performance.now()
    const id = qs?.[n]?.id
    if (!id) return
    let live = true
    // Words become tappable once their translations arrive (usually prefetched by the server).
    api.questionWords(id).then(
      (w) => live && setWords(w),
      () => {},
    )
    return () => {
      live = false
    }
  }, [n, qs])

  const addWord = async (tok: WordToken) => {
    const word = tok.lemma || tok.text
    const meaning = tok.lemma_meaning || tok.meaning
    if (!meaning || !qs) return
    try {
      await api.addWord({ word, meaning, pos: tok.pos ?? '', question_id: qs[n].id })
      const key = word.toLowerCase()
      setWords((w) =>
        w && { ...w, tokens: w.tokens.map((x) => ((x.lemma || x.text).toLowerCase() === key ? { ...x, added: true } : x)) },
      )
    } catch {
      /* keep the card open; the user can retry */
    }
  }

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
  const blank = <span className={`blank${result ? ' done' : ''}`}>{(result ? result.answer : sel) ?? ' '}</span>
  const tok = picked !== null ? words?.tokens[picked] : undefined

  // Plain text with the fill-in blank put back where "___" is.
  const withBlank = (text: string, key: number) =>
    text.split('___').map((part, i) => (
      <span key={`${key}-${i}`}>
        {i > 0 && blank}
        {part}
      </span>
    ))

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
        {words && words.text === q.prompt ? (
          words.tokens.map((w, i) =>
            w.word ? (
              <button key={i} className={`tok${picked === i ? ' on' : ''}`} onClick={() => setPicked(picked === i ? null : i)}>
                {w.text}
              </button>
            ) : (
              withBlank(w.text, i)
            ),
          )
        ) : isFill ? (
          <>
            {before}
            {blank}
            {after}
          </>
        ) : (
          q.prompt
        )}
        <button className="speak inline" onClick={() => speak(isFill ? q.prompt.replace('___', '…') : q.prompt, me.target)}>
          🔊
        </button>
      </div>
      {tok ? (
        <div className="gloss">
          <button className="x" onClick={() => setPicked(null)} aria-label="close">
            ✕
          </button>
          <div className="gw" onClick={() => speak(tok.lemma || tok.text, me.target)}>
            🔊 {tok.text}
            {tok.lemma && tok.lemma.toLowerCase() !== tok.text.toLowerCase() && <span className="muted"> → {tok.lemma}</span>}
            {tok.pos && <span className="lvtag">{t.pos[tok.pos] ?? tok.pos}</span>}
          </div>
          {tok.meaning ? (
            <div className="gm">
              {tok.meaning}
              {tok.lemma_meaning && tok.lemma_meaning !== tok.meaning && (
                <div className="muted">
                  {tok.lemma}: {tok.lemma_meaning}
                </div>
              )}
            </div>
          ) : (
            <div className="muted">{t.noGloss}</div>
          )}
          {tok.meaning && (
            <button className="chip add" disabled={tok.added} onClick={() => addWord(tok)}>
              {tok.added ? t.wordAdded : `＋ ${t.addWord}`}
            </button>
          )}
        </div>
      ) : (
        <button className="trans" onClick={() => setShowTr(true)}>
          {translationShown ? q.translation : `👁 ${t.showTranslation}`}
          {words && <span className="tap-hint"> · {t.tapWordHint}</span>}
        </button>
      )}

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
            {result.explanation && <p className="why">💡 {result.explanation}</p>}
            {!result.correct && result.choice_explanation && (
              <p className="why">
                <b>
                  {t.yourChoice} “{sel}”:
                </b>{' '}
                {result.choice_explanation}
              </p>
            )}
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
