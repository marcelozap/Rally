"""Domain types. Pure data, zero I/O, zero third-party model imports.

Everything downstream speaks these types, which is what lets the pose backend
be swapped without touching geometry, events, metrics, or advice.
"""
from __future__ import annotations

from collections.abc import Sequence
from enum import Enum

from pydantic import BaseModel, Field


class Joint(str, Enum):
    """Backend-neutral joint names. Each pose backend maps its own indices to these."""

    NOSE = "nose"
    L_SHOULDER = "left_shoulder"
    R_SHOULDER = "right_shoulder"
    L_ELBOW = "left_elbow"
    R_ELBOW = "right_elbow"
    L_WRIST = "left_wrist"
    R_WRIST = "right_wrist"
    L_HIP = "left_hip"
    R_HIP = "right_hip"
    L_KNEE = "left_knee"
    R_KNEE = "right_knee"
    L_ANKLE = "left_ankle"
    R_ANKLE = "right_ankle"


class Keypoint(BaseModel):
    """A single joint in one frame. x/y are normalised to [0,1] of frame size."""

    x: float
    y: float
    z: float = 0.0
    visibility: float = Field(default=1.0, ge=0.0, le=1.0)

    @property
    def xy(self) -> tuple[float, float]:
        return (self.x, self.y)


class PoseFrame(BaseModel):
    """One frame of detected pose."""

    index: int
    t: float  # seconds from clip start
    joints: dict[Joint, Keypoint] = Field(default_factory=dict)

    def get(self, joint: Joint) -> Keypoint | None:
        return self.joints.get(joint)

    def has(self, *joints: Joint, min_visibility: float = 0.5) -> bool:
        return all(
            (kp := self.joints.get(j)) is not None and kp.visibility >= min_visibility
            for j in joints
        )


class Handedness(str, Enum):
    RIGHT = "right"
    LEFT = "left"
    UNKNOWN = "unknown"


class SwingType(str, Enum):
    FOREHAND = "forehand"
    BACKHAND = "backhand"
    SERVE = "serve"
    UNKNOWN = "unknown"


class Swing(BaseModel):
    """One detected swing, in frame indices and seconds."""

    id: int
    type: SwingType = SwingType.UNKNOWN
    start_frame: int
    contact_frame: int
    end_frame: int
    start_t: float
    contact_t: float
    end_t: float
    peak_wrist_speed: float
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)


class Note(BaseModel):
    """One piece of coaching advice, tied to evidence."""

    code: str            # stable id, e.g. "contact_point_late"
    title: str
    detail: str
    severity: str        # info | suggest | fix
    confidence: float = Field(ge=0.0, le=1.0)
    swing_ids: list[int] = Field(default_factory=list)


class Analysis(BaseModel):
    """The complete output. This is the contract rally-app consumes."""

    schema_version: str = "analysis.v1"
    clip: str
    fps: float
    frame_count: int
    duration_s: float
    handedness: Handedness = Handedness.UNKNOWN
    swings: list[Swing] = Field(default_factory=list)
    metrics: dict[str, float] = Field(default_factory=dict)
    notes: list[Note] = Field(default_factory=list)


def frames_to_seconds(frames: Sequence[int], fps: float) -> list[float]:
    return [f / fps for f in frames]
