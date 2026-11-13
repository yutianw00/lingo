import { useEffect, useMemo, useState } from 'react'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { api, type Me } from './api'
import { Ctx } from './context'
import { STRINGS } from './i18n'
import Home from './pages/Home'
import Quiz from './pages/Quiz'
import Setup from './pages/Setup'
import Swipe from './pages/Swipe'
import Words from './pages/Words'
import { Centered } from './ui'

export default function App() {
  const [me, setMe] = useState<Me | null>(null)
  const [err, setErr] = useState(false)

  useEffect(() => {
    api.me().then(setMe, () => setErr(true))
  }, [])

  useEffect(() => {
    if (me) document.documentElement.lang = me.native === 'zh' ? 'zh-CN' : me.native
  }, [me])

  const ctx = useMemo(() => (me ? { me, setMe, t: STRINGS[me.native] } : null), [me])

  if (err)
    return (
      <Centered>
        <p>{STRINGS.zh.error}</p>
        <p className="muted">{STRINGS.en.error}</p>
      </Centered>
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
