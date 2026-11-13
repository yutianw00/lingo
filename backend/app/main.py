"""HTTP API. All endpoints live under /api; the built web app is served from /.

Auth is intentionally absent for now: the caller identifies itself with the
`X-User-Id` header (default "demo"). Swapping in SSO later only means replacing
`current_user` with a dependency that reads the verified identity.
"""
import random
import sqlite3
import time
from pathlib import Path
from typing import Annotated, Callable, Literal

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from . import db, logic, srs

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


class QuizAnswer(BaseModel):
    choice: str
    elapsed_ms: int | None = Field(default=None, ge=0)


def create_app(db_path: str | None = None, clock: Callable[[], float] = time.time,
               rng: random.Random | None = None) -> FastAPI:
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

    def current_user(conn: Conn, x_user_id: Annotated[str, Header()] = "demo") -> sqlite3.Row:
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
                "onboarded": bool(u["onboarded"]), "daily_goal": u["daily_goal"]}

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

    # ------------------------------------------------------------ home

    @app.get("/api/home")
    def home(user: User, conn: Conn, tz: TzOffset = 0):
        now, lang = clock(), user["target"]
        word_ids = [r["id"] for r in conn.execute("SELECT id FROM words")]
        q_ids = [r["id"] for r in conn.execute("SELECT id FROM questions")]
        ws = {k: v for k, v in logic.all_states(conn, user["id"], "word", lang).items() if k in set(word_ids)}
        qs = {k: v for k, v in logic.all_states(conn, user["id"], "question", lang).items() if k in set(q_ids)}
        streak, done = logic.streak_and_today(conn, user["id"], now, tz)
        return {
            "native": user["native"], "target": user["target"],
            "streak": streak, "today": {"done": done, "goal": user["daily_goal"]},
            "words": {"total": len(word_ids), "due": sum(1 for s in ws.values() if s.due <= now),
                      "new": len(word_ids) - len(ws), "levels": logic.level_counts(ws, len(word_ids), now)},
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
        rows = {r["id"]: r for r in conn.execute("SELECT * FROM words ORDER BY rank")}
        states = {k: v for k, v in logic.all_states(conn, user["id"], "word", target).items() if k in rows}
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
        for r in conn.execute("SELECT * FROM words ORDER BY rank"):
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
        all_rows = conn.execute("SELECT * FROM questions ORDER BY rank").fetchall()
        rows = {r["id"]: r for r in all_rows if kind is None or r["kind"] == kind}
        next_pool = [r for r in all_rows if r["kind"] == "next"]
        states = {k: v for k, v in logic.all_states(conn, user["id"], "question", target).items() if k in rows}
        ids = logic.pick_session(states, list(rows), size, now, rng, lapses_first=True)
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


app = create_app()
