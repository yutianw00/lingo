"""Load the hand-written course content into SQLite.

Two kinds of content live in backend/seed/:

* Legacy aligned content (seed/words_*.txt, seed/questions_*.txt): the same 270
  words / 80 questions in all four languages. Used for every target language
  that has no dedicated course.
* Dedicated courses (seed/<lang>/): a leveled course for one target language,
  currently Spanish (seed/es/). Every word has a difficulty score (0–10], a
  grammatical gender for nouns, meanings in zh + en and an example sentence in
  which the word is marked with [brackets]. Vocabulary cloze questions are
  generated from those examples automatically; grammar ("form") and dialogue
  ("context") questions are hand-written with a level each.

Content is upserted on every start-up, keyed by stable ids, so editing the seed
files never wipes anyone's progress.
"""
from __future__ import annotations

import json
import math
import random
import re
import sqlite3
from pathlib import Path

SEED_DIR = Path(__file__).resolve().parent.parent / "seed"
LANGS = ("zh", "en", "fr", "es")
COURSES = ("es",)  # target languages that have a dedicated, leveled course
POS = {"n", "v", "adj", "adv", "pron", "prep", "conj", "num", "interj", "phr", "det"}
GENDERS = {"m", "f", "mf"}
WORD_FIELDS = ("pos", "zh", "en", "fr", "es", "ex_zh", "ex_en", "ex_fr", "ex_es")
COURSE_WORD_FIELDS = ("score", "pos", "gender", "word", "zh", "en", "example", "ex_zh", "ex_en")
ARTICLES = ("el ", "la ", "los ", "las ")
BLANK = re.compile(r"\[([^\]]+)\]")


class ContentError(ValueError):
    pass


def _lines(path: Path):
    for no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if line and not line.startswith("#"):
            yield no, line


def _slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def strip_brackets(s: str) -> str:
    return s.replace("[", "").replace("]", "")


# ------------------------------------------------------------------ legacy (aligned 4-language)

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
            w.update(id=wid, rank=len(words), course="all", score=1.0, level=1, gender="", topic="")
            words.append(w)
    return words


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
                cur = {"id": head[0], "kind": head[1], "topic": head[2], "data": {}, "course": "all",
                       "level": 1, "skill": "form" if head[1] == "fill" else "context", "word_id": None}
                continue
            if cur is None:
                raise ContentError(f"{where}: line outside a question block")
            lang, _, body = line.partition(" ")
            if lang not in LANGS:
                raise ContentError(f"{where}: unknown language {lang!r}")
            cur["data"][lang] = _parse_fill(body, where) if cur["kind"] == "fill" else _parse_next(body, where)
    finish()
    return _interleave(questions)


def _parse_fill(body: str, where: str) -> dict:
    sentence, sep, opts = body.partition("|")
    sentence = sentence.strip()
    blanks = BLANK.findall(sentence)
    distractors = [o.strip() for o in opts.split(",") if o.strip()]
    if not sep or len(blanks) != 1 or len(distractors) != 3:
        raise ContentError(f"{where}: fill line needs one [answer] and 3 distractors")
    if blanks[0] in distractors or len(set(distractors)) != 3:
        raise ContentError(f"{where}: distractors must be distinct from the answer")
    return {"sentence": sentence, "answer": blanks[0], "distractors": distractors}


def _parse_next(body: str, where: str) -> dict:
    prompt, sep, answer = body.partition(">>")
    if not sep or not prompt.strip() or not answer.strip():
        raise ContentError(f"{where}: next line must be 'prompt >> answer'")
    return {"prompt": prompt.strip(), "answer": answer.strip()}


def _interleave(questions: list[dict]) -> list[dict]:
    """Curriculum order alternates kinds, so early sessions mix fill-in and next-sentence."""
    by_kind = {k: [q for q in questions if q["kind"] == k] for k in ("fill", "next")}
    ordered = []
    for i in range(max((len(v) for v in by_kind.values()), default=0)):
        ordered += [v[i] for v in by_kind.values() if i < len(v)]
    return ordered


# ------------------------------------------------------------------ dedicated course

def base_form(word: str, pos: str) -> str:
    """Dictionary form without the article: 'la manzana' -> 'manzana'."""
    if pos == "n":
        for a in ARTICLES:
            if word.startswith(a):
                return word[len(a):]
    return word


