from app import srs

DAY = srs.DAY
T0 = 1_700_000_000.0


def test_new_item_has_zero_mastery():
    s = srs.State()
    assert srs.mastery(s, T0) == 0
    assert srs.level(s, T0) == "new"


def test_known_at_first_sight_jumps_to_familiar():
    s = srs.review(srs.State(), "swipe_known", T0, elapsed_ms=3000)
    assert s.stability == 7.0
    assert srs.level(s, T0) == "familiar"
    assert s.due == T0 + 7 * DAY


def test_peeked_counts_less_than_known():
    known = srs.review(srs.State(), "swipe_known", T0)
    peeked = srs.review(srs.State(), "swipe_known_peeked", T0)
    assert peeked.stability < known.stability
    assert srs.mastery(peeked, T0) < srs.mastery(known, T0)


def test_unknown_comes_back_same_day():
    s = srs.review(srs.State(), "swipe_unknown", T0)
    assert s.lapses == 1 and s.reps == 0
    assert s.due - T0 < 0.5 * DAY
    assert srs.level(s, T0) == "learning"


def test_fast_answer_is_stronger_evidence():
    fast = srs.review(srs.State(), "swipe_known", T0, elapsed_ms=800)
    slow = srs.review(srs.State(), "swipe_known", T0, elapsed_ms=12000)
    assert fast.stability > slow.stability


def test_due_when_recall_hits_target():
    s = srs.review(srs.State(), "quiz_correct", T0)
    assert abs(srs.retrievability(s, s.due) - srs.TARGET_R) < 1e-9


def test_mastery_decays_without_review():
    s = srs.review(srs.State(), "swipe_known", T0)
    assert srs.mastery(s, T0 + 30 * DAY) < srs.mastery(s, T0)


def test_spacing_effect_reviewing_later_grows_more():
    s = srs.review(srs.State(), "quiz_correct", T0)
    early = srs.review(s, "quiz_correct", T0 + 0.1 * DAY)
    on_time = srs.review(s, "quiz_correct", s.due)
    assert on_time.stability > early.stability > s.stability


def test_lapse_cuts_stability():
    s = srs.State(stability=20, reps=4, lapses=0, last_review=T0, due=T0 + 20 * DAY)
    after = srs.review(s, "quiz_wrong", T0 + 10 * DAY)
    assert after.stability == 6.0
    assert after.lapses == 1 and after.reps == 4


def test_repeated_quiz_success_reaches_mastered():
    s, now = srs.State(), T0
    for _ in range(8):
        s = srs.review(s, "quiz_correct", now)
        now = s.due
    assert srs.level(s, s.last_review) == "mastered"


def test_stability_capped():
    s = srs.State(stability=300, reps=10, lapses=0, last_review=T0, due=T0 + 300 * DAY)
    assert srs.review(s, "quiz_correct", T0 + 300 * DAY).stability == srs.MAX_STABILITY
