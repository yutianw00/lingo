"""Google sign-in (OpenID Connect authorization-code flow with PKCE) and sessions.

Flow:
  1. GET /api/auth/google/login  → we store {state, PKCE verifier, next} server-side,
     put `state` in a short-lived cookie and redirect to Google.
  2. GET /api/auth/google/callback?code&state → state must match the cookie and the
     stored row; we exchange the code (with the client secret and PKCE verifier)
     directly with Google's token endpoint and read the ID token.
  3. We find/create the user, create a session and set an HttpOnly cookie.

The ID token comes straight from Google's token endpoint over TLS, authenticated
with our client secret, so per OpenID Connect Core §3.1.3.7 TLS validation stands
in for checking its signature; we still validate issuer, audience, expiry and
email verification. (A client sending us a Google token it got itself would need
signature verification; the iOS app avoids that by going through this same flow.)

Native apps (iOS) run the same flow in a system browser sheet: they pass the PKCE
challenge of a verifier only they know (`app_challenge`), the callback redirects to
`lingo://auth?code=…` with a one-time code instead of setting a cookie, and the app
redeems code + verifier at POST /api/auth/app/token for a session token. A code that
leaks through the URL scheme is useless without the verifier.

Sessions are random 256-bit tokens; only their SHA-256 is stored. Web clients get
them as a cookie, other clients can send `Authorization: Bearer <token>`.
"""
from __future__ import annotations

import base64
import hashlib
import json
import re
import secrets
import sqlite3
from typing import Callable
from urllib.parse import urlencode

import httpx

from .config import AuthConfig

GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
GOOGLE_ISSUERS = {"accounts.google.com", "https://accounts.google.com"}
SESSION_COOKIE = "lingo_session"
STATE_COOKIE = "lingo_oauth_state"
STATE_TTL = 600  # seconds the user has to finish signing in at Google
APP_REDIRECT = "lingo://auth"  # where native-app logins end (the iOS app's callback scheme)
APP_CODE_TTL = 120  # seconds the app has to redeem its one-time code
_CHALLENGE = re.compile(r"[A-Za-z0-9_-]{43}")  # base64url SHA-256, no padding


class AuthError(Exception):
    pass


# ------------------------------------------------------------------ tokens

def new_token() -> str:
    return secrets.token_urlsafe(32)


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def pkce_challenge(verifier: str) -> str:
    return base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()


def pkce_pair() -> tuple[str, str]:
    verifier = secrets.token_urlsafe(48)
    return verifier, pkce_challenge(verifier)


def valid_challenge(challenge: str) -> bool:
    return bool(_CHALLENGE.fullmatch(challenge))


def safe_next(path: str | None) -> str:
    """Only same-site relative paths, so the login can't be used as an open redirect."""
    if not path or not path.startswith("/") or path.startswith("//") or "\\" in path:
        return "/"
    return path


# ------------------------------------------------------------------ Google

def authorization_url(cfg: AuthConfig, state: str, challenge: str) -> str:
    return GOOGLE_AUTH_URL + "?" + urlencode({
        "client_id": cfg.google_client_id,
        "redirect_uri": cfg.redirect_uri,
        "response_type": "code",
        "scope": "openid email profile",
        "state": state,
        "code_challenge": challenge,
        "code_challenge_method": "S256",
        "prompt": "select_account",
    })


def exchange_code(cfg: AuthConfig, code: str, verifier: str) -> dict:
    """POST the authorization code to Google; returns the token response (with `id_token`)."""
    resp = httpx.post(GOOGLE_TOKEN_URL, data={
        "client_id": cfg.google_client_id,
        "client_secret": cfg.google_client_secret,
        "code": code,
        "code_verifier": verifier,
        "redirect_uri": cfg.redirect_uri,
        "grant_type": "authorization_code",
    }, timeout=10)
    if resp.status_code != 200:
        raise AuthError(f"token exchange failed ({resp.status_code})")
    return resp.json()


def id_token_claims(id_token: str, cfg: AuthConfig, now: float) -> dict:
    try:
        payload = id_token.split(".")[1]
        claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
    except (IndexError, ValueError):
        raise AuthError("malformed ID token") from None
    if claims.get("iss") not in GOOGLE_ISSUERS:
        raise AuthError("wrong issuer")
    if claims.get("aud") != cfg.google_client_id:
        raise AuthError("token was issued for another client")
    if float(claims.get("exp", 0)) < now:
        raise AuthError("expired ID token")
    if not claims.get("sub"):
        raise AuthError("ID token has no subject")
    if claims.get("email") and claims.get("email_verified") is False:
        raise AuthError("email not verified")
    return claims


# ------------------------------------------------------------------ storage

