import { useSearchParams } from 'react-router-dom'
import { signInWithGoogle } from '../api'
import { browserLang, STRINGS } from '../i18n'

/** Shown to signed-out visitors. The UI language follows the browser until we know the user. */
export default function Login() {
  const [params] = useSearchParams()
  const t = STRINGS[browserLang()]
  const error = params.get('error') as keyof typeof t.signInError | null
  const next = params.get('next') || '/'

  return (
    <div className="app login">
      <div className="login-hero">
        <div className="login-logo">🃏</div>
        <h1>Lingo</h1>
        <p className="muted">{t.signInSubtitle}</p>
      </div>
      {error && <p className="err">{t.signInError[error] ?? t.signInError.failed}</p>}
      <div className="bottom">
        <button className="btn google" onClick={() => signInWithGoogle(next)}>
          <svg viewBox="0 0 48 48" width="20" height="20" aria-hidden="true">
            <path fill="#EA4335" d="M24 9.5c3.5 0 6.6 1.2 9 3.6l6.7-6.7C35.6 2.4 30.2 0 24 0 14.6 0 6.6 5.4 2.6 13.3l7.8 6C12.3 13.5 17.7 9.5 24 9.5z" />
            <path fill="#4285F4" d="M46.1 24.5c0-1.6-.1-3.1-.4-4.5H24v9h12.4c-.5 2.9-2.2 5.3-4.6 6.9l7.4 5.8c4.3-4 6.9-9.9 6.9-17.2z" />
            <path fill="#FBBC05" d="M10.4 28.7c-.5-1.4-.8-3-.8-4.7s.3-3.2.8-4.7l-7.8-6C.9 16.6 0 20.2 0 24s.9 7.4 2.6 10.7l7.8-6z" />
            <path fill="#34A853" d="M24 48c6.5 0 11.9-2.1 15.9-5.8l-7.4-5.8c-2.1 1.4-4.8 2.3-8.5 2.3-6.3 0-11.7-4-13.6-9.6l-7.8 6C6.6 42.6 14.6 48 24 48z" />
          </svg>
          {t.signInGoogle}
        </button>
      </div>
    </div>
  )
}
