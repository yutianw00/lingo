"""Business logic: choosing what to practise, recording reviews, stats."""
from __future__ import annotations

import json
import math
import random
import sqlite3

from . import srs

DUE_SHARE = 0.7  # share of a session reserved for items that are due for review
LEVELS = ("new", "learning", "familiar", "mastered")


# ---------------------------------------------------------------- progress rows

def get_state(conn: sqlite3.Connection, user: str, item_type: str, item_id: str, lang: str) -> srs.State:
    row = conn.execute(
        "SELECT stability, reps, lapses, last_review, due FROM progress "
        "WHERE user_id=? AND item_type=? AND item_id=? AND lang=?",
        (user, item_type, item_id, lang),
    ).fetchone()
    return srs.State(**dict(row)) if row else srs.State()


def all_states(conn, user, item_type, lang) -> dict[str, srs.State]:
    rows = conn.execute(
        "SELECT item_id, stability, reps, lapses, last_review, due FROM progress "
        "WHERE user_id=? AND item_type=? AND lang=?",
        (user, item_type, lang),
    ).fetchall()
    return {r["item_id"]: srs.State(r["stability"], r["reps"], r["lapses"], r["last_review"], r["due"]) for r in rows}


def _save_state(conn, user, item_type, item_id, lang, s: srs.State):
    conn.execute(
        "INSERT OR REPLACE INTO progress (user_id, item_type, item_id, lang, stability, reps, lapses, last_review, due) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (user, item_type, item_id, lang, s.stability, s.reps, s.lapses, s.last_review, s.due),
    )


def record_review(conn, user, item_type, item_id, lang, grade, now, elapsed_ms=None):
    before = get_state(conn, user, item_type, item_id, lang)
    after = srs.review(before, grade, now, elapsed_ms)
    _save_state(conn, user, item_type, item_id, lang, after)
    conn.execute(
        "INSERT INTO review_log (user_id, item_type, item_id, lang, grade, elapsed_ms, ts, before, after) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (
            user, item_type, item_id, lang, grade, elapsed_ms, now,
            json.dumps(before.to_dict()) if before.last_review is not None else None,
            json.dumps(after.to_dict()),
        ),
    )
    conn.commit()
    return before, after


def undo_last(conn, user, item_type, item_id, lang) -> srs.State | None:
    """Revert the most recent review of this item. Returns the restored state."""
    row = conn.execute(
        "SELECT id, before FROM review_log WHERE user_id=? AND item_type=? AND item_id=? AND lang=? "
        "ORDER BY id DESC LIMIT 1",
        (user, item_type, item_id, lang),
    ).fetchone()
    if row is None:
        return None
    conn.execute("DELETE FROM review_log WHERE id=?", (row["id"],))
    if row["before"] is None:
        conn.execute(
            "DELETE FROM progress WHERE user_id=? AND item_type=? AND item_id=? AND lang=?",
            (user, item_type, item_id, lang),
        )
        restored = srs.State()
    else:
        restored = srs.State(**json.loads(row["before"]))
        _save_state(conn, user, item_type, item_id, lang, restored)
    conn.commit()
    return restored


# ---------------------------------------------------------------- scheduling

def pick_session(states: dict[str, srs.State], ordered_ids: list[str], size: int, now: float,
                 rng: random.Random, lapses_first: bool = False) -> list[str]:
    """Mix due reviews (~70 %) with new items (~30 %), topping up from whichever has more.

    Due items are taken most-forgotten first; new items in curriculum order. If there
    is still room (everything learned, nothing due) the soonest-due items fill it.
    """
    due = [i for i, s in states.items() if s.due is not None and s.due <= now]

    def urgency(i):
        s = states[i]
        return (-(s.lapses > 0) if lapses_first else 0, srs.retrievability(s, now))

    due.sort(key=urgency)
    new = [i for i in ordered_ids if i not in states]

    n_due = min(len(due), math.ceil(size * DUE_SHARE))
    n_new = min(len(new), size - n_due)
    n_due = min(len(due), size - n_new)
    picked = due[:n_due] + new[:n_new]

    if len(picked) < size:
        taken = set(picked)
        upcoming = sorted((i for i, s in states.items() if i not in taken), key=lambda i: states[i].due or 0)
        picked += upcoming[: size - len(picked)]

    # Interleave reviews and new items instead of front-loading one kind.
    rng.shuffle(picked)
    return picked


