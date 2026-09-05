"""End-to-end: video -> pose -> smoothing -> swings -> metrics -> advice.

This is the integration test the scaffold was missing. It drives the real
`analyze()` over a real video file, with a scripted estimator standing in for
mediapipe so the run is deterministic and model-free.

What it deliberately does NOT do: assert that any coaching threshold is correct.
Those thresholds are untuned guesses (docs/TUNING.md) and a test that pinned
them would just freeze the guesses in place. Everything here is a structural
invariant that must hold whatever the thresholds end up being.
"""
from __future__ import annotations

import math
from itertools import pairwise

import pytest

from conftest import TEST_CONFIG
from fixtures.synthetic import (
    DROPPED_FRAMES,
    FOREHAND_CONTACT,
    FRAME_COUNT,
    SERVE_CONTACT,
    ScriptedPoseEstimator,
    scripted_rally,
)
from rally_coach.core.types import Handedness, SwingType
from rally_coach.events.swing import wrist_speeds
from rally_coach.pipeline import analyze, load_config
from rally_coach.tracking.smoothing import OneEuroPoseFilter

SWING_FLOOR = TEST_CONFIG["events"]["swing"]["min_wrist_speed"]
MIN_SEPARATION = TEST_CONFIG["events"]["swing"]["min_separation_frames"]
CONTACT_TOLERANCE_FRAMES = 6  # smoothing shifts the speed peak slightly


# --- clip metadata comes from io/video.py, not from the fixture --------------
def test_clip_metadata_survives_the_round_trip(analysis, clip_fps, clip_frames):
    assert analysis.frame_count == clip_frames
    assert math.isclose(analysis.fps, clip_fps, rel_tol=1e-3)
    assert math.isclose(analysis.duration_s, clip_frames / clip_fps, rel_tol=1e-3)
    assert analysis.clip.endswith("scripted_rally.mp4")


def test_every_frame_reaches_the_estimator(estimator, analysis):
    """Frame count is the video's; dropped detections must not shorten the clip."""
    assert estimator.seen == FRAME_COUNT
    assert analysis.frame_count == FRAME_COUNT


def test_dropped_detections_do_not_break_the_run(analysis):
    """Four frames report no person. The pipeline must skip them, not fall over."""
    assert DROPPED_FRAMES
    detected = {s.contact_frame for s in analysis.swings}
    assert not (detected & DROPPED_FRAMES)
    assert analysis.swings, "swings should still be found despite the detection gap"


def test_injected_estimator_is_not_closed_by_the_pipeline(estimator, analysis):
    """The caller constructed it, so the caller owns its lifecycle."""
    assert estimator.closed is False


# --- the analytical chain ----------------------------------------------------
def test_handedness_is_detected(analysis):
    assert analysis.handedness is Handedness.RIGHT


def test_both_swings_are_found_and_classified(analysis):
    assert [s.type for s in analysis.swings] == [SwingType.FOREHAND, SwingType.SERVE]


def test_contacts_land_where_the_script_puts_them(analysis):
    forehand, serve = analysis.swings
    assert abs(forehand.contact_frame - FOREHAND_CONTACT) <= CONTACT_TOLERANCE_FRAMES
    assert abs(serve.contact_frame - SERVE_CONTACT) <= CONTACT_TOLERANCE_FRAMES


@pytest.mark.parametrize("field", ["frame", "t"])
def test_each_swing_is_internally_ordered(analysis, field):
    for s in analysis.swings:
        start = getattr(s, f"start_{field}")
        contact = getattr(s, f"contact_{field}")
        end = getattr(s, f"end_{field}")
        assert start <= contact <= end


def test_swing_ids_are_sequential_and_ordered_in_time(analysis):
    assert [s.id for s in analysis.swings] == list(range(len(analysis.swings)))
    contacts = [s.contact_frame for s in analysis.swings]
    assert contacts == sorted(contacts)


def test_swings_respect_the_configured_refractory_period(analysis):
    contacts = [s.contact_frame for s in analysis.swings]
    gaps = [b - a for a, b in pairwise(contacts)]
    assert all(g >= MIN_SEPARATION for g in gaps)


def test_swing_speed_and_confidence_are_in_range(analysis):
    for s in analysis.swings:
        assert s.peak_wrist_speed >= SWING_FLOOR
        assert 0.0 <= s.confidence <= 1.0
    assert max(s.confidence for s in analysis.swings) == pytest.approx(1.0)