def start_login(conn: sqlite3.Connection, next_path: str, claim: str | None, now: float,
                app_challenge: str | None = None) -> tuple[str, str]:
    """Remember a pending login; returns (state, PKCE challenge)."""
    state = new_token()
    verifier, challenge = pkce_pair()
    conn.execute("DELETE FROM oauth_states WHERE created_at < ?", (now - STATE_TTL,))
    conn.execute(
        "INSERT INTO oauth_states (state, verifier, next, claim, app_challenge, created_at) VALUES (?, ?, ?, ?, ?, ?)",
        (state, verifier, safe_next(next_path), claim, app_challenge, now),
    )
    conn.commit()
    return state, challenge


def take_login(conn: sqlite3.Connection, state: str, now: float) -> sqlite3.Row:
    """Fetch and consume a pending login (single use)."""
    row = conn.execute("SELECT * FROM oauth_states WHERE state=?", (state,)).fetchone()
    conn.execute("DELETE FROM oauth_states WHERE state=?", (state,))
    conn.commit()
    if row is None or row["created_at"] < now - STATE_TTL:
        raise AuthError("login expired, please try again")
    return row


def is_app_login(conn: sqlite3.Connection, state: str | None) -> bool:
    """Whether this browser's pending login (by its state cookie) was started by the native app."""
    if not state:
        return False
    row = conn.execute("SELECT app_challenge FROM oauth_states WHERE state=?", (state,)).fetchone()
    return bool(row and row["app_challenge"])


def create_app_code(conn: sqlite3.Connection, user_id: str, challenge: str, now: float) -> str:
    code = new_token()
    conn.execute("DELETE FROM app_codes WHERE created_at < ?", (now - APP_CODE_TTL,))
    conn.execute("INSERT INTO app_codes (code_hash, user_id, challenge, created_at) VALUES (?, ?, ?, ?)",
                 (token_hash(code), user_id, challenge, now))
    conn.commit()
    return code


def redeem_app_code(conn: sqlite3.Connection, code: str, verifier: str, now: float) -> str:
    """Consume a one-time app code (single use, even on a wrong verifier); returns the user id."""
    h = token_hash(code)
    row = conn.execute("SELECT * FROM app_codes WHERE code_hash=?", (h,)).fetchone()
    conn.execute("DELETE FROM app_codes WHERE code_hash=?", (h,))
    conn.commit()
    if row is None or row["created_at"] < now - APP_CODE_TTL:
        raise AuthError("code expired, please sign in again")
    if not secrets.compare_digest(pkce_challenge(verifier), row["challenge"]):
        raise AuthError("verifier does not match")
    return row["user_id"]


def upsert_google_user(conn: sqlite3.Connection, claims: dict, claim_id: str | None, now: float) -> str:
    """Return the user id for this Google account, creating it on first login.

    On the very first login, an anonymous user from before sign-in existed (the
    single-user `demo` profile, or whatever id the browser used) is adopted, so its
    progress carries over. Only users never linked to a Google account can be adopted.
    """
    sub = claims["sub"]
    profile = (claims.get("email"), claims.get("name"), claims.get("picture"))
    row = conn.execute("SELECT id FROM users WHERE google_sub=?", (sub,)).fetchone()
    if row:
        uid = row["id"]
    else:
        adopt = None
        if claim_id:
            adopt = conn.execute(
                "SELECT id FROM users WHERE id=? AND google_sub IS NULL", (claim_id,)
            ).fetchone()
        if adopt:
            uid = adopt["id"]
            conn.execute("UPDATE users SET google_sub=? WHERE id=?", (sub, uid))
        else:
            uid = "g-" + new_token()[:16]
            conn.execute("INSERT INTO users (id, google_sub, created_at) VALUES (?, ?, ?)", (uid, sub, now))
    conn.execute("UPDATE users SET email=?, name=?, picture=? WHERE id=?", (*profile, uid))
    conn.commit()
    return uid


def create_session(conn: sqlite3.Connection, user_id: str, now: float, days: int) -> str:
    token = new_token()
    conn.execute(
        "INSERT INTO sessions (token_hash, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)",
        (token_hash(token), user_id, now, now + days * 86400),
    )
    conn.execute("DELETE FROM sessions WHERE expires_at < ?", (now,))
    conn.commit()
    return token


def session_user(conn: sqlite3.Connection, token: str, now: float) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash=? AND s.expires_at > ?",
        (token_hash(token), now),
    ).fetchone()


def end_session(conn: sqlite3.Connection, token: str) -> None:
    conn.execute("DELETE FROM sessions WHERE token_hash=?", (token_hash(token),))
    conn.commit()


Exchange = Callable[[AuthConfig, str, str], dict]
