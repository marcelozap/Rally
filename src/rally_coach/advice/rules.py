"""Coaching advice.

Rule-based on purpose. Every note names the metric that triggered it and the
threshold it crossed, so you can argue with the coaching rather than trusting a
black box. Thresholds are first-draft guesses — tune them against real footage
before showing this to anyone who actually plays.

Adding a rule: write a function returning Note | None, add it to RULES.
"""
from __future__ import annotations

from collections.abc import Callable

from rally_coach.core.types import Analysis, Note

Rule = Callable[[Analysis], Note | None]

# --- thresholds (UNTUNED — see docs/TUNING.md) -------------------------------
ELBOW_STRAIGHT_DEG = 160.0     # above this at contact = arming the ball
KNEE_STIFF_DEG = 165.0         # above this on average = not loading the legs
LOW_SEPARATION_DEG = 20.0      # below this = little torso coil
LOW_COM_RANGE = 0.03           # normalised — below this = static feet


def _rule_elbow_extension(a: Analysis) -> Note | None:
    v = a.metrics.get("mean_elbow_angle_at_contact")
    if v is None or v < ELBOW_STRAIGHT_DEG:
        return None
    return Note(
        code="elbow_locked_at_contact",
        title="Arm is locking out at contact",
        detail=(
            f"Mean elbow angle at contact is {v:.0f}deg (flag above {ELBOW_STRAIGHT_DEG:.0f}deg). "
            "A fully straight arm at contact usually means the swing is coming from the "
            "shoulder rather than a rotating body. Try letting the elbow stay slightly "
            "bent and driving from the hips."
        ),
        severity="suggest",
        confidence=0.65,
        swing_ids=[s.id for s in a.swings],
    )


def _rule_leg_load(a: Analysis) -> Note | None:
    v = a.metrics.get("mean_knee_angle")
    if v is None or v < KNEE_STIFF_DEG:
        return None
    return Note(
        code="legs_not_loading",
        title="Legs staying straight",
        detail=(
            f"Mean knee angle across the clip is {v:.0f}deg (flag above {KNEE_STIFF_DEG:.0f}deg). "
            "Very little knee bend means power is coming from the upper body alone. "
            "Bend into the shot and push up through contact."
        ),
        severity="fix",
        confidence=0.7,
    )


def _rule_torso_separation(a: Analysis) -> Note | None:
    v = a.metrics.get("mean_separation_at_contact")
    if v is None or v > LOW_SEPARATION_DEG:
        return None
    return Note(
        code="low_torso_separation",
        title="Shoulders and hips rotating together",
        detail=(
            f"Shoulder-hip separation at contact averages {v:.0f}deg "
            f"(flag below {LOW_SEPARATION_DEG:.0f}deg). When the torso turns as one block "
            "you lose the elastic load that generates racket speed. Turn the shoulders "
            "earlier and let the hips lead the uncoil."
        ),
        severity="suggest",
        confidence=0.6,
    )


def _rule_footwork(a: Analysis) -> Note | None:
    v = a.metrics.get("com_lateral_range")
    if v is None or v > LOW_COM_RANGE or a.metrics.get("swing_count", 0) < 2:
        return None
    return Note(
        code="static_feet",
        title="Not moving into the ball",
        detail=(
            f"Center-of-mass moved {v:.3f} laterally across the whole clip "
            f"(flag below {LOW_COM_RANGE}). You're swinging from a planted stance. "
            "Add a split-step and step into contact."
        ),
        severity="fix",
        confidence=0.55,
    )


RULES: list[Rule] = [
    _rule_elbow_extension,
    _rule_leg_load,
    _rule_torso_separation,
    _rule_footwork,
]


def advise(analysis: Analysis, max_notes: int = 3, min_confidence: float = 0.6) -> list[Note]:
    """Run all rules, keep the confident ones, return the most severe few.

    Capped deliberately: a list of twelve corrections is not coaching.
    """
    notes = [n for rule in RULES if (n := rule(analysis)) and n.confidence >= min_confidence]
    order = {"fix": 0, "suggest": 1, "info": 2}
    notes.sort(key=lambda n: (order.get(n.severity, 9), -n.confidence))
    return notes[:max_notes]