def test_timestamps_agree_with_the_frame_rate(analysis):
    for s in analysis.swings:
        assert s.contact_t == pytest.approx(s.contact_frame / analysis.fps, abs=1e-6)


# --- metrics -----------------------------------------------------------------
EXPECTED_METRIC_KEYS = {
    "swing_count",
    "mean_peak_wrist_speed",
    "max_peak_wrist_speed",
    "mean_swing_duration_s",
    "mean_elbow_angle_at_contact",
    "mean_separation_at_contact",
    "mean_knee_angle",
    "com_lateral_range",
    "com_vertical_range",
}


def test_metrics_are_complete_and_finite(analysis):
    assert set(analysis.metrics) >= EXPECTED_METRIC_KEYS
    assert all(isinstance(v, float) and math.isfinite(v) for v in analysis.metrics.values())


def test_swing_count_metric_matches_the_swing_list(analysis):
    assert analysis.metrics["swing_count"] == float(len(analysis.swings))


def test_angle_metrics_are_physically_possible(analysis):
    for key in ("mean_elbow_angle_at_contact", "mean_knee_angle", "mean_separation_at_contact"):
        assert 0.0 <= analysis.metrics[key] <= 180.0


def test_movement_metrics_are_non_degenerate(analysis):
    """A fixture that never moves would make every downstream metric meaningless."""
    assert analysis.metrics["com_lateral_range"] > 0.0
    assert analysis.metrics["com_vertical_range"] > 0.0


# --- advice ------------------------------------------------------------------
def test_clean_rally_produces_well_formed_notes(analysis):
    """Shape only. Whether the advice is RIGHT is a tuning question, not a test."""
    assert len(analysis.notes) <= TEST_CONFIG["advice"]["max_notes"]
    for n in analysis.notes:
        assert n.confidence >= TEST_CONFIG["advice"]["min_confidence"]


def test_flawed_technique_reaches_the_advice_stage(flawed_analysis):
    """Locked arm + straight legs + planted feet must produce SOMETHING, or the
    advice stage is silently unreachable from the pipeline."""
    assert flawed_analysis.notes
    assert len(flawed_analysis.notes) <= TEST_CONFIG["advice"]["max_notes"]


def test_notes_are_sorted_most_severe_first(flawed_analysis):
    order = {"fix": 0, "suggest": 1, "info": 2}
    ranks = [order[n.severity] for n in flawed_analysis.notes]
    assert ranks == sorted(ranks)


def test_notes_reference_real_swings(flawed_analysis):
    valid = {s.id for s in flawed_analysis.swings}
    for n in flawed_analysis.notes:
        assert set(n.swing_ids) <= valid


def test_note_codes_are_unique(flawed_analysis):
    codes = [n.code for n in flawed_analysis.notes]
    assert len(codes) == len(set(codes))


# --- determinism -------------------------------------------------------------
def test_two_runs_of_the_same_clip_agree(synthetic_clip, analysis):
    again = analyze(synthetic_clip, config=TEST_CONFIG, estimator=ScriptedPoseEstimator())
    assert again.model_dump(mode="json") == analysis.model_dump(mode="json")


def test_on_frame_fires_once_per_detected_frame(synthetic_clip):
    seen: list[int] = []
    analyze(
        synthetic_clip,
        config=TEST_CONFIG,
        on_frame=lambda i, _p: seen.append(i),
        estimator=ScriptedPoseEstimator(),
    )
    assert len(seen) == FRAME_COUNT - len(DROPPED_FRAMES)
    assert not (set(seen) & DROPPED_FRAMES)
    assert seen == sorted(seen)


# --- shipped defaults must preserve the contact spike -----------------------
def test_shipped_smoothing_preserves_the_contact_spike():
    cfg = load_config()
    smoothing = cfg["smoothing"]
    floor = cfg["events"]["swing"]["min_wrist_speed"]

    poses = scripted_rally()
    filt = OneEuroPoseFilter(
        min_cutoff=smoothing["min_cutoff"],
        beta=smoothing["beta"],
        d_cutoff=smoothing["d_cutoff"],
    )
    smoothed_peak = max(wrist_speeds([filt.apply(p) for p in poses], Handedness.RIGHT))
    assert smoothed_peak >= floor
