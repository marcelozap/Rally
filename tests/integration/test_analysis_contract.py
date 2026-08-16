"""The analysis.v1 contract with rally-app.

rally-coach writes this file; rally-app reads it; neither imports the other. The
only thing stopping the two repos drifting apart is that the shipped schema stays
put and the writer keeps matching it. Both halves are asserted here.
"""
from __future__ import annotations

import json
import re

import pytest

from conftest import SCHEMA_PATH
from rally_coach.core.types import Analysis
from rally_coach.export import writer

jsonschema = pytest.importorskip("jsonschema", reason="pip install -e .[dev]")


# --- the writer matches the schema -------------------------------------------
def test_pipeline_output_validates_against_the_frozen_schema(analysis, schema):
    jsonschema.validate(instance=writer.to_dict(analysis), schema=schema)


def test_output_with_notes_validates_too(flawed_analysis, schema):
    """The empty-notes case passing tells you nothing about the notes branch."""
    assert flawed_analysis.notes
    jsonschema.validate(instance=writer.to_dict(flawed_analysis), schema=schema)


def test_written_file_is_valid_json_and_valid_schema(analysis, schema, tmp_path):
    path = writer.write(analysis, tmp_path / "runs" / "analysis.json")
    assert path.exists()
    jsonschema.validate(instance=json.loads(path.read_text(encoding="utf-8")), schema=schema)


def test_write_then_read_round_trips(analysis, tmp_path):
    path = writer.write(analysis, tmp_path / "analysis.json")
    assert writer.read(path).model_dump(mode="json") == analysis.model_dump(mode="json")


def test_version_is_stamped_on_every_analysis(analysis):
    assert analysis.schema_version == writer.SCHEMA_VERSION == "analysis.v1"


def test_reader_refuses_a_version_it_does_not_support(analysis, tmp_path):
    payload = writer.to_dict(analysis) | {"schema_version": "analysis.v2"}
    path = tmp_path / "future.json"
    path.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(ValueError, match=re.escape("analysis.v2")):
        writer.read(path)


def test_types_can_rebuild_an_analysis_from_the_written_dict(analysis):
    assert Analysis.model_validate(writer.to_dict(analysis)) == analysis


# --- the schema itself has not been edited in place --------------------------
# These are canaries, not style checks. analysis.v1 is frozen: if a change to the
# contract is needed it becomes analysis.v2 in a NEW file. Editing v1 in place is
# how rally-coach and rally-app silently stop agreeing, and the failure shows up
# on the Swift side, months later, as a decoding error nobody can source.
FROZEN_TOP_LEVEL_REQUIRED = [
    "schema_version",
    "clip",
    "fps",
    "frame_count",
    "duration_s",
    "swings",
    "metrics",
    "notes",
]
FROZEN_SWING_REQUIRED = ["id", "type", "start_frame", "contact_frame", "end_frame"]
FROZEN_NOTE_REQUIRED = ["code", "title", "detail", "severity", "confidence"]
FROZEN_SWING_TYPES = ["forehand", "backhand", "serve", "unknown"]
FROZEN_SEVERITIES = ["info", "suggest", "fix"]
FROZEN_ID = "https://xiv.dev/schemas/analysis.v1.json"


@pytest.fixture(scope="module")
def raw_schema() -> dict:
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


def test_schema_identity_is_unchanged(raw_schema):
    assert raw_schema["$id"] == FROZEN_ID
    assert raw_schema["properties"]["schema_version"]["const"] == "analysis.v1"


def test_schema_required_fields_are_unchanged(raw_schema):
    assert raw_schema["required"] == FROZEN_TOP_LEVEL_REQUIRED
    assert raw_schema["properties"]["swings"]["items"]["required"] == FROZEN_SWING_REQUIRED
    assert raw_schema["properties"]["notes"]["items"]["required"] == FROZEN_NOTE_REQUIRED


def test_schema_enums_are_unchanged(raw_schema):
    swing_type = raw_schema["properties"]["swings"]["items"]["properties"]["type"]["enum"]
    severity = raw_schema["properties"]["notes"]["items"]["properties"]["severity"]["enum"]
    assert swing_type == FROZEN_SWING_TYPES
    assert severity == FROZEN_SEVERITIES


def test_the_schema_itself_is_a_valid_json_schema(raw_schema):
    jsonschema.Draft202012Validator.check_schema(raw_schema)


# --- the types and the schema agree ------------------------------------------
def test_every_swing_type_the_code_can_emit_is_allowed_by_the_schema(raw_schema):
    from rally_coach.core.types import SwingType

    allowed = set(raw_schema["properties"]["swings"]["items"]["properties"]["type"]["enum"])
    assert {t.value for t in SwingType} == allowed


def test_every_handedness_the_code_can_emit_is_allowed_by_the_schema(raw_schema):
    from rally_coach.core.types import Handedness

    allowed = set(raw_schema["properties"]["handedness"]["enum"])
    assert {h.value for h in Handedness} == allowed
