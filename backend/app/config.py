"""Runtime configuration from the environment, with `backend/.env` as a fallback.

`.env` is git-ignored and holds secrets (Google OAuth client). Real environment
variables always win over the file.
"""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

ENV_FILE = Path(__file__).resolve().parent.parent / ".env"


def load_env_file(path: Path = ENV_FILE) -> None:
    if not path.is_file():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        value = value.strip().strip('"').strip("'")
        if value:
            os.environ.setdefault(key.strip(), value)


@dataclass(frozen=True)
class AuthConfig:
    google_client_id: str
    google_client_secret: str
    redirect_uri: str  # must match an "Authorized redirect URI" of the Google client exactly
    frontend_url: str = ""  # where to send the browser after login ("" = same origin)
    cookie_secure: bool = False  # True when served over https
    session_days: int = 30


def auth_from_env() -> AuthConfig | None:
    """None (= login disabled, single local user) unless a Google client is configured."""
    load_env_file()
    cid = os.environ.get("GOOGLE_CLIENT_ID", "").strip()
    secret = os.environ.get("GOOGLE_CLIENT_SECRET", "").strip()
    if not cid or not secret:
        return None
    redirect = os.environ.get("GOOGLE_REDIRECT_URI", "http://localhost:8000/api/auth/google/callback").strip()
    return AuthConfig(
        google_client_id=cid,
        google_client_secret=secret,
        redirect_uri=redirect,
        frontend_url=os.environ.get("FRONTEND_URL", "").strip().rstrip("/"),
        cookie_secure=redirect.startswith("https://"),
    )
