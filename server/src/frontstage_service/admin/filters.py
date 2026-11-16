"""Filter der Liste aus den Abfrageparametern; Ungültiges wird ignoriert, nie ein Fehler."""

from datetime import date

from ..models import FeedbackFilter, FeedbackKind, FeedbackStatus


def _kind_or_none(value: str | None) -> FeedbackKind | None:
    try:
        return FeedbackKind(value) if value else None
    except ValueError:
        return None


def _status_or_none(value: str | None) -> FeedbackStatus | None:
    try:
        return FeedbackStatus(value) if value else None
    except ValueError:
        return None


def _date_or_none(value: str | None) -> date | None:
    try:
        return date.fromisoformat(value) if value else None
    except ValueError:
        return None


def parse_filter(
    kind: str | None, status: str | None, since: str | None, until: str | None
) -> FeedbackFilter:
    return FeedbackFilter(
        kind=_kind_or_none(kind),
        status=_status_or_none(status),
        since=_date_or_none(since),
        until=_date_or_none(until),
    )
