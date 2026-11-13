"""Google sign-in flow, with Google's token endpoint replaced by a fake."""
import base64
import json
import random
from urllib.parse import parse_qs, urlparse

import pytest
from fastapi.testclient import TestClient

from app import auth
from app.config import AuthConfig, load_env_file
from app.main import create_app

NOW = 1_700_000_000.0
CFG = AuthConfig(google_client_id="cid.apps.googleusercontent.com", google_client_secret="s3cret",
                 redirect_uri="http://testserver/api/auth/google/callback")


def fake_id_token(**claims) -> str:
    base = {"iss": "https://accounts.google.com", "aud": CFG.google_client_id, "exp": NOW + 3600,
            "sub": "111", "email": "learner@example.com", "email_verified": True, "name": "Learner"}
    base.update(claims)
    enc = lambda d: base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b"=").decode()
    return f"{enc({'alg': 'RS256'})}.{enc(base)}.sig"


class FakeGoogle:
    def __init__(self):
        self.claims = {}
        self.calls = []

    def __call__(self, cfg, code, verifier):
        self.calls.append((code, verifier))
        return {"id_token": fake_id_token(**self.claims)}


@pytest.fixture
def google():
    return FakeGoogle()


@pytest.fixture
def client(tmp_path, google):
    app = create_app(str(tmp_path / "auth.db"), clock=lambda: NOW, rng=random.Random(0),
                     auth_cfg=CFG, exchange=google)
    return TestClient(app, follow_redirects=False)


def sign_in(client, next_path="/", claim=None):
    params = {"next": next_path}
    if claim:
        params["claim"] = claim
    r = client.get("/api/auth/google/login", params=params)
    assert r.status_code == 302
    state = parse_qs(urlparse(r.headers["location"]).query)["state"][0]
    return client.get("/api/auth/google/callback", params={"code": "the-code", "state": state})


def test_api_requires_sign_in(client):
    assert client.get("/api/auth/config").json() == {"enabled": True, "providers": ["google"]}
    assert client.get("/api/me").status_code == 401
    assert client.get("/api/me", headers={"X-User-Id": "demo"}).status_code == 401  # header no longer trusted


def test_login_redirects_to_google_with_pkce(client):
    r = client.get("/api/auth/google/login", params={"next": "/swipe"})
    url = urlparse(r.headers["location"])
    q = parse_qs(url.query)
    assert url.netloc == "accounts.google.com"
    assert q["client_id"] == [CFG.google_client_id] and q["redirect_uri"] == [CFG.redirect_uri]
    assert q["scope"] == ["openid email profile"] and q["code_challenge_method"] == ["S256"]
    assert r.cookies.get(auth.STATE_COOKIE) == q["state"][0]


def test_full_sign_in_and_logout(client, google):
    r = sign_in(client, "/swipe")
    assert r.status_code == 302 and r.headers["location"] == "/swipe"
    code, verifier = google.calls[0]
    assert code == "the-code" and len(verifier) >= 43
    me = client.get("/api/me").json()
    assert me["email"] == "learner@example.com" and me["name"] == "Learner"
    # signing in again is the same account
    first_id = me["id"]
    sign_in(client)
    assert client.get("/api/me").json()["id"] == first_id
    assert client.post("/api/auth/logout").json() == {"ok": True}
    assert client.get("/api/me").status_code == 401


def test_bearer_token_for_non_browser_clients(client, tmp_path):
    sign_in(client)
    token = client.cookies.get(auth.SESSION_COOKIE)
    other = TestClient(client.app)
    assert other.get("/api/me", headers={"Authorization": f"Bearer {token}"}).status_code == 200
    assert other.get("/api/me", headers={"Authorization": "Bearer nope"}).status_code == 401


def test_state_must_match_cookie(client):
    r = client.get("/api/auth/google/login")
    state = parse_qs(urlparse(r.headers["location"]).query)["state"][0]
    client.cookies.clear()
    r = client.get("/api/auth/google/callback", params={"code": "c", "state": state})
    assert r.headers["location"] == "/login?error=state"


def test_state_is_single_use(client):
    r = client.get("/api/auth/google/login")
    state = parse_qs(urlparse(r.headers["location"]).query)["state"][0]
    client.get("/api/auth/google/callback", params={"code": "c", "state": state})
    client.cookies.set(auth.STATE_COOKIE, state, path="/api/auth")
    r = client.get("/api/auth/google/callback", params={"code": "c", "state": state})
    assert r.headers["location"] == "/login?error=failed"


@pytest.mark.parametrize("bad", [
    {"aud": "someone-else"}, {"iss": "https://evil.example"}, {"exp": NOW - 1}, {"email_verified": False},
])
def test_invalid_id_tokens_rejected(client, google, bad):
    google.claims = bad
    r = sign_in(client)
    assert r.headers["location"] == "/login?error=failed"
    assert client.get("/api/me").status_code == 401


def test_user_cancelled_at_google(client):
    r = client.get("/api/auth/google/callback", params={"error": "access_denied"})
    assert r.headers["location"] == "/login?error=cancelled"


@pytest.mark.parametrize("target", ["//evil.example", "https://evil.example", "\\\\evil", "nope"])
def test_no_open_redirect(client, target):
    assert sign_in(client, target).headers["location"] == "/"


def test_first_sign_in_adopts_local_progress(tmp_path, google):
    db_file = str(tmp_path / "adopt.db")
    # before sign-in existed: a single local user learned some words
    local = TestClient(create_app(db_file, clock=lambda: NOW))
    local.put("/api/me", json={"native": "zh", "target": "es"})
    card = local.get("/api/words/session?size=1").json()[0]
    local.post(f"/api/words/{card['id']}/review", json={"known": True})

    client = TestClient(create_app(db_file, clock=lambda: NOW, auth_cfg=CFG, exchange=google),
                        follow_redirects=False)
    sign_in(client, claim="demo")
    me = client.get("/api/me").json()
    assert me["id"] == "demo" and me["target"] == "es" and me["onboarded"]
    assert client.get("/api/home").json()["words"]["levels"]["familiar"] == 1

    # a second Google account cannot take over the same local profile
    client.post("/api/auth/logout")
    google.claims = {"sub": "222", "email": "other@example.com"}
    sign_in(client, claim="demo")
    me2 = client.get("/api/me").json()
    assert me2["id"] != "demo" and not me2["onboarded"]


def test_env_file_loading(tmp_path, monkeypatch):
    env = tmp_path / ".env"
    env.write_text("# comment\nLINGO_TEST_A=from-file\nLINGO_TEST_B='quoted'\nLINGO_TEST_C=\n")
    monkeypatch.setenv("LINGO_TEST_A", "from-env")
    monkeypatch.delenv("LINGO_TEST_B", raising=False)
    load_env_file(env)
    import os
    assert os.environ["LINGO_TEST_A"] == "from-env"  # real environment wins
    assert os.environ["LINGO_TEST_B"] == "quoted"
    assert "LINGO_TEST_C" not in os.environ
    monkeypatch.delenv("LINGO_TEST_B")
