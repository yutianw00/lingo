import { useCallback, useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api, speak, type Progress as Prog, type WordCard } from '../api'
import { useApp } from '../context'
import { Centered, LEVEL_COLOR, LevelBars, Progress, sleep, Toast, useToast } from '../ui'

const SWIPE_THRESHOLD = 110
const TAP_SLOP = 6

interface CardProps {
  card: WordCard
  revealed: boolean
  leaving: -1 | 0 | 1
  onReveal: () => void
  onSwipe: (dir: -1 | 1) => void
}

/** The draggable top card. Drag state lives in refs and is applied straight to the DOM. */
function TopCard({ card, revealed, leaving, onReveal, onSwipe }: CardProps) {
  const { me, t } = useApp()
  const el = useRef<HTMLDivElement>(null)
  const yes = useRef<HTMLDivElement>(null)
  const no = useRef<HTMLDivElement>(null)
  const drag = useRef<{ x: number; y: number; dx: number; dy: number } | null>(null)

  const setStamps = (dx: number) => {
    if (yes.current) yes.current.style.opacity = String(Math.max(0, dx / 100))
    if (no.current) no.current.style.opacity = String(Math.max(0, -dx / 100))
  }

  const onDown = (e: React.PointerEvent) => {
    if ((e.target as HTMLElement).closest('[data-nodrag]') || leaving) return
    drag.current = { x: e.clientX, y: e.clientY, dx: 0, dy: 0 }
    el.current?.setPointerCapture(e.pointerId)
    el.current?.classList.add('dragging')
  }
  const onMove = (e: React.PointerEvent) => {
    const d = drag.current
    if (!d || !el.current) return
    d.dx = e.clientX - d.x
    d.dy = e.clientY - d.y
    el.current.style.transform = `translate(${d.dx}px, ${d.dy * 0.3}px) rotate(${d.dx / 18}deg)`
    setStamps(d.dx)
  }
  const onUp = () => {
    const d = drag.current
    drag.current = null
    if (!d || !el.current) return
    el.current.classList.remove('dragging')
    if (Math.abs(d.dx) > SWIPE_THRESHOLD) return onSwipe(d.dx > 0 ? 1 : -1)
    el.current.style.transform = ''
    setStamps(0)
    if (Math.abs(d.dx) < TAP_SLOP && Math.abs(d.dy) < TAP_SLOP) onReveal()
  }

  const flyStyle = leaving
    ? { transform: `translate(${leaving * 600}px, -40px) rotate(${leaving * 30}deg)`, transition: 'transform .26s ease-in' }
    : undefined

  return (
    <div
      ref={el}
      className={`card top${revealed ? ' revealed' : ''}`}
      style={flyStyle}
      onPointerDown={onDown}
      onPointerMove={onMove}
      onPointerUp={onUp}
      onPointerCancel={onUp}
    >
      <CardFace card={card} />
      <div ref={yes} className="stamp yes" style={leaving === 1 ? { opacity: 1 } : undefined}>
        {t.known}
      </div>
      <div ref={no} className="stamp no" style={leaving === -1 ? { opacity: 1 } : undefined}>
        {t.unknown}
      </div>
      <button className="speak" data-nodrag onClick={() => speak(card.word, me.target)} aria-label="speak">
        🔊
      </button>
      <div className="back">
        <div className="m">{card.meaning}</div>
        <div className="ex" data-nodrag onClick={() => speak(card.example, me.target)}>
          <p>{card.example}</p>
          <p>{card.example_translation}</p>
        </div>
      </div>
      <div className="hint">{t.tapToReveal}</div>
    </div>
  )
}

function CardFace({ card }: { card: WordCard }) {
  const { t } = useApp()
  return (
    <>
      <div className="meta">
        <LevelBars level={card.level} />
        <span style={{ color: LEVEL_COLOR[card.level] }}>
          {t.level[card.level]}
          {card.level !== 'new' && ` · ${card.mastery}`}
        </span>
      </div>
      <div className="word">{card.word}</div>
      <div className="pos">
        {t.pos[card.pos] ?? card.pos}
        {card.gender && <span className={`gender g-${card.gender}`}>{t.gender[card.gender]}</span>}
        {card.topic && <span className="lvtag">{t.lv(card.difficulty_level)}</span>}
      </div>
    </>
  )
}