# ---------------------------------------------------------------- serialisation

def item_progress(s: srs.State, now: float) -> dict:
    return {
        "mastery": srs.mastery(s, now),
        "level": srs.level(s, now),
        "due": s.due,
        "reps": s.reps,
        "lapses": s.lapses,
    }


def native_text(row, field: str, native: str) -> str:
    """Course content has meanings in zh + en only; other natives fall back to English."""
    return row[field.format(native)] or row[field.format("en")]


def word_card(row: sqlite3.Row, native: str, target: str, s: srs.State, now: float) -> dict:
    return {
        "id": row["id"],
        "word": row[target],
        "pos": row["pos"],
        "gender": row["gender"],
        "difficulty": row["score"],
        "difficulty_level": row["level"],
        "topic": row["topic"],
        "meaning": native_text(row, "{}", native),
        "example": row["ex_" + target],
        "example_translation": native_text(row, "ex_{}", native),
        **item_progress(s, now),
    }


def strip_brackets(sentence: str) -> str:
    return sentence.replace("[", "").replace("]", "")


def _native(data: dict, native: str) -> dict:
    return data.get(native) or data["en"]


def question_payload(q: sqlite3.Row, native: str, target: str, s: srs.State, now: float,
                     next_pool: list[sqlite3.Row], rng: random.Random) -> dict:
    data = json.loads(q["data"])
    t, n = data[target], _native(data, native)
    base = {"id": q["id"], "kind": q["kind"], "skill": q["skill"], "difficulty_level": q["level"],
            **item_progress(s, now)}
    if q["kind"] == "fill":
        options = [t["answer"], *t["distractors"]]
        rng.shuffle(options)
        blanked = t["sentence"].replace(f"[{t['answer']}]", "___")
        return {**base, "prompt": blanked, "translation": strip_brackets(n["sentence"]),
                "options": [{"text": o, "translation": None} for o in options]}
    # 'next': distractors are the correct follow-ups of other questions on a different topic,
    # no harder than the question itself
    others = [o for o in next_pool if o["topic"] != q["topic"] and o["id"] != q["id"] and o["level"] <= q["level"]]
    if len(others) < 3:
        others = [o for o in next_pool if o["topic"] != q["topic"] and o["id"] != q["id"]]
    chosen = rng.sample(others, k=min(3, len(others)))
    options = [{"text": t["answer"], "translation": n["answer"]}]
    for o in chosen:
        od = json.loads(o["data"])
        options.append({"text": od[target]["answer"], "translation": _native(od, native)["answer"]})
    rng.shuffle(options)
    return {**base, "prompt": t["prompt"], "translation": n["prompt"], "options": options}


def question_answer(q: sqlite3.Row, native: str, target: str) -> dict:
    data = json.loads(q["data"])
    t, n = data[target], _native(data, native)
    if q["kind"] == "fill":
        return {"answer": t["answer"], "full_sentence": strip_brackets(t["sentence"]),
                "translation": strip_brackets(n["sentence"])}
    return {"answer": t["answer"], "full_sentence": f"{t['prompt']} {t['answer']}",
            "translation": f"{n['prompt']} {n['answer']}"}


# ---------------------------------------------------------------- stats

def day_index(ts: float, tz_offset_min: int) -> int:
    # tz_offset_min follows JS Date.getTimezoneOffset(): minutes *behind* UTC (UTC+8 → -480)
    return int((ts - tz_offset_min * 60) // 86400)


def streak_and_today(conn, user: str, now: float, tz_offset_min: int) -> tuple[int, int]:
    rows = conn.execute("SELECT ts FROM review_log WHERE user_id=?", (user,)).fetchall()
    days: dict[int, int] = {}
    for r in rows:
        d = day_index(r["ts"], tz_offset_min)
        days[d] = days.get(d, 0) + 1
    today = day_index(now, tz_offset_min)
    done_today = days.get(today, 0)
    d = today if done_today else today - 1
    streak = 0
    while d in days:
        streak += 1
        d -= 1
    return streak, done_today


def level_counts(states: dict[str, srs.State], total: int, now: float) -> dict:
    counts = dict.fromkeys(LEVELS, 0)
    for s in states.values():
        counts[srs.level(s, now)] += 1
    counts["new"] += total - len(states)
    return counts
