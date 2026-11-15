# Lingo for iOS

Native SwiftUI client for the Lingo backend: sign-in, language setup, home, word swipe,
multiple choice and the word list, with the same mastery model, content and progress as the web app
(it talks to the same API, so progress is shared).

## Run it

1. Start the backend on your Mac (from the repo root):
   ```bash
   backend/.venv/bin/uvicorn app.main:app --app-dir backend --host 0.0.0.0 --port 8000
   ```
2. Open `iOS/Lingo.xcodeproj` in Xcode, pick an iPhone simulator and press **Run** (⌘R).

The app talks to `http://localhost:8000` by default, which from the simulator is your Mac.

**Sign-in.** With Google configured in `backend/.env` the app shows "Sign in with Google": the
backend runs the same Google flow in a system browser sheet and hands the app a one-time code via
`lingo://auth`, which the app redeems (with its PKCE verifier) for a session token kept in the
Keychain. No changes are needed in the Google console — the redirect is still the backend's
`/api/auth/google/callback`. Without Google configured the app runs as the local `demo` user.

## On a real iPhone

- Xcode → target **Lingo** → *Signing & Capabilities*: choose your Team (a free Apple ID works);
  change the bundle id `app.lingo.ios` if Xcode says it is taken.
- The phone can't reach `localhost`: on the sign-in screen tap **Server** and enter your Mac's LAN
  address, e.g. `http://192.168.1.20:8000` (backend started with `--host 0.0.0.0`).
- Google sign-in on a phone also needs the backend reachable at the address in
  `GOOGLE_REDIRECT_URI` (Google only allows `localhost` or https redirects), e.g. via an https
  tunnel added as an authorized redirect URI. Without sign-in configured, the LAN address is enough.

## Layout

```
Lingo/
  LingoApp.swift, AppModel.swift   app entry, signed-in state
  API.swift, Models.swift          typed client for /api (Bearer token, X-Tz-Offset)
  Auth.swift                       Google sign-in (ASWebAuthenticationSession + PKCE), Keychain
  Strings.swift, Theme.swift       UI strings (zh/en/fr/es) and colors, ported from web/src
  Speech.swift                     pronunciation (AVSpeechSynthesizer)
  Views/                           Login, Setup, Home, Swipe, Quiz, Words
```

New files dropped into `Lingo/` are picked up by Xcode automatically (synchronized folder).

Debug launch arguments (Product → Scheme → Edit Scheme → Arguments): `-serverURL http://…`
overrides the server, `-screen swipe|quiz|words|setup` opens a screen directly.
