# Lingo for iOS

Native SwiftUI client for the Lingo backend: sign-in, language setup, home, word swipe,
multiple choice and the word list, with the same mastery model, content and progress as the web app
(it talks to the same API, so progress is shared).

## Run it

Open `iOS/Lingo.xcodeproj` in Xcode, pick an iPhone simulator (or your phone) and press **Run** (⌘R).

The app talks to the deployed backend, `https://lingo-tiw0.onrender.com`, by default.

**Against a local backend.** Start it on your Mac (from the repo root):
```bash
backend/.venv/bin/uvicorn app.main:app --app-dir backend --host 0.0.0.0 --port 8000
```
then in Xcode: Product → Scheme → Edit Scheme… → Run → Arguments, tick **`-local`** (already in the
list, off by default). The app then uses `http://localhost:8000`, which from the simulator is your Mac.
From the command line: `xcrun simctl launch booted com.yutianw.lingo -local`.

**Sign-in.** With Google configured in `backend/.env` the app shows "Sign in with Google": the
backend runs the same Google flow in a system browser sheet and hands the app a one-time code via
`lingo://auth`, which the app redeems (with its PKCE verifier) for a session token kept in the
Keychain. No changes are needed in the Google console — the redirect is still the backend's
`/api/auth/google/callback`. Without Google configured the app runs as the local `demo` user.

## On a real iPhone

- Xcode → target **Lingo** → *Signing & Capabilities*: choose your Team (a free Apple ID works);
  change the bundle id `com.yutianw.lingo` if Xcode says it is taken (it must be unique per Apple account).
- With the default (deployed) backend nothing else is needed, Google sign-in included.
- To use the backend on your Mac instead, `-local` won't help (`localhost` is the phone itself):
  on the sign-in screen tap **Server** and enter your Mac's LAN address, e.g.
  `http://192.168.1.20:8000` (backend started with `--host 0.0.0.0`). Google sign-in then also
  needs the backend reachable at the address in `GOOGLE_REDIRECT_URI` (Google only allows
  `localhost` or https redirects); without sign-in configured, the LAN address is enough.
- A free Apple ID signs the app for 7 days; after that, connect the phone and Run again.

## Layout

```
Lingo/
  LingoApp.swift, AppModel.swift   app entry, signed-in state
  API.swift, Models.swift          typed client for /api (Bearer token, X-Tz-Offset)
  PreviewData.swift                canned API responses for #Preview / -previewData (Debug only)
  Auth.swift                       Google sign-in (ASWebAuthenticationSession + PKCE), Keychain
  Strings.swift, Theme.swift       UI strings (zh/en/fr/es) and colors, ported from web/src
  Speech.swift                     pronunciation (AVSpeechSynthesizer)
  Views/                           Login, Setup, Home, Swipe, Quiz, Words
```

New files dropped into `Lingo/` are picked up by Xcode automatically (synchronized folder).

Debug launch arguments (Product → Scheme → Edit Scheme → Arguments): `-local` uses
`http://localhost:8000`, `-serverURL http://…` any other server (both override the address saved
in the app), `-screen swipe|quiz|words|setup` opens a screen directly.
`-previewData` runs the whole app offline on canned data (no server, no sign-in).

## SwiftUI previews

Every screen has `#Preview`s (Editor → Canvas, ⌥⌘↩). They run on the canned responses in
`Lingo/PreviewData.swift` (Spanish course, Chinese UI), so they need no server or sign-in and stay
interactive: you can answer questions, swipe cards and add words. The data was captured from a
local backend; regenerate it if the API shape changes. Previews and `PreviewData` are `#if DEBUG`
only and are not part of release builds.
