"""Answer explanations, tap-to-translate and custom words."""
import json
import random

import pytest
from fastapi.testclient import TestClient

from app import db, explain, logic, seed
from app.main import create_app

T0 = 1_700_000_000.0


def make(tmp_path, native="zh", target="es"):
    c = TestClient(create_app(str(tmp_path / "t.db"), clock=lambda: T0, rng=random.Random(0)))
    assert c.put("/api/me", json={"native": native, "target": target}).status_code == 200
    return c


def answer(c, qid, choice):
    r = c.post(f"/api/quiz/{qid}/answer", json={"choice": choice})
    assert r.status_code == 200
    return r.json()


# ------------------------------------------------------------------ explanations

def test_vocab_explanations_come_from_the_word_list(tmp_path):
    c = make(tmp_path)
    ok = answer(c, "v-es-gracias-phr", "gracias")
    assert ok["correct"] and "谢谢" in ok["explanation"] and ok["choice_explanation"] is None
    bad = answer(c, "v-es-gracias-phr", "perdón")
    assert not bad["correct"] and "谢谢" in bad["explanation"]
    assert "perdón" in bad["choice_explanation"] and "对不起" in bad["choice_explanation"]


def test_vocab_explanation_handles_capitalised_options(tmp_path):
    bad = answer(make(tmp_path, native="en"), "v-es-s-adv", "Ayer")
    assert "yes" in bad["explanation"] and "Ayer" in bad["choice_explanation"] and "yesterday" in bad["choice_explanation"]


def test_every_vocab_option_can_be_explained():
    """Each option of each vocabulary cloze is a course word, so its meaning is known."""
    words, qs = seed.load_course("es")
    bases = {seed.base_form(x["es"], x["pos"]).lower() for x in words}
    for q in qs:
        if q["skill"] == "vocab":
            t = q["data"]["es"]
            assert {o.lower() for o in [t["answer"], *t["distractors"]]} <= bases, q["id"]


def test_dialogue_wrong_reply_names_the_line_it_answers(tmp_path):
    c = make(tmp_path)
    conn = db.connect(str(tmp_path / "t.db"))
    rows = conn.execute("SELECT id, data FROM questions WHERE course='es' AND kind='next'").fetchall()
    other = json.loads(next(r for r in rows if r["id"] != "es-d301")["data"])
    r = answer(c, "es-d301", other["es"]["answer"])
    assert not r["correct"] and "Muy bien, gracias" in r["explanation"]
    assert other["es"]["prompt"] in r["choice_explanation"] and other["zh"]["prompt"] in r["choice_explanation"]


# ------------------------------------------------------------------ tap-to-translate

def test_words_split_and_translated(tmp_path):
    c = make(tmp_path, native="en")
    r = c.get("/api/quiz/v-es-gracias-phr/words").json()
    assert r["text"] == "Muchas ___ por la comida."
    assert "".join(t["text"] for t in r["tokens"]) == r["text"]
    words = {t["text"]: t for t in r["tokens"] if t["word"]}
    assert set(words) == {"Muchas", "por", "la", "comida"}
    assert words["Muchas"]["lemma"] == "mucho" and words["comida"]["meaning"] and words["comida"]["added"] is False


def test_inflected_form_points_to_its_course_word(tmp_path):
    c = make(tmp_path, native="zh")
    q = next(r["id"] for r in db.connect(str(tmp_path / "t.db")).execute(
        "SELECT id, data FROM questions WHERE course='es'") if "Quiero" in json.loads(r["data"])["es"].get("sentence", ""))
    tok = next(t for t in c.get(f"/api/quiz/{q}/words").json()["tokens"] if t["text"] == "Quiero")
    assert tok["lemma"] == "querer" and tok["meaning"] == "我想要" and tok["lemma_meaning"] != tok["meaning"]


def test_chinese_is_split_into_words(tmp_path):
    c = make(tmp_path, native="en", target="zh")
    toks = c.get("/api/quiz/n04/words").json()["tokens"]
    assert [t["text"] for t in toks if t["word"]] == ["你好吗"]
    toks = c.get("/api/quiz/f04/words").json()["tokens"]
    assert [t["text"] for t in toks if t["word"]] == ["下雨", "了", "别", "忘了", "带"]


def _quiz_texts(conn, course, target):
    for q in conn.execute("SELECT * FROM questions WHERE course=?", (course,)):
        t = json.loads(q["data"]).get(target)
        if t:
            yield logic.strip_brackets(t.get("sentence") or t["prompt"])
            if q["kind"] == "next":
                yield t["answer"]


@pytest.fixture(scope="module")
def content(tmp_path_factory):
    path = str(tmp_path_factory.mktemp("content") / "t.db")
    db.init_db(path)
    conn = db.connect(path)
    return conn, explain.build_dictionaries(conn)


@pytest.mark.parametrize("target", ["es", "en", "fr", "zh"])
def test_every_quiz_word_has_a_meaning(content, target):
    """Word lists + glossaries cover every word of every quiz sentence, for every native language."""
    conn, dictionaries = content
    course = target if target in seed.COURSES else "all"
    missing = set()
    for native in (n for n in db.LANGS if n != target):
        find = explain.make_lookup(dictionaries, target, native)
        for text in _quiz_texts(conn, course, target):
            for tok in explain.tokens(text, target, find):
                if tok["word"] and not tok["meaning"]:
                    missing.add((native, tok["text"]))
    assert not missing, sorted(missing)[:40]


