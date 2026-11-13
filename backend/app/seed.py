"""Load the hand-written course content (backend/seed/*.txt) into SQLite.

Content is upserted on every start-up, keyed by stable ids, so editing the seed
files never wipes anyone's progress.
"""
from __future__ import annotations

import json
import re
import sqlite3
from pathlib import Path

SEED_DIR = Path(__file__).resolve().parent.parent / "seed"
LANGS = ("zh", "en", "fr", "es")
POS = {"n", "v", "adj", "adv", "pron", "prep", "conj", "num", "interj", "phr"}
WORD_FIELDS = ("pos", "zh", "en", "fr", "es", "ex_zh", "ex_en", "ex_fr", "ex_es")


class ContentError(ValueError):
    pass


def _lines(path: Path):
    for no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if line and not line.startswith("#"):
            yield no, line


def _slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def parse_words(paths: list[Path]) -> list[dict]:
    words, seen = [], set()
    for path in paths:
        for no, line in _lines(path):
            parts = [p.strip() for p in line.split("|")]
            if len(parts) != len(WORD_FIELDS):
                raise ContentError(f"{path.name}:{no}: expected {len(WORD_FIELDS)} fields, got {len(parts)}")
            w = dict(zip(WORD_FIELDS, parts))
            if w["pos"] not in POS:
                raise ContentError(f"{path.name}:{no}: unknown part of speech {w['pos']!r}")
            if any(not v for v in parts):
                raise ContentError(f"{path.name}:{no}: empty field")
            wid = _slug(w["en"])
            if wid in seen:
                wid = f"{wid}-{w['pos']}"
            if wid in seen:
                raise ContentError(f"{path.name}:{no}: duplicate word {w['en']!r}")
            seen.add(wid)
            w["id"] = wid
            w["rank"] = len(words)
            words.append(w)
    return words


BLANK = re.compile(r"\[([^\]]+)\]")


def parse_questions(paths: list[Path]) -> list[dict]:
    questions, cur = [], None

    def finish():
        if cur is None:
            return
        missing = set(LANGS) - set(cur["data"])
        if missing:
            raise ContentError(f"question {cur['id']}: missing languages {sorted(missing)}")
        questions.append(cur)

    for path in paths:
        for no, line in _lines(path):
            where = f"{path.name}:{no}"
            if line.startswith("@"):
                finish()
                head = line[1:].split()
                if len(head) != 3 or head[1] not in ("fill", "next"):
                    raise ContentError(f"{where}: header must be '@id fill|next topic'")
                if any(q["id"] == head[0] for q in questions):
                    raise ContentError(f"{where}: duplicate id {head[0]}")
                cur = {"id": head[0], "kind": head[1], "topic": head[2], "rank": len(questions), "data": {}}
                continue
            if cur is None:
                raise ContentError(f"{where}: line outside a question block")
            lang, _, body = line.partition(" ")
            if lang not in LANGS:
                raise ContentError(f"{where}: unknown language {lang!r}")
            body = body.strip()
            if cur["kind"] == "fill":
                sentence, sep, opts = body.partition("|")
                sentence = sentence.strip()
                blanks = BLANK.findall(sentence)
                distractors = [o.strip() for o in opts.split(",") if o.strip()]
                if not sep or len(blanks) != 1 or len(distractors) != 3:
                    raise ContentError(f"{where}: fill line needs one [answer] and 3 distractors")
                if blanks[0] in distractors or len(set(distractors)) != 3:
                    raise ContentError(f"{where}: distractors must be distinct from the answer")
                cur["data"][lang] = {"sentence": sentence, "answer": blanks[0], "distractors": distractors}
            else:
                prompt, sep, answer = body.partition(">>")
                if not sep or not prompt.strip() or not answer.strip():
                    raise ContentError(f"{where}: next line must be 'prompt >> answer'")
                cur["data"][lang] = {"prompt": prompt.strip(), "answer": answer.strip()}
    finish()
    # Curriculum order alternates kinds, so early sessions mix fill-in and next-sentence.
    by_kind = {k: [q for q in questions if q["kind"] == k] for k in ("fill", "next")}
    ordered = []
    for i in range(max(len(v) for v in by_kind.values())):
        ordered += [v[i] for v in by_kind.values() if i < len(v)]
    for rank, q in enumerate(ordered):
        q["rank"] = rank
    return ordered


def load_content(conn: sqlite3.Connection, seed_dir: Path = SEED_DIR) -> None:
    words = parse_words(sorted(seed_dir.glob("words*.txt")))
    questions = parse_questions(sorted(seed_dir.glob("questions*.txt")))
    conn.executemany(
        f"INSERT OR REPLACE INTO words (id, rank, {', '.join(WORD_FIELDS)}) "
        f"VALUES (:id, :rank, {', '.join(':' + f for f in WORD_FIELDS)})",
        words,
    )
    conn.executemany(
        "INSERT OR REPLACE INTO questions (id, rank, kind, topic, data) VALUES (?, ?, ?, ?, ?)",
        [(q["id"], q["rank"], q["kind"], q["topic"], json.dumps(q["data"], ensure_ascii=False)) for q in questions],
    )
    # Drop content that was removed from the seed files (progress rows stay harmless).
    conn.execute(f"DELETE FROM words WHERE id NOT IN ({','.join('?' * len(words))})", [w["id"] for w in words])
    conn.execute(
        f"DELETE FROM questions WHERE id NOT IN ({','.join('?' * len(questions))})", [q["id"] for q in questions]
    )
