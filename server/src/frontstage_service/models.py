"""Datenmodelle des Rückmeldedienstes (Vertrag mit der App, Teilplan 11 und 12)."""

from dataclasses import dataclass
from datetime import date, datetime
from enum import StrEnum
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class FeedbackKind(StrEnum):
    idea = "idea"
    issue = "issue"


class FeedbackStatus(StrEnum):
    new = "new"
    in_progress = "inProgress"
    done = "done"
    rejected = "rejected"


class DeviceInfoIn(BaseModel):
    """Geräteangaben, die die App freiwillig mitsendet (Feldnamen wörtlich wie im Vertrag)."""

    model_config = ConfigDict(extra="forbid")

    appVersion: str  # noqa: N815
    build: str
    systemName: str  # noqa: N815
    systemVersion: str  # noqa: N815
    modelIdentifier: str  # noqa: N815
    dataLocation: Literal["iCloud", "oneDrive"]  # noqa: N815
    baseTone: Literal["warm", "system", "cool", "petrol"]  # noqa: N815
    accent: Annotated[str, Field(pattern=r"^#[0-9A-F]{6}$")] | None
    appearanceMode: Literal["system", "light", "dark"]  # noqa: N815
    isUnlocked: bool  # noqa: N815
    languageCode: Annotated[str, Field(max_length=8)]  # noqa: N815


# Die 21 Rohwerte von HelpTopic (Teilplan 11, Task 1)
HelpTopic = Literal[
    "gettingStarted",
    "dayView",
    "openingMaterial",
    "penNotes",
    "secondScreen",
    "classScreen",
    "board",
    "preparation",
    "coursePlan",
    "timetable",
    "bellSchedule",
    "nonTeachingDays",
    "schoolYears",
    "schulmanager",
    "storage",
    "dataLocation",
    "pairing",
    "appearance",
    "purchase",
    "privacy",
    "feedback",
]


class FeedbackIn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    clientDraftId: UUID  # noqa: N815
    kind: FeedbackKind
    text: Annotated[str, Field(min_length=1, max_length=10_000)]
    topic: HelpTopic | None
    appVersion: Annotated[str, Field(max_length=32)]  # noqa: N815
    deviceInfo: DeviceInfoIn | None  # noqa: N815

    @field_validator("text")
    @classmethod
    def _text_not_blank(cls, value: str) -> str:
        # Wie die App (canSend): mindestens ein Zeichen außer Leerraum. Gespeichert wird der Text unverändert.
        if not value.strip():
            raise ValueError("Der Text besteht nur aus Leerraum.")
        return value


class Receipt(BaseModel):
    id: UUID
    reference: str


@dataclass(frozen=True)
class FeedbackRecord:
    id: UUID
    client_draft_id: UUID
    reference: str
    received_at: datetime
    kind: FeedbackKind
    text: str
    topic: str | None
    app_version: str
    device_info: dict | None
    status: FeedbackStatus
    note: str
    attachment_count: int
    updated_at: datetime


@dataclass(frozen=True)
class FeedbackFilter:
    kind: FeedbackKind | None = None
    status: FeedbackStatus | None = None
    since: date | None = None
    until: date | None = None  # einschließlich (bis Tagesende UTC)
