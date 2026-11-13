import random

import pytest
from fastapi.testclient import TestClient

from app import srs
from app.main import create_app

T0 = 1_700_000_000.0


class Clock:
    def __init__(self):
        self.now = T0

    def __call__(self):
        return self.now


@pytest.fixture
def clock():
    return Clock()


@pytest.fixture
def client(tmp_path, clock):
    app = create_app(str(tmp_path / "test.db"), clock=clock, rng=random.Random(0))
    c = TestClient(app)
    r = c.put("/api/me", json={"native": "zh", "target": "fr"})
    assert r.status_code == 200
    return c


def test_new_user_defaults_and_onboarding(tmp_path):
    c = TestClient(create_app(str(tmp_path / "x.db")))
    me = c.get("/api/me", headers={"X-User-Id": "alice"}).json()
    assert me["onboarded"] is False
    r = c.put("/api/me", json={"native": "en", "target": "es"}, headers={"X-User-Id": "alice"})
    assert r.json()["onboarded"] is True and r.json()["target"] == "es"


def test_same_language_rejected(client):
    assert client.put("/api/me", json={"native": "fr", "target": "fr"}).status_code == 422


def test_word_session_all_new_in_curriculum_order_languages(client):
    cards = client.get("/api/words/session?size=20").json()
    assert len(cards) == 20
    assert all(c["level"] == "new" and c["mastery"] == 0 for c in cards)
    hello = next(c for c in cards if c["id"] == "hello")
    assert hello["word"] == "bonjour" and hello["meaning"] == "你好"
    assert hello["example"].startswith("Bonjour") and hello["example_translation"].startswith("你好")


def test_word_review_updates_mastery_and_home(client):
    r = client.post("/api/words/apple/review", json={"known": True, "elapsed_ms": 1000}).json()
    assert r["before"]["mastery"] == 0 and r["after"]["level"] == "familiar"
    client.post("/api/words/bread/review", json={"known": False})
    home = client.get("/api/home").json()
    assert home["today"]["done"] == 2
    assert home["streak"] == 1
    assert home["words"]["levels"]["familiar"] == 1
    assert home["words"]["levels"]["learning"] == 1
    assert home["words"]["new"] == home["words"]["total"] - 2


def test_progress_is_per_target_language(client):
    client.post("/api/words/apple/review", json={"known": True})
    client.put("/api/me", json={"native": "zh", "target": "en"})
    card = next(c for c in client.get("/api/words").json() if c["id"] == "apple")
    assert card["word"] == "apple" and card["level"] == "new"


def test_undo_restores_previous_state(client):
    client.post("/api/words/apple/review", json={"known": True})
    first = client.get("/api/words?q=pomme").json()[0]
    client.post("/api/words/apple/review", json={"known": False})
    restored = client.post("/api/words/apple/undo").json()
    assert restored["mastery"] == first["mastery"]
    client.post("/api/words/apple/undo")
    assert client.get("/api/words?q=pomme").json()[0]["level"] == "new"
    assert client.post("/api/words/apple/undo").status_code == 409
    assert client.get("/api/home").json()["today"]["done"] == 0


def test_due_words_come_back_first(client, clock):
    client.post("/api/words/apple/review", json={"known": False})
    clock.now += srs.DAY
    ids = [c["id"] for c in client.get("/api/words/session?size=5").json()]
    assert "apple" in ids


def test_list_filters(client):
    client.post("/api/words/apple/review", json={"known": True})
    assert [c["id"] for c in client.get("/api/words?level=familiar").json()] == ["apple"]
    assert client.get("/api/words?q=苹果").json()[0]["id"] == "apple"
    assert len(client.get("/api/words?level=due").json()) == 0


def test_quiz_fill_flow(client):
    qs = client.get("/api/quiz/session?size=40&kind=fill").json()
    q = next(x for x in qs if x["id"] == "f01")
    assert q["prompt"] == "Je voudrais une ___ de café."
    assert q["translation"] == "我想要一杯咖啡。"
    assert sorted(o["text"] for o in q["options"]) == sorted(["tasse", "voiture", "fenêtre", "chaussure"])
    wrong = client.post("/api/quiz/f01/answer", json={"choice": "voiture"}).json()
    assert wrong["correct"] is False and wrong["answer"] == "tasse"
    assert wrong["full_sentence"] == "Je voudrais une tasse de café."
    right = client.post("/api/quiz/f01/answer", json={"choice": "tasse"}).json()
    assert right["correct"] is True


def test_quiz_mastery_independent_from_words(client):
    client.post("/api/quiz/f01/answer", json={"choice": "tasse"})
    home = client.get("/api/home").json()
    assert home["quiz"]["levels"]["learning"] == 1
    assert home["words"]["new"] == home["words"]["total"]


def test_quiz_next_options_from_other_topics(client):
    qs = client.get("/api/quiz/session?size=40&kind=next").json()
    q = next(x for x in qs if x["id"] == "n02")
    texts = [o["text"] for o in q["options"]]
    assert len(texts) == 4 and len(set(texts)) == 4
    assert "Alors je prends mon parapluie." in texts
    assert "Mets ton manteau." not in texts  # same topic (weather) is never a distractor
    assert all(o["translation"] for o in q["options"])


def test_first_quiz_session_mixes_kinds(client):
    kinds = [q["kind"] for q in client.get("/api/quiz/session?size=10").json()]
    assert kinds.count("fill") == 5 and kinds.count("next") == 5


def test_wrong_answers_prioritised(client, clock):
    client.post("/api/quiz/n05/answer", json={"choice": "nope"})
    clock.now += srs.DAY
    qs = client.get("/api/quiz/session?size=10").json()
    assert "n05" in [q["id"] for q in qs]


def test_every_language_pair_serves_content(client):
    for native in ("zh", "en", "fr", "es"):
        for target in ("zh", "en", "fr", "es"):
            if native == target:
                continue
            client.put("/api/me", json={"native": native, "target": target})
            words = client.get("/api/words/session?size=50").json()
            assert len(words) == 50 and all(w["meaning"] and w["example_translation"] for w in words)
            if target == "es":  # leveled course: questions unlock once words are introduced
                for w in words:
                    client.post(f"/api/words/{w['id']}/review", json={"known": True})
            qs = client.get("/api/quiz/session?size=30").json()
            assert len(qs) == 30, (native, target)
            for q in qs:
                texts = [o["text"] for o in q["options"]]
                assert len(texts) == 4 and len(set(texts)) == 4, (native, target, q["id"])
                assert q["translation"], (native, target, q["id"])


def test_streak_counts_consecutive_days(client, clock):
    for _ in range(3):
        client.post("/api/words/apple/review", json={"known": True})
        clock.now += srs.DAY
    assert client.get("/api/home").json()["streak"] == 3  # today has none yet → counts up to yesterday
    clock.now += srs.DAY
    assert client.get("/api/home").json()["streak"] == 0


def test_unknown_ids_404(client):
    assert client.post("/api/words/nope/review", json={"known": True}).status_code == 404
    assert client.post("/api/quiz/nope/answer", json={"choice": "x"}).status_code == 404
