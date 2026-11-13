"""The leveled Spanish course: content integrity and level gating."""
import random

import pytest
from fastapi.testclient import TestClient

from app import seed
from app.main import create_app


@pytest.fixture(scope="module")
def course():
    return seed.load_course("es")


def test_course_size_and_levels(course):
    words, questions = course
    assert len(words) >= 3000
    levels = {w["level"] for w in words}
    assert levels == set(range(1, 11))
    assert all(0 < w["score"] <= 10 for w in words)
    assert [w["score"] for w in words] == sorted(w["score"] for w in words)


def test_every_noun_has_gender(course):
    words, _ = course
    nouns = [w for w in words if w["pos"] == "n"]
    assert nouns and all(w["gender"] in {"m", "f", "mf"} for w in nouns)
    assert all(w["gender"] == "" for w in words if w["pos"] != "n")


def test_vocab_questions_are_well_formed(course):
    words, questions = course
    by_base = {}
    for w in words:
        by_base.setdefault(w["_base"].lower(), []).append(w)
    vocab = [q for q in questions if q["skill"] == "vocab"]
    assert len(vocab) > 0.9 * len(words)
    for q in vocab:
        d = q["data"]["es"]
        assert d["answer"] not in d["distractors"] and len(set(d["distractors"])) == 3
        # letter case matches the answer's, so capitalisation is never a giveaway
        assert all(x[:1].isupper() == d["answer"][:1].isupper() for x in d["distractors"])
        word = next(w for w in words if w["id"] == q["word_id"])
        for dist in d["distractors"]:
            # same part of speech (and gender for nouns) so grammar never gives the answer away,
            # and never much harder than the word being tested
            assert any(o["pos"] == word["pos"] and o["gender"] == word["gender"]
                       and o["score"] <= word["score"] + 2 for o in by_base[dist.lower()])


def test_progression_rules(course):
    _, questions = course
    hand = [q for q in questions if q["skill"] != "vocab"]
    assert all(q["level"] >= 3 for q in hand), "levels 1–2 are vocabulary only"
    for level in range(3, 11):
        at = [q for q in hand if q["level"] == level]
        assert any(q["skill"] == "form" for q in at) and any(q["skill"] == "context" for q in at), level
    # curriculum order never puts a harder question before an easier one
    assert [q["level"] for q in questions] == sorted(q["level"] for q in questions)


@pytest.fixture
def es_client(tmp_path):
    c = TestClient(create_app(str(tmp_path / "es.db"), clock=lambda: 1_700_000_000.0, rng=random.Random(1)))
    c.put("/api/me", json={"native": "zh", "target": "es"})
    return c


def test_cards_show_gender_and_difficulty(es_client):
    cards = es_client.get("/api/words/session?size=20").json()
    assert all(c["difficulty_level"] == 1 for c in cards), "new learners start at level 1"
    noun = next(c for c in es_client.get("/api/words?q=manzana").json() if c["word"] == "la manzana")
    assert noun["gender"] == "f" and noun["meaning"] == "苹果" and noun["example"] == "Me como una manzana."


def test_quiz_locked_until_words_are_seen(es_client):
    assert es_client.get("/api/quiz/session").json() == []
    home = es_client.get("/api/home").json()
    assert home["leveled"] and home["level"] == 1 and home["quiz"]["total"] == 0
    seen = set()
    for card in es_client.get("/api/words/session?size=5").json():
        es_client.post(f"/api/words/{card['id']}/review", json={"known": True})
        seen.add(card["id"])
    qs = es_client.get("/api/quiz/session").json()
    assert qs and all(q["skill"] == "vocab" and q["id"][2:] in seen for q in qs)


def test_grammar_and_dialogues_unlock_by_level(es_client):
    words = es_client.get("/api/words").json()
    for w in words:
        if w["difficulty_level"] <= 3:
            es_client.post(f"/api/words/{w['id']}/review", json={"known": True})
    assert es_client.get("/api/home").json()["level"] == 3
    qs = es_client.get("/api/quiz/session?size=50").json()
    hand = [q for q in qs if q["skill"] != "vocab"]
    assert hand and all(q["difficulty_level"] <= 3 for q in hand)
    assert {q["skill"] for q in hand} == {"form", "context"}


def test_english_speaker_gets_english_meanings(es_client):
    es_client.put("/api/me", json={"native": "fr", "target": "es"})  # no French glosses → falls back to English
    card = next(c for c in es_client.get("/api/words?q=manzana").json() if c["word"] == "la manzana")
    assert card["meaning"] == "apple"
