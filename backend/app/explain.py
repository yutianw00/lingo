"""Answer explanations and tap-to-translate word lookups, from the course content alone.

* Word lookups: the course word list, plus the glossaries in seed/glossary/ which cover every
  other word that appears in a quiz (inflected forms, articles, names…). Everything is static,
  so it is loaded once at start-up and a test checks that no quiz word is left uncovered.
* Explanations: a vocabulary-cloze answer is explained by what each option means; a wrong
  dialogue reply by the line it actually answers.
"""
from __future__ import annotations

import re
import sqlite3
from typing import Callable

from . import logic, seed

Entry = dict  # {"lemma", "meaning", "lemma_meaning", "pos"}
Lookup = Callable[[str], Entry | None]

WORD = re.compile(r"[^\W\d_]+(?:['’][^\W\d_]+)*")
MAX_ZH_WORD = 5


def build_dictionaries(conn: sqlite3.Connection) -> dict[tuple[str, str], dict[str, Entry]]:
    """(target, native) -> lower-cased word form -> entry.

    Course word lists first (their meanings are the ones the learner studies), then the
    glossaries, which cover every other word used in a quiz sentence."""
    rows = conn.execute("SELECT * FROM words ORDER BY rank").fetchall()
    out: dict[tuple[str, str], dict[str, Entry]] = {}
    for target in seed.LANGS:
        course = target if target in seed.COURSES else "all"
        glossary = seed.load_glossary(target)
        for native in seed.LANGS:
            if native == target:
                continue
            d: dict[str, Entry] = {}
            for r in rows:
                if r["course"] != course or not r[target]:
                    continue
                meaning = logic.native_text(r, "{}", native) if course != "all" else r[native]
                entry = {"lemma": r[target], "meaning": meaning, "lemma_meaning": meaning, "pos": r["pos"]}
                for form in {r[target], seed.base_form(r[target], r["pos"])}:
                    d.setdefault(form.lower(), entry)
            for form, g in glossary.items():
                if form in d:
                    continue
                m = g["meanings"]
                meaning = m.get(native) or m.get("en") or next(iter(m.values()))
                base = d.get(g["lemma"].lower())  # the lemma's own course entry, if it has one
                d[form] = {"lemma": g["lemma"], "meaning": meaning, "pos": g["pos"],
                           "lemma_meaning": base["meaning"] if base else meaning}
            out[(target, native)] = d
    return out


def make_lookup(dictionaries: dict[tuple[str, str], dict[str, Entry]], target: str, native: str) -> Lookup:
    d = dictionaries.get((target, native), {})

    def find(word: str) -> Entry | None:
        w = word.lower()
        if w in d:
            return d[w]
        # plural nouns / adjectives: gatos -> gato, ciudades -> ciudad
        for suffix in ("es", "s"):
            if target != "zh" and w.endswith(suffix) and w[: -len(suffix)] in d:
                return d[w[: -len(suffix)]]
        return None

    return find


def split_words(text: str, lang: str, lookup: Lookup) -> list[tuple[int, int]]:
    """Word spans: by spaces/punctuation, or for Chinese by longest dictionary match."""
    if lang != "zh":
        return [m.span() for m in WORD.finditer(text)]
    spans, i = [], 0
    while i < len(text):
        if not ("一" <= text[i] <= "鿿"):
            i += 1
            continue
        n = next((n for n in range(MAX_ZH_WORD, 1, -1) if lookup(text[i:i + n])), 1)
        spans.append((i, i + n))
        i += n
    return spans


def tokens(text: str, lang: str, lookup: Lookup) -> list[dict]:
    """Cover `text` with plain-text and word segments; words carry their lookup entry."""
    out, pos = [], 0
    for start, end in split_words(text, lang, lookup):
        if start > pos:
            out.append({"text": text[pos:start], "word": False})
        word = text[start:end]
        info = lookup(word) or {}
        out.append({"text": word, "word": True, "lemma": info.get("lemma"), "meaning": info.get("meaning"),
                    "lemma_meaning": info.get("lemma_meaning"), "pos": info.get("pos")})
        pos = end
    if pos < len(text):
        out.append({"text": text[pos:], "word": False})
    return out


TEMPLATES = {
    "vocab_right": {
        "zh": "“{w}”的意思是“{m}”，正是这句话需要的词。",
        "en": "“{w}” means “{m}” — exactly what this sentence needs.",
        "fr": "« {w} » signifie « {m} » : c'est le mot qu'il faut ici.",
        "es": "«{w}» significa «{m}»: es justo la palabra que pide la frase.",
    },
    "vocab_wrong": {
        "zh": "“{w}”的意思是“{m}”，放在这句话里意思不通。",
        "en": "“{w}” means “{m}”, which doesn't fit this sentence.",
        "fr": "« {w} » signifie « {m} », ce qui n'a pas de sens dans cette phrase.",
        "es": "«{w}» significa «{m}», y no encaja en esta frase.",
    },
    "next_right": {
        "zh": "“{a}”是对“{p}”自然的回应。",
        "en": "“{a}” is a natural reply to “{p}”.",
        "fr": "« {a} » est une réponse naturelle à « {p} ».",
        "es": "«{a}» es una respuesta natural a «{p}».",
    },
    "next_wrong": {
        "zh": "这句是在回应“{p}”（{pn}），和这里的话接不上。",
        "en": "That line answers “{p}” ({pn}), not this one.",
        "fr": "Cette phrase répond à « {p} » ({pn}), pas à celle-ci.",
        "es": "Esa frase responde a «{p}» ({pn}), no a esta.",
    },
}


def template(name: str, native: str, **kw) -> str:
    t = TEMPLATES[name]
    return (t.get(native) or t["en"]).format(**kw)