# ------------------------------------------------------------------ custom words

def test_custom_word_joins_the_swipe_deck_only(tmp_path):
    c = make(tmp_path, native="en")
    before = c.get("/api/home").json()
    w = c.post("/api/words/custom", json={"word": "la comida", "meaning": "food", "pos": "n",
                                          "question_id": "v-es-gracias-phr"}).json()
    assert w["custom"] and w["difficulty_level"] == 0 and w["level"] == "new"
    assert w["example"] == "Muchas gracias por la comida." and w["example_translation"] == "Thanks a lot for the food."
    assert c.post("/api/words/custom", json={"word": "La comida", "meaning": "x"}).json()["id"] == w["id"]

    home = c.get("/api/home").json()
    assert home["words"]["total"] == before["words"]["total"] + 1 and home["level"] == before["level"]
    assert home["quiz"]["total"] == before["quiz"]["total"]
    assert w["id"] in [x["id"] for x in c.get("/api/words/session?size=5").json()]
    assert any(x["id"] == w["id"] and x["custom"] for x in c.get("/api/words").json())
    assert all(q["id"] != w["id"] for q in c.get("/api/quiz/session?size=50").json())

    assert c.post(f"/api/words/{w['id']}/review", json={"known": True}).json()["after"]["reps"] == 1
    assert c.post(f"/api/words/{w['id']}/undo").status_code == 200
    tok = next(t for t in c.get("/api/quiz/v-es-gracias-phr/words").json()["tokens"] if t["text"] == "comida")
    assert tok["added"] is True

    assert c.delete(f"/api/words/custom/{w['id']}").json() == {"ok": True}
    assert all(x["id"] != w["id"] for x in c.get("/api/words").json())


def test_custom_words_are_private(tmp_path):
    c = make(tmp_path)
    w = c.post("/api/words/custom", json={"word": "perro", "meaning": "狗"}).json()
    bob = {"X-User-Id": "bob"}
    c.put("/api/me", json={"native": "zh", "target": "es"}, headers=bob)
    assert all(x["id"] != w["id"] for x in c.get("/api/words", headers=bob).json())
    assert c.post(f"/api/words/{w['id']}/review", json={"known": True}, headers=bob).status_code == 404
    assert c.delete(f"/api/words/custom/{w['id']}", headers=bob).status_code == 404


@pytest.mark.parametrize("field", ["word", "meaning"])
def test_custom_word_validation(tmp_path, field):
    body = {"word": "perro", "meaning": "狗", field: ""}
    assert make(tmp_path).post("/api/words/custom", json=body).status_code == 422


def test_glossary_format_errors(tmp_path):
    g = tmp_path / "glossary"
    g.mkdir()
    (g / "es.txt").write_text("!columns zh en\nquiero|querer|v|我想要\n", encoding="utf-8")
    with pytest.raises(seed.ContentError):
        seed.load_glossary("es", tmp_path)
    (g / "es.txt").write_text("!columns zh en\nquiero|querer|verb|我想要|I want\n", encoding="utf-8")
    with pytest.raises(seed.ContentError):
        seed.load_glossary("es", tmp_path)


def test_every_grammar_question_is_explained():
    """Every grammar fill-in explains each of its options, in Chinese and English (English only for
    the Chinese target). Other native languages fall back to English."""
    missing = []
    legacy = seed.parse_questions(sorted(seed.SEED_DIR.glob("questions*.txt")))
    _, course = seed.load_course("es")
    for q in legacy + course:
        if q["kind"] != "fill" or q["skill"] == "vocab":
            continue
        for target, t in q["data"].items():
            if "answer" not in t or (q["course"] == "all" and target in seed.COURSES):
                continue  # translation-only line, or a language with its own course (never shown)
            for native in (["en"] if target == "zh" else ["zh", "en"]):
                if native not in t.get("why", {}):
                    missing.append(f"{q['id']} {target}.{native}")
    assert not missing, f"{len(missing)} missing, e.g. {missing[:10]}"


def test_grammar_explanation_in_answer(tmp_path):
    c = make(tmp_path, native="en")
    r = answer(c, "es-f301", "el")
    assert r["explanation"] and r["choice_explanation"] and r["explanation"] != r["choice_explanation"]
    assert answer(c, "es-f301", "la")["choice_explanation"] is None


def test_why_must_cover_every_option(tmp_path):
    (tmp_path / "q.txt").write_text(
        "@x fill food\n"
        "zh 我要[杯]子 | 本, 辆, 张\nen I want a [cup]. | book, car, shoe\n"
        "fr Une [tasse]. | voiture, fenêtre, chaussure\nes Una [taza]. | ventana, silla, calle\n"
        "why en.zh cup | 杯子\nwhy en.zh book | 书\n", encoding="utf-8")
    with pytest.raises(seed.ContentError):
        seed.parse_questions([tmp_path / "q.txt"])
