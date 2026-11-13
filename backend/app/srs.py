"""Mastery model (spaced repetition).

Every (user, item, target language) has a memory *stability* S, in days.
Recall probability decays as  R(t) = 0.85 ** (t / S)  — i.e. S is exactly the
number of days until the predicted recall drops to 85 %, which is when the item
becomes due again.

Mastery shown to the user (0–100) = 100 · S/(S+7) · R(now):
  * the S/(S+7) part grows with long-term memory strength (S=7d → 50, S=28d → 80),
  * the R part makes it fade when the item hasn't been reviewed for a while.

A review either succeeds or fails, with a *weight* that reflects how trustworthy
the signal is (a self-reported swipe is weaker evidence than a correct quiz
answer). Success multiplies S by 1 + w·(0.6 + 3·(1−R)): reviewing an item that
was close to being forgotten (low R) grows it more — the spacing effect.
Failure cuts S to 30 %.
"""
from __future__ import annotations

from dataclasses import asdict, dataclass

DAY = 86400.0
TARGET_R = 0.85
MAX_STABILITY = 365.0
HALF_MASTERY_DAYS = 7.0


@dataclass
class State:
    stability: float = 0.0
    reps: int = 0  # number of successful reviews
    lapses: int = 0  # number of failed reviews
    last_review: float | None = None
    due: float | None = None

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass(frozen=True)
class Grade:
    success: bool
    weight: float  # strength of the evidence on success
    first_stability: float  # S assigned the first time the item is answered correctly


GRADES = {
    # Word cards (self-reported)
    "swipe_known": Grade(True, 0.5, 7.0),  # knew it at first sight → straight to "familiar"
    "swipe_known_peeked": Grade(True, 0.25, 1.0),  # looked at the meaning, then said "known"
    "swipe_unknown": Grade(False, 0.0, 0.0),
    # Quiz questions (objective)
    "quiz_correct": Grade(True, 1.0, 2.0),
    "quiz_wrong": Grade(False, 0.0, 0.0),
}

FIRST_FAIL_STABILITY = 0.2  # ≈ 5 h: a word you didn't know comes back later today
LAPSE_FACTOR = 0.3
MIN_STABILITY = 0.1


def retrievability(s: State, now: float) -> float:
    if s.last_review is None or s.stability <= 0:
        return 0.0
    days = max(0.0, (now - s.last_review) / DAY)
    return TARGET_R ** (days / s.stability)


def mastery(s: State, now: float) -> int:
    if s.last_review is None:
        return 0
    strength = s.stability / (s.stability + HALF_MASTERY_DAYS)
    return round(100 * strength * retrievability(s, now))


def level(s: State, now: float) -> str:
    if s.last_review is None:
        return "new"
    m = mastery(s, now)
    if m < 40:
        return "learning"
    if m < 80:
        return "familiar"
    return "mastered"


def speed_factor(elapsed_ms: int | None) -> float:
    """Answering instantly is stronger evidence than hesitating."""
    if elapsed_ms is None:
        return 1.0
    if elapsed_ms < 2000:
        return 1.2
    if elapsed_ms > 8000:
        return 0.7
    return 1.0


def review(s: State, grade_name: str, now: float, elapsed_ms: int | None = None) -> State:
    g = GRADES[grade_name]
    if g.success:
        f = speed_factor(elapsed_ms)
        if s.reps == 0 and s.lapses == 0:
            stability = g.first_stability * f
        else:
            r = retrievability(s, now)
            stability = max(s.stability, MIN_STABILITY) * (1 + g.weight * f * (0.6 + 3 * (1 - r)))
        reps, lapses = s.reps + 1, s.lapses
    else:
        if s.last_review is None:
            stability = FIRST_FAIL_STABILITY
        else:
            stability = max(MIN_STABILITY, s.stability * LAPSE_FACTOR)
        reps, lapses = s.reps, s.lapses + 1
    stability = min(stability, MAX_STABILITY)
    return State(stability=stability, reps=reps, lapses=lapses, last_review=now, due=now + stability * DAY)