def parse_course_words(paths: list[Path], course: str) -> list[dict]:
    words, seen = [], {}
    for path in paths:
        topic = "general"
        for no, line in _lines(path):
            where = f"{course}/{path.name}:{no}"
            if line.startswith("@"):
                topic = line[1:].strip() or "general"
                continue
            parts = [p.strip() for p in line.split("|")]
            if len(parts) != len(COURSE_WORD_FIELDS):
                raise ContentError(f"{where}: expected {len(COURSE_WORD_FIELDS)} fields, got {len(parts)}")
            if any(not p for p in parts):
                raise ContentError(f"{where}: empty field")
            f = dict(zip(COURSE_WORD_FIELDS, parts))
            try:
                score = float(f["score"])
            except ValueError:
                raise ContentError(f"{where}: score must be a number") from None
            if not 0 < score <= 10:
                raise ContentError(f"{where}: score must be in (0, 10]")
            pos, gender = f["pos"], f["gender"]
            if pos not in POS:
                raise ContentError(f"{where}: unknown part of speech {pos!r}")
            if pos == "n" and gender not in GENDERS:
                raise ContentError(f"{where}: noun needs gender m/f/mf")
            if pos != "n" and gender != "-":
                raise ContentError(f"{where}: only nouns have a gender (use '-')")
            blanks = BLANK.findall(f["example"])
            if len(blanks) != 1:
                raise ContentError(f"{where}: example must mark the word with exactly one [..]")
            if "[" in f["ex_zh"] + f["ex_en"]:
                raise ContentError(f"{where}: only the target-language example is bracketed")
            base = base_form(f["word"], pos)
            key = (base, pos, gender)
            if key in seen:
                raise ContentError(f"{where}: duplicate of {seen[key]} ({f['word']})")
            seen[key] = where
            wid = f"{course}-{_slug(base)}-{pos}" + (f"-{gender}" if pos == "n" and gender != "mf" else "")
            words.append({
                "id": wid, "course": course, "score": score, "level": max(1, math.ceil(score)),
                "pos": pos, "gender": gender if pos == "n" else "", "topic": topic,
                "zh": f["zh"], "en": f["en"], "fr": "", "es": "",
                course: f["word"],
                "ex_zh": f["ex_zh"], "ex_en": f["ex_en"], "ex_fr": "", "ex_es": "",
                "ex_" + course: strip_brackets(f["example"]),
                "_base": base, "_example": f["example"], "_answer": blanks[0],
            })
    words.sort(key=lambda w: w["score"])  # stable: equal scores keep file order
    for rank, w in enumerate(words):
        w["rank"] = rank
    return words


def make_vocab_questions(words: list[dict], course: str) -> list[dict]:
    """One fill-in question per word whose example uses its dictionary form.

    Distractors are other words of the same part of speech (and gender, for nouns,
    so the article doesn't give the answer away) with a similar difficulty,
    preferring a different topic. The native translation is shown with these
    questions, so the learner is recalling *which word means this* in context.
    """
    # Sentence-initial answers are capitalised ("[Hola], María"): compare case-insensitively and
    # capitalise the distractors the same way, so letter case never gives the answer away.
    eligible = [w for w in words if w["_answer"].lower() == w["_base"].lower()]
    pools: dict[tuple, list[dict]] = {}
    for w in eligible:
        pools.setdefault((w["pos"], w["gender"]), []).append(w)
    questions = []
    for w in eligible:
        rng = random.Random(w["id"])
        cands = [c for c in pools[(w["pos"], w["gender"])]
                 if c["_base"] != w["_base"] and c["_base"].lower() not in w["_example"].lower()
                 and not c["_base"][:1].isupper()]  # proper nouns (Navidad) would stand out
        chosen: list[str] = []
        # Never harder than the word itself + 2 (the learner must be able to read every option);
        # easier words are fine as a fallback.
        for above, below, other_topic in ((1.5, 1.5, True), (2, 3, True), (2, 3, False), (2, 10, False)):
            tier = [c for c in cands if -below <= c["score"] - w["score"] <= above
                    and (c["topic"] != w["topic"] or not other_topic) and c["_base"] not in chosen]
            rng.shuffle(tier)
            for c in tier:
                if len(chosen) < 3 and c["_base"] not in chosen:
                    chosen.append(c["_base"])
            if len(chosen) == 3:
                break
        if len(chosen) < 3:
            continue
        if w["_answer"][:1].isupper():
            chosen = [c[:1].upper() + c[1:] for c in chosen]
        questions.append({
            "id": f"v-{w['id']}", "kind": "fill", "topic": w["topic"], "course": course,
            "level": w["level"], "skill": "vocab", "word_id": w["id"], "score": w["score"],
            "data": {
                course: {"sentence": w["_example"], "answer": w["_answer"], "distractors": chosen},
                "zh": {"sentence": w["ex_zh"]}, "en": {"sentence": w["ex_en"]},
            },
        })
    return questions


