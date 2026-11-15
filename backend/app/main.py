"""HTTP API. All endpoints live under /api; the built web app is served from /.

Sign-in: when a Google OAuth client is configured (backend/.env, see .env.example)
every /api call needs a session — a cookie for the web app, or `Authorization:
Bearer <token>` for other clients. Without it the app runs as a single local user
identified by the `X-User-Id` header (default "demo"), which is also what tests use.
"""
import math
import random
import sqlite3
import time
from pathlib import Path
from typing import Annotated, Callable, Literal
from urllib.parse import quote

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

import httpx

from . import auth, config, db, logic, seed, srs
from .config import AuthConfig

Lang = Literal["zh", "en", "fr", "es"]
LANGUAGES = [
    {"code": "zh", "name": "简体中文", "tts": "zh-CN"},
    {"code": "en", "name": "English", "tts": "en-US"},
    {"code": "fr", "name": "Français", "tts": "fr-FR"},
    {"code": "es", "name": "Español", "tts": "es-ES"},
]
WEB_DIST = Path(__file__).resolve().parents[2] / "web" / "dist"


class Settings(BaseModel):
    native: Lang
    target: Lang
    daily_goal: int | None = Field(default=None, ge=5, le=500)


class WordReview(BaseModel):
    known: bool
    peeked: bool = False
    elapsed_ms: int | None = Field(default=None, ge=0)


class AppToken(BaseModel):
    code: str = Field(min_length=1, max_length=200)
    verifier: str = Field(min_length=43, max_length=128)


class QuizAnswer(BaseModel):
    choice: str
    elapsed_ms: int | None = Field(default=None, ge=0)


