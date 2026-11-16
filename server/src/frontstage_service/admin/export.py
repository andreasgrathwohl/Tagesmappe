"""Ausfuhr der Rückmeldungen als CSV und JSON (FR-18.1, Entscheidung 11)."""

import csv
import io
import json
from collections.abc import Iterable

from ..models import FeedbackRecord

COLUMNS = (
    "reference",
    "received_at",
    "kind",
    "status",
    "topic",
    "app_version",
    "attachment_count",
    "text",
    "note",
)
# Zellen mit diesen Anfangszeichen würden Tabellenprogramme als Formel auslegen.
FORMULA_PREFIXES = ("=", "+", "-", "@", "\t", "\r")
UTF8_BOM = b"\xef\xbb\xbf"


def _neutralise(value: str) -> str:
    return "'" + value if value.startswith(FORMULA_PREFIXES) else value


def _fields(record: FeedbackRecord) -> dict:
    return {
        "reference": record.reference,
        "received_at": record.received_at.isoformat().replace("+00:00", "Z"),
        "kind": record.kind.value,
        "status": record.status.value,
        "topic": record.topic or "",
        "app_version": record.app_version,
        "attachment_count": record.attachment_count,
        "text": record.text,
        "note": record.note,
    }


def to_csv(records: Iterable[FeedbackRecord]) -> bytes:
    """UTF-8 mit BOM, Trennzeichen Semikolon; Formelanfänge werden mit ' entschärft."""
    buffer = io.StringIO(newline="")
    writer = csv.writer(buffer, delimiter=";", lineterminator="\r\n", quoting=csv.QUOTE_MINIMAL)
    writer.writerow(COLUMNS)
    for record in records:
        fields = _fields(record)
        writer.writerow([_neutralise(v) if isinstance(v, str) else v for v in (fields[c] for c in COLUMNS)])
    return UTF8_BOM + buffer.getvalue().encode("utf-8")


def to_json(records: Iterable[FeedbackRecord]) -> bytes:
    """Liste von Objekten mit denselben Feldern plus device_info (unverändert, kein Formelschutz nötig)."""
    items = [{**_fields(r), "device_info": r.device_info} for r in records]
    return json.dumps(items, ensure_ascii=False, indent=2).encode("utf-8")
