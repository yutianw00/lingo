from __future__ import annotations

import os
import sqlite3
from pathlib import Path

from . import seed

LANGS = ("zh", "en", "fr", "es")
DEFAULT_DB = Path(__file__).resolve().parent.parent / "lingo.db"

SCHEMA = """
CREATE TABLE IF NOT EXISTS words (
    id TEXT PRIMARY KEY,
    rank INTEGER NOT NULL,
    pos TEXT NOT NULL,
    zh TEXT NOT NULL, en TEXT NOT NULL, fr TEXT NOT NULL, es TEXT NOT NULL,
    ex_zh TEXT NOT NULL, ex_en TEXT NOT NULL, ex_fr TEXT NOT NULL, ex_es TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS questions (
    id TEXT PRIMARY KEY,
    rank INTEGER NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('fill', 'next')),
    topic TEXT NOT NULL,
    data TEXT NOT NULL            -- JSON, keyed by language
);
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    native TEXT NOT NULL DEFAULT 'zh',
    target TEXT NOT NULL DEFAULT 'en',
    onboarded INTEGER NOT NULL DEFAULT 0,
    daily_goal INTEGER NOT NULL DEFAULT 30,
    created_at REAL NOT NULL
);
-- One row per (user, item, language being learned). Words and quiz questions
-- are tracked independently (item_type = 'word' | 'question').
CREATE TABLE IF NOT EXISTS progress (
    user_id TEXT NOT NULL,
    item_type TEXT NOT NULL,
    item_id TEXT NOT NULL,
    lang TEXT NOT NULL,
    stability REAL NOT NULL,
    reps INTEGER NOT NULL,
    lapses INTEGER NOT NULL,
    last_review REAL,
    due REAL,
    PRIMARY KEY (user_id, item_type, item_id, lang)
);
CREATE INDEX IF NOT EXISTS idx_progress_due ON progress (user_id, item_type, lang, due);
CREATE TABLE IF NOT EXISTS review_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    item_type TEXT NOT NULL,
    item_id TEXT NOT NULL,
    lang TEXT NOT NULL,
    grade TEXT NOT NULL,
    elapsed_ms INTEGER,
    ts REAL NOT NULL,
    before TEXT,                  -- JSON of previous progress state (for undo), NULL if new
    after TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_log_user_ts ON review_log (user_id, ts);
"""


def db_path() -> str:
    return os.environ.get("LINGO_DB", str(DEFAULT_DB))


def connect(path: str | None = None) -> sqlite3.Connection:
    conn = sqlite3.connect(path or db_path(), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def init_db(path: str | None = None) -> None:
    conn = connect(path)
    try:
        conn.executescript(SCHEMA)
        seed.load_content(conn)
        conn.commit()
    finally:
        conn.close()
