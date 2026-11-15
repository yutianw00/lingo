# One image serves both the API and the built web app (FastAPI mounts web/dist).

# ---- build the web app
FROM node:24-slim AS web
WORKDIR /web
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
RUN npm run build

# ---- run the backend
FROM python:3.14-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY backend/requirements.txt backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt
COPY backend/ backend/
COPY --from=web /web/dist web/dist

# The SQLite database must live on a persistent disk in production (LINGO_DB=/data/lingo.db
# on Render); this default only applies when running the image locally without one.
ENV LINGO_DB=/data/lingo.db
RUN mkdir -p /data

# Render (and most hosts) pass the port in $PORT and terminate TLS in front of the app,
# so trust its X-Forwarded-* headers. One worker: SQLite has a single writer anyway.
CMD ["sh", "-c", "exec uvicorn app.main:app --app-dir backend --host 0.0.0.0 --port ${PORT:-8000} --proxy-headers --forwarded-allow-ips='*'"]
