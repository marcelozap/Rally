"""Writes the analysis contract consumed by rally-app.

THE RULE: analysis.v1 is frozen. Any breaking change becomes analysis.v2 with a
new schema file. rally-app reads a version it declares support for. Never edit
a shipped schema in place — that is how the two repos silently drift apart.
"""
from __future__ import annotations

import json
from pathlib import Path

from rally_coach.core.types import Analysis

SCHEMA_VERSION = "analysis.v1"


def to_dict(analysis: Analysis) -> dict:
    return analysis.model_dump(mode="json")


def write(analysis: Analysis, path: str | Path) -> Path:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(to_dict(analysis), indent=2), encoding="utf-8")
    return p


def read(path: str | Path) -> Analysis:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    version = data.get("schema_version")
    if version != SCHEMA_VERSION:
        raise ValueError(f"unsupported schema {version!r}, expected {SCHEMA_VERSION!r}")
    return Analysis.model_validate(data)
