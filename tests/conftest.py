"""Shared fixtures for the test suite.

pytest puts this file's own directory on sys.path, which is what makes
`from fixtures.synthetic import ...` work here without any path juggling inside
the individual test modules.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from fixtures.synthetic import (
    FPS,
    FRAME_COUNT,
    ScriptedPoseEstimator,
    flawed_rally,
    render_clip,
)
from rally_coach import export as _export
from rally_coach.pipeline import analyze

SCHEMA_PATH = Path(_export.__file__).parent / "schema" / "analysis.v1.json"

# The integration tests pin their own config on purpose. `config/pipeline.yaml`
# is about to be calibrated against real footage (docs/TUNING.md), and that
# calibration must not show up here as a test failure. These tests assert on the
# SHAPE of the contract; they deliberately assert nothing about whether any
# particular threshold value is correct.
TEST_CONFIG: dict = {
    "video": {"max_dimension": 640},
    "smoothing": {"min_cutoff": 6.0, "beta": 0.05, "d_cutoff": 1.0},
    "events": {"swing": {"min_wrist_speed": 2.0, "min_separation_frames": 12}},
    "advice": {"max_notes": 3, "min_confidence": 0.6},
}


@pytest.fixture(scope="session")
def schema() -> dict:
    """The frozen analysis.v1 contract, read from the shipped package."""
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


@pytest.fixture(scope="session")
def synthetic_clip(tmp_path_factory: pytest.TempPathFactory) -> Path:
    """A real 3s video, rendered to a tmp dir. Never written into the repo."""
    return render_clip(tmp_path_factory.mktemp("clips") / "scripted_rally.mp4")


@pytest.fixture(scope="session")
def estimator() -> ScriptedPoseEstimator:
    return ScriptedPoseEstimator()


@pytest.fixture(scope="session")
def analysis(synthetic_clip: Path, estimator: ScriptedPoseEstimator):
    """One full pipeline run over the clean rally. Session-scoped: run once, assert often."""
    return analyze(synthetic_clip, config=TEST_CONFIG, estimator=estimator)


@pytest.fixture(scope="session")
def flawed_analysis(synthetic_clip: Path):
    """Same two swings, bad technique — the run that actually produces notes."""
    return analyze(
        synthetic_clip,
        config=TEST_CONFIG,
        estimator=ScriptedPoseEstimator(flawed_rally()),
    )


@pytest.fixture(scope="session")
def clip_fps() -> float:
    return FPS


@pytest.fixture(scope="session")
def clip_frames() -> int:
    return FRAME_COUNT