def parse_course_questions(paths: list[Path], course: str) -> list[dict]:
    """Hand-written leveled questions:  @id fill|next <level> <topic>  then es/zh/en lines."""
    questions, cur = [], None
    langs = (course, "zh", "en")

    def finish():
        if cur is None:
            return
        missing = set(langs) - set(cur["data"])
        if missing:
            raise ContentError(f"question {cur['id']}: missing languages {sorted(missing)}")
        questions.append(cur)

    for path in paths:
        for no, line in _lines(path):
            where = f"{course}/{path.name}:{no}"
            if line.startswith("@"):
                finish()
                head = line[1:].split()
                if len(head) != 4 or head[1] not in ("fill", "next"):
                    raise ContentError(f"{where}: header must be '@id fill|next <level> <topic>'")
                try:
                    level = int(head[2])
                except ValueError:
                    raise ContentError(f"{where}: level must be an integer") from None
                if not 1 <= level <= 10:
                    raise ContentError(f"{where}: level must be 1–10")
                qid = f"{course}-{head[0]}"
                if any(q["id"] == qid for q in questions):
                    raise ContentError(f"{where}: duplicate id {head[0]}")
                cur = {"id": qid, "kind": head[1], "level": level, "topic": head[3], "course": course,
                       "skill": "form" if head[1] == "fill" else "context", "word_id": None,
                       "score": float(level), "data": {}}
                continue
            if cur is None:
                raise ContentError(f"{where}: line outside a question block")
            lang, _, body = line.partition(" ")
            if lang not in langs:
                raise ContentError(f"{where}: unknown language {lang!r}")
            body = body.strip()
            if cur["kind"] == "next":
                cur["data"][lang] = _parse_next(body, where)
            elif lang == course:
                cur["data"][lang] = _parse_fill(body, where)
            else:
                if "[" in body or "|" in body:
                    raise ContentError(f"{where}: translation lines are plain sentences")
                cur["data"][lang] = {"sentence": body}
    finish()
    return questions


def load_course(course: str, seed_dir: Path = SEED_DIR) -> tuple[list[dict], list[dict]]:
    d = seed_dir / course
    words = parse_course_words(sorted(d.glob("words_*.txt")), course)
    questions = make_vocab_questions(words, course) + parse_course_questions(sorted(d.glob("questions_*.txt")), course)
    # Curriculum order: by level, then (within a level) alternate skills.
    questions.sort(key=lambda q: q["score"])
    by_level: dict[int, dict[str, list]] = {}
    for q in questions:
        by_level.setdefault(q["level"], {}).setdefault(q["skill"], []).append(q)
    ordered = []
    for level in sorted(by_level):
        groups = list(by_level[level].values())
        for i in range(max(len(g) for g in groups)):
            ordered += [g[i] for g in groups if i < len(g)]
    return words, ordered


# ------------------------------------------------------------------ DB

def load_content(conn: sqlite3.Connection, seed_dir: Path = SEED_DIR) -> None:
    words = parse_words(sorted(seed_dir.glob("words*.txt")))
    questions = parse_questions(sorted(seed_dir.glob("questions*.txt")))
    for course in COURSES:
        if (seed_dir / course).is_dir():
            cw, cq = load_course(course, seed_dir)
            words += cw
            questions += cq
    for rank, q in enumerate(questions):
        q["rank"] = rank
    cols = ("id", "course", "rank", "score", "level", "gender", "topic", *WORD_FIELDS)
    conn.executemany(
        f"INSERT INTO words ({', '.join(cols)}) VALUES ({', '.join(':' + c for c in cols)})",
        words,
    )
    conn.executemany(
        "INSERT INTO questions (id, course, rank, level, skill, word_id, kind, topic, data) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [(q["id"], q["course"], q["rank"], q["level"], q["skill"], q["word_id"], q["kind"], q["topic"],
          json.dumps(q["data"], ensure_ascii=False)) for q in questions],
    )
