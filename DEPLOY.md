# Deploying Lingo (Render)

One Render web service runs everything: the API and the built web app come from the same
Docker image ([Dockerfile](Dockerfile)), and the SQLite database lives on a persistent disk.
The iOS app talks to the same server.

```
push to main ──► GitHub Actions (.github/workflows/ci.yml: tests, web build, docker build)
                      │ checks pass
                      ▼
                 Render deploys the new image ──► https://<your domain>  (web + /api)
```

## What it costs

- Render **Starter** instance (~$7/month) + 1 GB disk (~$0.25/month). The free plan can't
  attach a disk (the database would be wiped on every deploy) and sleeps when idle.
- Optional: your own domain (~$10/year). Recommended before shipping the iOS app, because the
  app has the server address built in.

## First deploy

1. **Render account** — sign in at render.com with GitHub and add a payment method.
2. **Create the service** — Render dashboard → **New → Blueprint** → pick this repository.
   Render reads [render.yaml](render.yaml) and asks for the three secret values:
   - `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` — from your Google OAuth web client.
   - `GOOGLE_REDIRECT_URI` — `https://<service>.onrender.com/api/auth/google/callback`
     (or your own domain, see below). You only learn the `onrender.com` name once the service
     exists: leave Google empty at first if you like (the app then runs without sign-in as the
     shared `demo` user), and fill these in under the service's **Environment** tab afterwards.
3. **Google Cloud Console** → Google Auth Platform → Clients → your web client:
   - add the same URL under **Authorized redirect URIs**;
   - **Audience**: publish the app ("In production"). While it is in *Testing*, only the test
     users listed there can sign in. With only the email/profile scopes no Google review is needed.
4. Open `https://<service>.onrender.com` and sign in.

## Own domain

Render service → **Settings → Custom Domains** → add e.g. `lingo.example.com`, then create
the DNS record Render shows (a CNAME to `<service>.onrender.com`) at your registrar. Render
issues the HTTPS certificate. Then update `GOOGLE_REDIRECT_URI` on Render and the redirect URI
in Google to the new domain.

## Everyday flow

- Push to `main` → CI runs → if it passes, Render builds and deploys (`autoDeployTrigger:
  checksPass`). A failing check means no deploy.
- Content, questions and the mastery model live in the backend, so they reach the iOS app as
  soon as the server is deployed — no app update needed. Changes to the iOS code itself need a
  new app build.
- Keep the API backwards compatible (add fields, don't rename or remove them): older iOS
  builds stay installed on people's phones.

## Data

The database is `/data/lingo.db` on the Render disk (`LINGO_DB`). It survives deploys and
restarts. Only one instance can use the disk, so a deploy has a few seconds of downtime.
To take a copy: Render service → **Shell** →
`python -c "import sqlite3; sqlite3.connect('/data/lingo.db').backup(sqlite3.connect('/data/backup.db'))"`,
or use Render's disk snapshots.

## Test the image locally

```bash
docker build -t lingo .
docker run --rm -p 8000:8000 -v lingo-data:/data lingo   # http://localhost:8000
```
