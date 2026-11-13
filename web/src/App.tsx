import { useEffect, useMemo, useState } from 'react'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { api, SignInRequired, type Me } from './api'
import { Ctx } from './context'
import { browserLang, STRINGS } from './i18n'
import Home from './pages/Home'
import Login from './pages/Login'
import Quiz from './pages/Quiz'
import Setup from './pages/Setup'
import Swipe from './pages/Swipe'
import Words from './pages/Words'
import { Centered } from './ui'

type State = { kind: 'loading' } | { kind: 'error' } | { kind: 'signed-out' } | { kind: 'ready'; me: Me }

export default function App() {
  const [state, setState] = useState<State>({ kind: 'loading' })

  useEffect(() => {
    api.me().then(
      (me) => setState({ kind: 'ready', me }),
      (e) => setState({ kind: e instanceof SignInRequired ? 'signed-out' : 'error' }),
    )
  }, [])

  const me = state.kind === 'ready' ? state.me : null
  useEffect(() => {
    const lang = me?.native ?? browserLang()
    document.documentElement.lang = lang === 'zh' ? 'zh-CN' : lang
  }, [me])

  const ctx = useMemo(
    () => (me ? { me, setMe: (m: Me) => setState({ kind: 'ready', me: m }), t: STRINGS[me.native] } : null),
    [me],
  )

  if (state.kind === 'error')
    return (
      <Centered>
        <p>{STRINGS.zh.error}</p>
        <p className="muted">{STRINGS.en.error}</p>
      </Centered>
    )
  if (state.kind === 'signed-out')
    return (
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="*" element={<LoginRedirect />} />
        </Routes>
      </BrowserRouter>
    )
  if (!ctx) return <Centered>…</Centered>

  const gate = (el: React.ReactElement) => (ctx.me.onboarded ? el : <Navigate to="/setup" replace />)

  return (
    <Ctx.Provider value={ctx}>
      <BrowserRouter>
        <Routes>
          <Route path="/setup" element={<Setup />} />
          <Route path="/" element={gate(<Home />)} />
          <Route path="/swipe" element={gate(<Swipe />)} />
          <Route path="/quiz" element={gate(<Quiz />)} />
          <Route path="/words" element={gate(<Words />)} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </Ctx.Provider>
  )
}

/** Remember where the user was headed, then show the sign-in page. */
function LoginRedirect() {
  const next = window.location.pathname
  return <Navigate to={`/login?next=${encodeURIComponent(next)}`} replace />
}
