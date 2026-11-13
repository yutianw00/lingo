# Lingo

A Duolingo-style language learning app ("learn y from x") for Simplified Chinese, English, French and Spanish — every pair of the four (12 combinations).

- **Word swipe** — swipe right if you know the word, left if you don't, tap to see the meaning (in your native language) and an example sentence.
- **Multiple choice** — *fill the blank* (pick the word that completes the sentence) and *what comes next* (pick the natural follow-up sentence).

Backend: Python / FastAPI / SQLite. Frontend: React + Vite + TypeScript. No login yet (see "Auth" below).

## Run it

```bash
# one-time setup
cd backend && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt && cd ..
cd web && npm install && npm run build && cd ..

# run (serves the API and the built web app on http://localhost:8000)
backend/.venv/bin/uvicorn app.main:app --app-dir backend --port 8000
```

For frontend development with hot reload, run the backend as above and `npm run dev` in `web/` (http://localhost:5173, `/api` is proxied to :8000).

Tests: `cd backend && .venv/bin/python -m pytest`

API docs (Swagger) are at http://localhost:8000/docs while the server runs.

## Layout

```
backend/
  app/srs.py      mastery / spaced-repetition model (pure functions)
  app/logic.py    session selection, review recording, undo, stats
  app/main.py     HTTP API (FastAPI), also serves web/dist
  app/seed.py     parses + validates seed/*.txt and upserts it on start-up
  seed/           course content: words_*.txt, questions_*.txt (hand-written, human-editable)
  tests/          pytest: algorithm + API
web/src/
  api.ts          typed API client + text-to-speech helper
  i18n.ts         UI strings in zh / en / fr / es (UI language = native language)
  pages/          Setup, Home, Swipe, Quiz, Words
mockups/          the original static HTML mock-ups
docs/             screenshots
```

## Mastery model

Each (user, item, target language) stores a memory **stability** `S` in days. Predicted recall decays as
`R(t) = 0.85^(t/S)`, so the item is due again exactly `S` days after the last review (when recall drops to 85 %).

Displayed mastery (0–100) = `100 · S/(S+7) · R(now)` — it grows with long-term strength and fades if you stop reviewing.
Levels: new (never seen) · learning (<40) · familiar (40–79) · mastered (≥80, i.e. S ≳ 4 weeks).

| Event | Effect |
|---|---|
| Swipe right, first time, without peeking | S = 7 d → straight to *familiar* |
| Swipe right after peeking at the meaning | S = 1 d (weak evidence) |
| Correct quiz answer, first time | S = 2 d |
| Later success | S ×= 1 + w·(0.6 + 3·(1−R)); w = 0.5 swipe, 0.25 peeked swipe, 1.0 quiz |
| Swipe left / wrong answer | S = 0.2 d (≈5 h) the first time, else S ×= 0.3 |
| Answer < 2 s / > 8 s | evidence weight ×1.2 / ×0.7 |

The `(1−R)` term is the spacing effect: succeeding on something you were about to forget counts for more.
Words and quiz questions have **independent** mastery (a question's mastery is about that question, not its words).

Sessions are ~70 % due reviews (most-forgotten first; for the quiz, previously-missed questions first) and ~30 % new items in curriculum order.

## Content

All content is hand-written in `backend/seed/` — 270 words and 80 questions (40 fill-in, 40 next-sentence), each aligned across all four languages, so any of the 12 pairs works from one file. Formats are documented at the top of each file; the loader validates them (exactly one `[blank]`, 3 distinct distractors, all four languages present…). Content is upserted by stable id on start-up, so editing or adding lines never wipes progress.

Next-sentence distractors are the correct answers of *other* questions whose `topic` differs, so put prompts whose answers could be swapped (e.g. all "what time…?" prompts) under the same topic.

## Auth

None yet. The client sends `X-User-Id` (defaults to `demo`; set `localStorage['lingo.uid']` to switch users).
To add SSO, replace `current_user` in `app/main.py` with a dependency that returns the verified identity; nothing else changes.

## iOS

The web app is mobile-first, and every feature goes through the JSON API, so a SwiftUI client can reuse it as-is:
send `X-User-Id` and `X-Tz-Offset` (minutes, same sign as JS `getTimezoneOffset()`), use `AVSpeechSynthesizer` for pronunciation.
