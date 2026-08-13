from rally_coach.advice.rules import advise
from rally_coach.core.types import Analysis


def _analysis(**metrics: float) -> Analysis:
    return Analysis(clip="t.mp4", fps=60, frame_count=60, duration_s=1.0, metrics=metrics)


def test_locked_elbow_is_flagged():
    notes = advise(_analysis(mean_elbow_angle_at_contact=175.0))
    assert any(n.code == "elbow_locked_at_contact" for n in notes)


def test_good_form_produces_no_notes():
    notes = advise(_analysis(mean_elbow_angle_at_contact=140.0, mean_knee_angle=150.0,
                             mean_separation_at_contact=35.0, com_lateral_range=0.2))
    assert notes == []


def test_notes_are_capped_and_fixes_come_first():
    notes = advise(
        _analysis(mean_elbow_angle_at_contact=175.0, mean_knee_angle=175.0,
                  mean_separation_at_contact=5.0, com_lateral_range=0.001, swing_count=3),
        max_notes=2,
    )
    assert len(notes) == 2
    assert notes[0].severity == "fix"
