import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api, type Home as HomeData, type Level } from '../api'
import { useApp } from '../context'
import { Centered, LangBadge, LEVEL_COLOR, TabBar } from '../ui'

const LEVELS: Level[] = ['new', 'learning', 'familiar', 'mastered']

function Distribution({ levels, total }: { levels: Record<Level, number>; total: number }) {
  const { t } = useApp()
  return (
    <>
      <div className="dist">
        {LEVELS.map((l) => (
          <i key={l} style={{ width: `${(levels[l] / Math.max(total, 1)) * 100}%`, background: LEVEL_COLOR[l] }} />
        ))}
      </div>
      <div className="legend">
        {LEVELS.map((l) => (
          <span key={l} style={{ '--c': LEVEL_COLOR[l] } as React.CSSProperties}>
            {t.level[l]} {levels[l]}
          </span>
        ))}
      </div>
    </>
  )
}

export default function Home() {
  const { me, t } = useApp()
  const [data, setData] = useState<HomeData | null>(null)
  const [err, setErr] = useState(false)

  useEffect(() => {
    api.home().then(setData, () => setErr(true))
  }, [me.target, me.native])

  if (err) return <Centered>{t.error}</Centered>
  if (!data) return <Centered>{t.loading}</Centered>

  const { done, goal } = data.today
  const pct = Math.min(100, (done / goal) * 100)

  return (
    <div className="app">
      <div className="topbar">
        <Link className="pair" to="/setup">
          <LangBadge lang={me.native} small />→<LangBadge lang={me.target} small />
          {t.langName[me.target]} ▾
        </Link>
        {data.leveled && <span className="lvbadge">{t.lv(data.level)}</span>}
        <span className="streak" title="streak">
          🔥 {t.streakDays(data.streak)}
        </span>
      </div>

      <div className="panel goal">
        <div className="ring" style={{ background: `conic-gradient(var(--good) 0 ${pct}%, var(--line) ${pct}% 100%)` }}>
          <b>
            {done}/{goal}
          </b>
        </div>
        <div>
          <h3>{t.dailyGoal(goal)}</h3>
          <p className="muted">{done >= goal ? t.goalDone : t.remaining(goal - done)}</p>
        </div>
      </div>

      <h2>{t.practice}</h2>
      <Link className="panel mode" to="/swipe">
        <div className="ico" style={{ background: 'var(--soft)' }}>🃏</div>
        <div className="grow">
          <h3>{t.swipeTitle}</h3>
          <p className="muted">{t.swipeDesc}</p>
          <div className="tags">
            {data.words.due > 0 && <span className="tag warn">{t.due(data.words.due)}</span>}
            <span className="tag good">{t.newCount(data.words.new)}</span>
          </div>
        </div>
      </Link>
      <Link className="panel mode" to="/quiz">
        <div className="ico" style={{ background: 'var(--good-soft)' }}>✅</div>
        <div className="grow">
          <h3>{t.quizTitle}</h3>
          <p className="muted">{t.quizDesc}</p>
          <div className="tags">
            <span className="tag primary">{t.perRound(10)}</span>
            {data.quiz.mistakes > 0 && <span className="tag bad">{t.mistakes(data.quiz.mistakes)}</span>}
            {data.quiz.due > 0 && <span className="tag warn">{t.due(data.quiz.due)}</span>}
          </div>
        </div>
      </Link>

      <h2>
        {t.vocab} <span className="muted thin">{t.total(data.words.total)}</span>
      </h2>
      <div className="panel">
        <Distribution levels={data.words.levels} total={data.words.total} />
      </div>
      <h2>
        {t.quizProgress} <span className="muted thin">{t.total(data.quiz.total)}</span>
      </h2>
      <div className="panel">
        <Distribution levels={data.quiz.levels} total={data.quiz.total} />
      </div>

      <TabBar />
    </div>
  )
}