def create_app(db_path: str | None = None, clock: Callable[[], float] = time.time,
               rng: random.Random | None = None, auth_cfg: AuthConfig | None = None,
               exchange: auth.Exchange = auth.exchange_code) -> FastAPI:
    db.init_db(db_path)
    rng = rng or random.Random()
    app = FastAPI(title="Lingo API", version="0.1.0")

    def get_conn():
        conn = db.connect(db_path)
        try:
            yield conn
        finally:
            conn.close()

    Conn = Annotated[sqlite3.Connection, Depends(get_conn)]

    def session_token(request: Request) -> str | None:
        header = request.headers.get("authorization", "")
        if header.lower().startswith("bearer "):
            return header[7:].strip() or None
        return request.cookies.get(auth.SESSION_COOKIE)

    def current_user(request: Request, conn: Conn, x_user_id: Annotated[str, Header()] = "demo") -> sqlite3.Row:
        if auth_cfg is not None:
            token = session_token(request)
            row = auth.session_user(conn, token, clock()) if token else None
            if row is None:
                raise HTTPException(401, "sign in required")
            return row
        row = conn.execute("SELECT * FROM users WHERE id=?", (x_user_id,)).fetchone()
        if row is None:
            conn.execute("INSERT INTO users (id, created_at) VALUES (?, ?)", (x_user_id, clock()))
            conn.commit()
            row = conn.execute("SELECT * FROM users WHERE id=?", (x_user_id,)).fetchone()
        return row

    User = Annotated[sqlite3.Row, Depends(current_user)]
    TzOffset = Annotated[int, Header(alias="X-Tz-Offset")]

    def me_payload(u) -> dict:
        return {"id": u["id"], "native": u["native"], "target": u["target"],
                "onboarded": bool(u["onboarded"]), "daily_goal": u["daily_goal"],
                "email": u["email"], "name": u["name"], "picture": u["picture"]}

    # ------------------------------------------------------------ sign-in

    @app.get("/api/auth/config")
    def auth_config():
        return {"enabled": auth_cfg is not None, "providers": ["google"] if auth_cfg else []}

    @app.get("/api/auth/google/login", include_in_schema=False)
    def google_login(conn: Conn, next: str = "/", claim: str | None = None, app_challenge: str | None = None):
        if auth_cfg is None:
            raise HTTPException(404, "sign-in is not configured")
        if app_challenge is not None and not auth.valid_challenge(app_challenge):
            raise HTTPException(422, "app_challenge must be a base64url SHA-256 (S256) PKCE challenge")
        state, challenge = auth.start_login(conn, next, claim, clock(), app_challenge)
        resp = RedirectResponse(auth.authorization_url(auth_cfg, state, challenge), status_code=302)
        resp.set_cookie(auth.STATE_COOKIE, state, max_age=auth.STATE_TTL, httponly=True, samesite="lax",
                        secure=auth_cfg.cookie_secure, path="/api/auth")
        return resp

    @app.get("/api/auth/google/callback", include_in_schema=False)
    def google_callback(request: Request, conn: Conn, code: str | None = None, state: str | None = None,
                        error: str | None = None):
        if auth_cfg is None:
            raise HTTPException(404, "sign-in is not configured")

        app_login = auth.is_app_login(conn, request.cookies.get(auth.STATE_COOKIE))

        def fail(reason: str):
            target = auth.APP_REDIRECT if app_login else f"{auth_cfg.frontend_url}/login"
            resp = RedirectResponse(f"{target}?error={quote(reason)}", status_code=302)
            resp.delete_cookie(auth.STATE_COOKIE, path="/api/auth")
            return resp

        if error:
            return fail("cancelled")
        if not code or not state or request.cookies.get(auth.STATE_COOKIE) != state:
            return fail("state")
        now = clock()
        try:
            pending = auth.take_login(conn, state, now)
            tokens = exchange(auth_cfg, code, pending["verifier"])
            claims = auth.id_token_claims(tokens.get("id_token", ""), auth_cfg, now)
        except (auth.AuthError, httpx.HTTPError):
            return fail("failed")
        uid = auth.upsert_google_user(conn, claims, pending["claim"], now)
        if pending["app_challenge"]:
            code = auth.create_app_code(conn, uid, pending["app_challenge"], now)
            resp = RedirectResponse(f"{auth.APP_REDIRECT}?code={quote(code)}", status_code=302)
            resp.delete_cookie(auth.STATE_COOKIE, path="/api/auth")
            return resp
        token = auth.create_session(conn, uid, now, auth_cfg.session_days)
        resp = RedirectResponse(auth_cfg.frontend_url + pending["next"], status_code=302)
        resp.set_cookie(auth.SESSION_COOKIE, token, max_age=auth_cfg.session_days * 86400, httponly=True,
                        samesite="lax", secure=auth_cfg.cookie_secure, path="/")
        resp.delete_cookie(auth.STATE_COOKIE, path="/api/auth")
        return resp

    @app.post("/api/auth/app/token")
    def app_token(body: AppToken, conn: Conn):
        """Native apps: trade the one-time code from `lingo://auth?code=…` (plus the PKCE verifier) for a session."""
        if auth_cfg is None:
            raise HTTPException(404, "sign-in is not configured")
        now = clock()
        try:
            uid = auth.redeem_app_code(conn, body.code, body.verifier, now)
        except auth.AuthError as e:
            raise HTTPException(400, str(e)) from None
        token = auth.create_session(conn, uid, now, auth_cfg.session_days)
        return {"token": token, "expires_in": auth_cfg.session_days * 86400}

    @app.post("/api/auth/logout")
    def logout(request: Request, conn: Conn):
        token = session_token(request)
        if token:
            auth.end_session(conn, token)
        resp = JSONResponse({"ok": True})
        resp.delete_cookie(auth.SESSION_COOKIE, path="/")
        return resp

    # ------------------------------------------------------------ settings

    @app.get("/api/languages")
    def languages():
        return LANGUAGES

    @app.get("/api/me")
    def get_me(user: User):
        return me_payload(user)

    @app.put("/api/me")
    def put_me(body: Settings, user: User, conn: Conn):
        if body.native == body.target:
            raise HTTPException(422, "native and target language must differ")
        conn.execute(
            "UPDATE users SET native=?, target=?, onboarded=1, daily_goal=COALESCE(?, daily_goal) WHERE id=?",
            (body.native, body.target, body.daily_goal, user["id"]),
        )
        conn.commit()
        return me_payload(conn.execute("SELECT * FROM users WHERE id=?", (user["id"],)).fetchone())

    # ------------------------------------------------------------ content selection

    def course_of(target: str) -> str:
        return target if target in seed.COURSES else "all"

    def course_words(conn, target):
        return conn.execute("SELECT * FROM words WHERE course=? ORDER BY rank", (course_of(target),)).fetchall()

    def word_states(conn, user, rows) -> dict[str, srs.State]:
        ids = {r["id"] for r in rows}
        return {k: v for k, v in logic.all_states(conn, user["id"], "word", user["target"]).items() if k in ids}

    def learner_level(rows, wstates) -> tuple[int, float]:
        """The learner's level = the hardest word they have been introduced to (words come in level order)."""
        scores = [r["score"] for r in rows if r["id"] in wstates]
        top = max(scores, default=0.0)
        return max(1, math.ceil(top)), top

    def quiz_pool(conn, user):
        """Questions available right now, plus the course's dialogue pool (for distractors).

        Leveled courses gate questions: a vocab cloze unlocks once its word has been
        introduced in the swipe deck; grammar and dialogue questions unlock at their level.
        """
        target = user["target"]
        course = course_of(target)
        rows = conn.execute("SELECT * FROM questions WHERE course=? ORDER BY rank", (course,)).fetchall()
        next_pool = [r for r in rows if r["kind"] == "next"]
        if course == "all":
            return rows, next_pool
        words = course_words(conn, target)
        wstates = word_states(conn, user, words)
        level, _ = learner_level(words, wstates)
        pool = [r for r in rows if (r["word_id"] in wstates if r["skill"] == "vocab" else r["level"] <= level)]
        return pool, next_pool

    # ------------------------------------------------------------ home

    @app.get("/api/home")
    def home(user: User, conn: Conn, tz: TzOffset = 0):
        now, lang = clock(), user["target"]
        words = course_words(conn, lang)
        ws = word_states(conn, user, words)
        pool, _ = quiz_pool(conn, user)
        q_ids = {r["id"] for r in pool}
        qs = {k: v for k, v in logic.all_states(conn, user["id"], "question", lang).items() if k in q_ids}
        streak, done = logic.streak_and_today(conn, user["id"], now, tz)
        level, score = learner_level(words, ws)
        return {
            "native": user["native"], "target": user["target"],
            "leveled": course_of(lang) != "all", "level": level, "level_score": round(score, 1),
            "streak": streak, "today": {"done": done, "goal": user["daily_goal"]},
            "words": {"total": len(words), "due": sum(1 for s in ws.values() if s.due <= now),
                      "new": len(words) - len(ws), "levels": logic.level_counts(ws, len(words), now)},
            "quiz": {"total": len(q_ids), "due": sum(1 for s in qs.values() if s.due <= now),
                     "new": len(q_ids) - len(qs),
                     "mistakes": sum(1 for s in qs.values() if s.lapses > 0 and s.due <= now),
                     "levels": logic.level_counts(qs, len(q_ids), now)},
        }

    # ------------------------------------------------------------ words

    def word_row(conn, word_id):
        row = conn.execute("SELECT * FROM words WHERE id=?", (word_id,)).fetchone()
        if row is None:
            raise HTTPException(404, "word not found")
        return row

    @app.get("/api/words/session")
    def word_session(user: User, conn: Conn, size: int = Query(20, ge=1, le=100)):
        now, native, target = clock(), user["native"], user["target"]
        rows = {r["id"]: r for r in course_words(conn, target)}
        states = word_states(conn, user, rows.values())
        ids = logic.pick_session(states, list(rows), size, now, rng)
        return [logic.word_card(rows[i], native, target, states.get(i, srs.State()), now) for i in ids]

    @app.post("/api/words/{word_id}/review")
    def review_word(word_id: str, body: WordReview, user: User, conn: Conn):
        word_row(conn, word_id)
        grade = ("swipe_known_peeked" if body.peeked else "swipe_known") if body.known else "swipe_unknown"
        now = clock()
        before, after = logic.record_review(conn, user["id"], "word", word_id, user["target"], grade, now,
                                            body.elapsed_ms)
        return {"grade": grade, "before": logic.item_progress(before, now), "after": logic.item_progress(after, now)}

    @app.post("/api/words/{word_id}/undo")
    def undo_word(word_id: str, user: User, conn: Conn):
        word_row(conn, word_id)
        restored = logic.undo_last(conn, user["id"], "word", word_id, user["target"])
        if restored is None:
            raise HTTPException(409, "nothing to undo")
        return logic.item_progress(restored, clock())

    @app.get("/api/words")
    def list_words(user: User, conn: Conn,
                   level: Literal["new", "learning", "familiar", "mastered", "due"] | None = None,
                   q: str | None = None):
        now, native, target = clock(), user["native"], user["target"]
        states = logic.all_states(conn, user["id"], "word", target)
        out = []
        needle = (q or "").strip().lower()
        for r in course_words(conn, target):
            s = states.get(r["id"], srs.State())
            card = logic.word_card(r, native, target, s, now)
            if level == "due" and not (s.due is not None and s.due <= now):
                continue
            if level and level != "due" and card["level"] != level:
                continue
            if needle and needle not in card["word"].lower() and needle not in card["meaning"].lower():
                continue
            out.append(card)
        return out

    # ------------------------------------------------------------ quiz

    def question_row(conn, qid):
        row = conn.execute("SELECT * FROM questions WHERE id=?", (qid,)).fetchone()
        if row is None:
            raise HTTPException(404, "question not found")
        return row

    @app.get("/api/quiz/session")
    def quiz_session(user: User, conn: Conn, size: int = Query(10, ge=1, le=50),
                     kind: Literal["fill", "next"] | None = None):
        now, native, target = clock(), user["native"], user["target"]
        pool, next_pool = quiz_pool(conn, user)
        rows = {r["id"]: r for r in pool if kind is None or r["kind"] == kind}
        states = {k: v for k, v in logic.all_states(conn, user["id"], "question", target).items() if k in rows}
        # New questions: round-robin across skills (each in curriculum order), so thousands of
        # vocabulary clozes never crowd out the grammar and dialogue questions.
        by_skill: dict[str, list[str]] = {}
        for qid, r in rows.items():
            if qid not in states:
                by_skill.setdefault(r["skill"], []).append(qid)
        groups = list(by_skill.values())
        new_order = [g[i] for i in range(max(map(len, groups), default=0)) for g in groups if i < len(g)]
        ids = logic.pick_session(states, new_order, size, now, rng, lapses_first=True)
        return [logic.question_payload(rows[i], native, target, states.get(i, srs.State()), now, next_pool, rng)
                for i in ids]

    @app.post("/api/quiz/{qid}/answer")
    def answer_question(qid: str, body: QuizAnswer, user: User, conn: Conn):
        q = question_row(conn, qid)
        solution = logic.question_answer(q, user["native"], user["target"])
        correct = body.choice.strip() == solution["answer"]
        now = clock()
        before, after = logic.record_review(conn, user["id"], "question", qid, user["target"],
                                            "quiz_correct" if correct else "quiz_wrong", now, body.elapsed_ms)
        return {"correct": correct, **solution,
                "before": logic.item_progress(before, now), "after": logic.item_progress(after, now)}

    # ------------------------------------------------------------ web app

    if WEB_DIST.exists():
        app.mount("/assets", StaticFiles(directory=WEB_DIST / "assets"), name="assets")

        @app.get("/{path:path}", include_in_schema=False)
        def spa(path: str, request: Request):
            if path.startswith("api/"):
                raise HTTPException(404)
            f = WEB_DIST / path
            if path and f.is_file() and WEB_DIST in f.resolve().parents:
                return FileResponse(f)
            return FileResponse(WEB_DIST / "index.html")

    return app


app = create_app(auth_cfg=config.auth_from_env())