export default function Swipe() {
  const { t } = useApp()
  const nav = useNavigate()
  const [cards, setCards] = useState<WordCard[] | null>(null)
  const [err, setErr] = useState(false)
  const [i, setI] = useState(0)
  const [revealed, setRevealed] = useState(false)
  const [leaving, setLeaving] = useState<-1 | 0 | 1>(0)
  const [history, setHistory] = useState<{ idx: number; known: boolean }[]>([])
  const [toast, showToast] = useToast()
  const shownAt = useRef(performance.now())
  const busy = useRef(false)

  const load = useCallback(() => {
    setCards(null)
    setErr(false)
    api.wordSession(20).then(
      (c) => {
        setCards(c)
        setI(0)
        setHistory([])
      },
      () => setErr(true),
    )
  }, [])
  useEffect(load, [load])

  useEffect(() => {
    shownAt.current = performance.now()
    setRevealed(false)
  }, [i, cards])

  const patch = (idx: number, p: Prog) =>
    setCards((cs) => cs && cs.map((c, k) => (k === idx ? { ...c, ...p } : c)))

  const fly = useCallback(
    async (dir: -1 | 1) => {
      if (!cards || i >= cards.length || busy.current) return
      busy.current = true
      const card = cards[i]
      const known = dir > 0
      setLeaving(dir)
      try {
        const [res] = await Promise.all([
          api.reviewWord(card.id, { known, peeked: revealed, elapsed_ms: Math.round(performance.now() - shownAt.current) }),
          sleep(260),
        ])
        patch(i, res.after)
        setHistory((h) => [...h, { idx: i, known }])
        setI(i + 1)
        showToast(`${card.word}  ${res.before.mastery} → ${res.after.mastery}`)
      } catch {
        showToast(t.error)
      } finally {
        setLeaving(0)
        busy.current = false
      }
    },
    [cards, i, revealed, showToast, t.error],
  )

  const undo = useCallback(async () => {
    if (!cards || busy.current || history.length === 0) return
    busy.current = true
    const last = history[history.length - 1]
    try {
      patch(last.idx, await api.undoWord(cards[last.idx].id))
      setHistory((h) => h.slice(0, -1))
      setI(last.idx)
      showToast(t.undone)
    } catch {
      showToast(t.error)
    } finally {
      busy.current = false
    }
  }, [cards, history, showToast, t])

  // Keyboard: ← / → to swipe, space to reveal, backspace to undo.
  const keys = useRef({ fly, undo })
  keys.current = { fly, undo }
  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      if (e.key === 'ArrowLeft') keys.current.fly(-1)
      else if (e.key === 'ArrowRight') keys.current.fly(1)
      else if (e.key === ' ') {
        e.preventDefault()
        setRevealed(true)
      } else if (e.key === 'Backspace') keys.current.undo()
    }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [])

  if (err)
    return (
      <Centered>
        <p>{t.error}</p>
        <button className="btn" onClick={load}>
          {t.retry}
        </button>
      </Centered>
    )
  if (!cards) return <Centered>{t.loading}</Centered>

  const finished = i >= cards.length
  const knownCount = history.filter((h) => h.known).length

  return (
    <div className="app">
      <div className="topbar">
        <button className="icon-btn" onClick={() => nav('/')} aria-label="close">
          ✕
        </button>
        <Progress value={i / Math.max(cards.length, 1)} />
        <span className="muted bold">
          {Math.min(i + 1, cards.length)}/{cards.length}
        </span>
      </div>

      <div className="stack">
        {finished ? (
          <div className="card summary">
            <div className="big">🎉</div>
            <h1>{t.roundDone}</h1>
            <p className="muted">{t.roundHint}</p>
            <div className="stats">
              <div className="good">
                {knownCount}
                <small>{t.known}</small>
              </div>
              <div className="bad">
                {history.length - knownCount}
                <small>{t.unknown}</small>
              </div>
            </div>
            <button className="btn" onClick={() => nav('/quiz')}>
              {t.goQuiz}
            </button>
            <button className="btn ghost" onClick={load}>
              {t.again}
            </button>
          </div>
        ) : (
          cards
            .slice(i, i + 3)
            .map((card, k) =>
              k === 0 ? (
                <TopCard
                  key={card.id}
                  card={card}
                  revealed={revealed}
                  leaving={leaving}
                  onReveal={() => setRevealed((r) => !r)}
                  onSwipe={fly}
                />
              ) : (
                <div
                  key={card.id}
                  className="card behind"
                  style={{ transform: `translateY(${k * 12}px) scale(${1 - k * 0.04})`, zIndex: 10 - k }}
                >
                  <CardFace card={card} />
                </div>
              ),
            )
            .reverse()
        )}
      </div>

      {!finished && (
        <div className="actions-wrap">
          <div className="actions">
            <button className="round no" onClick={() => fly(-1)} aria-label={t.unknown}>
              ✕
            </button>
            <button className="round sm" onClick={undo} disabled={history.length === 0} aria-label={t.undo}>
              ↶
            </button>
            <button className="round yes" onClick={() => fly(1)} aria-label={t.known}>
              ✓
            </button>
          </div>
          <div className="labels">
            <span>{t.unknown}</span>
            <span>{t.undo}</span>
            <span>{t.known}</span>
          </div>
        </div>
      )}
      <Toast msg={toast} />
    </div>
  )
}
