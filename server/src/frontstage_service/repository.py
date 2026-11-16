"""Datensätze der Rückmeldungen (reines SQL über stdlib sqlite3)."""

import builtins
import json
import secrets
import sqlite3
from collections.abc import Callable, Iterator
from contextlib import AbstractContextManager, contextmanager
from datetime import UTC, date, datetime, time, timedelta
from uuid import UUID, uuid4

from .models import FeedbackFilter, FeedbackIn, FeedbackKind, FeedbackRecord, FeedbackStatus

# Ohne 0/O/1/I, damit Kennungen am Telefon oder in Mails nicht verwechselt werden
REFERENCE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
REFERENCE_LENGTH = 8
MAX_NOTE_LENGTH = 5_000


def _to_iso(value: datetime) -> str:
    """Feste Form, damit der Textvergleich in SQL der Zeitordnung entspricht."""
    return value.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def _from_iso(value: str) -> datetime:
    return datetime.fromisoformat(value)


def _day_start(day: date) -> datetime:
    return datetime.combine(day, time.min, tzinfo=UTC)


def _record(row: sqlite3.Row) -> FeedbackRecord:
    return FeedbackRecord(
        id=UUID(row["id"]),
        client_draft_id=UUID(row["client_draft_id"]),
        reference=row["reference"],
        received_at=_from_iso(row["received_at"]),
        kind=FeedbackKind(row["kind"]),
        text=row["text"],
        topic=row["topic"],
        app_version=row["app_version"],
        device_info=json.loads(row["device_info"]) if row["device_info"] is not None else None,
        status=FeedbackStatus(row["status"]),
        note=row["note"],
        attachment_count=row["attachment_count"],
        updated_at=_from_iso(row["updated_at"]),
    )


class FeedbackRepository:
    """Gehört genau einer Verbindung, ihr Transaktionszähler nur ihr. Nie zwischen Anfragen teilen."""

    def __init__(self, connection: sqlite3.Connection, clock: Callable[[], datetime]) -> None:
        self._db = connection
        self._clock = clock
        self._depth = 0

    def transaction(self) -> AbstractContextManager[None]:
        """COMMIT am Ende, ROLLBACK bei Ausnahme. Ein innerer Aufruf läuft in der äußeren Transaktion mit."""
        return self._transaction()

    @contextmanager
    def _transaction(self) -> Iterator[None]:
        if self._depth:
            self._depth += 1
            try:
                yield
            finally:
                self._depth -= 1
            return
        self._db.execute("BEGIN IMMEDIATE")
        self._depth = 1
        try:
            yield
        except BaseException:
            self._db.execute("ROLLBACK")
            raise
        else:
            self._db.execute("COMMIT")
        finally:
            self._depth = 0

    def find_by_client_draft_id(self, client_draft_id: UUID) -> FeedbackRecord | None:
        row = self._db.execute(
            "SELECT * FROM feedback WHERE client_draft_id = ?", (str(client_draft_id),)
        ).fetchone()
        return _record(row) if row else None

    def _new_reference(self) -> str:
        while True:
            reference = "".join(secrets.choice(REFERENCE_ALPHABET) for _ in range(REFERENCE_LENGTH))
            taken = self._db.execute("SELECT 1 FROM feedback WHERE reference = ?", (reference,)).fetchone()
            if not taken:
                return reference

    def insert(self, feedback: FeedbackIn, attachment_count: int) -> FeedbackRecord:
        """Legt den Datensatz an; doppelte ``clientDraftId`` wirft ``sqlite3.IntegrityError``."""
        now = _to_iso(self._clock())
        new_id = uuid4()
        device_info = (
            json.dumps(feedback.deviceInfo.model_dump(), ensure_ascii=False, sort_keys=True)
            if feedback.deviceInfo is not None
            else None
        )
        self._db.execute(
            "INSERT INTO feedback (id, client_draft_id, reference, received_at, kind, text, topic,"
            " app_version, device_info, status, note, attachment_count, updated_at)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '', ?, ?)",
            (
                str(new_id),
                str(feedback.clientDraftId),
                self._new_reference(),
                now,
                feedback.kind.value,
                feedback.text,
                feedback.topic,
                feedback.appVersion,
                device_info,
                FeedbackStatus.new.value,
                attachment_count,
                now,
            ),
        )
        record = self.get(new_id)
        assert record is not None  # noqa: S101
        return record

    def get(self, id: UUID) -> FeedbackRecord | None:  # noqa: A002
        row = self._db.execute("SELECT * FROM feedback WHERE id = ?", (str(id),)).fetchone()
        return _record(row) if row else None

    def list(
        self,
        filter: FeedbackFilter,  # noqa: A002
        *,
        limit: int,
        offset: int,
    ) -> tuple[list[FeedbackRecord], int]:
        """Neueste zuerst; zweiter Wert ist die Gesamtzahl der Treffer ohne Seitenschnitt."""
        clauses: list[str] = []
        params: list[object] = []
        if filter.kind is not None:
            clauses.append("kind = ?")
            params.append(filter.kind.value)
        if filter.status is not None:
            clauses.append("status = ?")
            params.append(filter.status.value)
        if filter.since is not None:
            clauses.append("received_at >= ?")
            params.append(_to_iso(_day_start(filter.since)))
        if filter.until is not None:
            clauses.append("received_at < ?")
            params.append(_to_iso(_day_start(filter.until + timedelta(days=1))))
        where = f" WHERE {' AND '.join(clauses)}" if clauses else ""
        total = self._db.execute(f"SELECT COUNT(*) FROM feedback{where}", params).fetchone()[0]  # noqa: S608
        rows = self._db.execute(
            f"SELECT * FROM feedback{where} ORDER BY received_at DESC, rowid DESC LIMIT ? OFFSET ?",  # noqa: S608
            [*params, limit, offset],
        ).fetchall()
        return [_record(r) for r in rows], total

    def _update(self, id: UUID, column: str, value: str) -> bool:  # noqa: A002
        # column kommt nur aus dem eigenen Code (set_status, set_note), nie von außen
        cursor = self._db.execute(
            f"UPDATE feedback SET {column} = ?, updated_at = ? WHERE id = ?",  # noqa: S608
            (value, _to_iso(self._clock()), str(id)),
        )
        return cursor.rowcount > 0

    def set_status(self, id: UUID, status: FeedbackStatus) -> bool:  # noqa: A002
        return self._update(id, "status", FeedbackStatus(status).value)

    def set_note(self, id: UUID, note: str) -> bool:  # noqa: A002
        if len(note) > MAX_NOTE_LENGTH:
            raise ValueError(f"Die Notiz darf höchstens {MAX_NOTE_LENGTH} Zeichen lang sein.")
        return self._update(id, "note", note)

    def delete(self, id: UUID) -> bool:  # noqa: A002
        return self._db.execute("DELETE FROM feedback WHERE id = ?", (str(id),)).rowcount > 0

    def expired_ids(self, before: datetime) -> builtins.list[UUID]:  # list ist hier die Methode
        rows = self._db.execute(
            "SELECT id FROM feedback WHERE received_at < ?", (_to_iso(before),)
        ).fetchall()
        return [UUID(r["id"]) for r in rows]
