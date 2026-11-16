import sqlite3
from datetime import UTC, date, datetime
from pathlib import Path
from uuid import uuid4

import pytest
from pydantic import ValidationError

from frontstage_service.db import connect
from frontstage_service.models import FeedbackFilter, FeedbackIn, FeedbackKind, FeedbackStatus
from frontstage_service.repository import REFERENCE_ALPHABET, FeedbackRepository


@pytest.fixture
def conn(tmp_path: Path):
    connection = connect(tmp_path / "data")
    yield connection
    connection.close()


@pytest.fixture
def repo(conn, clock) -> FeedbackRepository:
    return FeedbackRepository(conn, clock)


def make(kind: str = "idea", text: str = "Text", **extra) -> FeedbackIn:
    return FeedbackIn.model_validate(
        {
            "clientDraftId": str(uuid4()),
            "kind": kind,
            "text": text,
            "topic": None,
            "appVersion": "0.1.0 (1)",
            "deviceInfo": None,
            **extra,
        }
    )


def test_insert_and_get_roundtrip(repo, clock):
    device = {
        "appVersion": "0.1.0",
        "build": "1",
        "systemName": "iPadOS",
        "systemVersion": "26.1",
        "modelIdentifier": "iPad14,5",
        "dataLocation": "iCloud",
        "baseTone": "warm",
        "accent": None,
        "appearanceMode": "system",
        "isUnlocked": False,
        "languageCode": "de",
    }
    fb = make("issue", "Tafel speichert nicht", topic="board", deviceInfo=device)
    record = repo.insert(fb, attachment_count=2)
    loaded = repo.get(record.id)
    assert loaded == record
    assert loaded.client_draft_id == fb.clientDraftId
    assert loaded.kind is FeedbackKind.issue
    assert loaded.status is FeedbackStatus.new
    assert loaded.topic == "board" and loaded.attachment_count == 2 and loaded.note == ""
    assert loaded.device_info == device
    assert loaded.received_at == clock.now and loaded.updated_at == clock.now
    assert repo.find_by_client_draft_id(fb.clientDraftId) == record
    assert repo.find_by_client_draft_id(uuid4()) is None
    assert repo.get(uuid4()) is None


def test_duplicate_client_draft_id_raises(repo):
    fb = make()
    repo.insert(fb, 0)
    with pytest.raises(sqlite3.IntegrityError):
        repo.insert(fb, 0)


def test_reference_format_and_unique(repo):
    refs = [repo.insert(make(), 0).reference for _ in range(200)]
    assert len(set(refs)) == 200
    assert all(len(r) == 8 and set(r) <= set(REFERENCE_ALPHABET) for r in refs)


def test_list_newest_first_with_total(repo, clock):
    ids = []
    for hour in (9, 10, 11):
        clock.now = datetime(2026, 11, 16, hour, 0, tzinfo=UTC)
        ids.append(repo.insert(make(), 0).id)
    items, total = repo.list(FeedbackFilter(), limit=2, offset=0)
    assert total == 3 and [r.id for r in items] == [ids[2], ids[1]]
    items, total = repo.list(FeedbackFilter(), limit=2, offset=2)
    assert total == 3 and [r.id for r in items] == [ids[0]]


def test_filter_by_kind_status_and_dates(repo, clock):
    clock.now = datetime(2026, 11, 14, 8, 0, tzinfo=UTC)
    a = repo.insert(make("idea"), 0)
    clock.now = datetime(2026, 11, 15, 23, 59, 59, tzinfo=UTC)
    b = repo.insert(make("issue"), 0)
    clock.now = datetime(2026, 11, 16, 0, 0, tzinfo=UTC)
    c = repo.insert(make("issue"), 0)
    repo.set_status(c.id, FeedbackStatus.done)

    def ids(f: FeedbackFilter) -> set:
        return {r.id for r in repo.list(f, limit=50, offset=0)[0]}

    assert ids(FeedbackFilter(kind=FeedbackKind.issue)) == {b.id, c.id}
    assert ids(FeedbackFilter(status=FeedbackStatus.done)) == {c.id}
    assert ids(FeedbackFilter(since=date(2026, 11, 15))) == {b.id, c.id}
    # until ist einschließlich: 23:59:59 am 15. zählt, 00:00 am 16. nicht
    assert ids(FeedbackFilter(until=date(2026, 11, 15))) == {a.id, b.id}
    both = FeedbackFilter(since=date(2026, 11, 15), until=date(2026, 11, 15), kind=FeedbackKind.issue)
    assert ids(both) == {b.id}
    _, total = repo.list(FeedbackFilter(kind=FeedbackKind.idea), limit=1, offset=0)
    assert total == 1


def test_set_status_and_note_persist(repo, clock):
    record = repo.insert(make(), 0)
    clock.now = datetime(2026, 11, 17, 9, 0, tzinfo=UTC)
    assert repo.set_status(record.id, FeedbackStatus.in_progress)
    assert repo.set_note(record.id, "Rückruf folgt – äöü")
    loaded = repo.get(record.id)
    assert loaded.status is FeedbackStatus.in_progress
    assert loaded.note == "Rückruf folgt – äöü"
    assert loaded.updated_at == clock.now and loaded.received_at != clock.now
    assert not repo.set_status(uuid4(), FeedbackStatus.done)
    assert not repo.set_note(uuid4(), "x")
    repo.set_note(record.id, "x" * 5_000)
    with pytest.raises(ValueError):
        repo.set_note(record.id, "x" * 5_001)


def test_delete_removes_row(repo):
    record = repo.insert(make(), 0)
    assert repo.delete(record.id)
    assert repo.get(record.id) is None
    assert not repo.delete(record.id)


def test_expired_ids(repo, clock):
    clock.now = datetime(2025, 11, 15, 10, 0, tzinfo=UTC)
    old = repo.insert(make(), 0)
    clock.now = datetime(2026, 11, 15, 10, 0, tzinfo=UTC)
    repo.insert(make(), 0)
    assert repo.expired_ids(datetime(2025, 11, 16, tzinfo=UTC)) == [old.id]


def test_schema_has_no_address_column(conn):
    names = [r["name"].lower() for r in conn.execute("PRAGMA table_info(feedback)")]
    assert names
    assert not [n for n in names if "ip" in n or "addr" in n]


def test_wal_mode_and_version(conn):
    assert conn.execute("PRAGMA journal_mode").fetchone()[0] == "wal"
    assert conn.execute("PRAGMA foreign_keys").fetchone()[0] == 1
    assert conn.execute("PRAGMA user_version").fetchone()[0] == 1


def test_database_file_name_matches_architecture(tmp_path):
    # docs/ARCHITECTURE.md, Area dienst: Volume /data mit frontstage.sqlite3
    connect(tmp_path).close()
    assert (tmp_path / "frontstage.sqlite3").is_file()


def test_reconnect_keeps_data_and_migrates_once(tmp_path):
    first = connect(tmp_path)
    FeedbackRepository(first, lambda: datetime.now(UTC)).insert(make(), 0)
    first.close()
    second = connect(tmp_path)
    assert second.execute("SELECT COUNT(*) FROM feedback").fetchone()[0] == 1
    second.close()


def test_transaction_rolls_back_on_error(repo, conn):
    with pytest.raises(RuntimeError), repo.transaction():
        repo.insert(make(), 0)
        raise RuntimeError("Speicher voll")
    assert conn.execute("SELECT COUNT(*) FROM feedback").fetchone()[0] == 0
    with repo.transaction():
        repo.insert(make(), 0)
    assert conn.execute("SELECT COUNT(*) FROM feedback").fetchone()[0] == 1


def test_feedback_in_rejects_unknown_fields():
    with pytest.raises(ValidationError):
        make(extra="x")
    with pytest.raises(ValidationError):
        make(topic="unbekannt")
    with pytest.raises(ValidationError):
        make(text="")
    with pytest.raises(ValidationError):
        make(text="x" * 10_001)


def test_feedback_in_accepts_contract_example():
    json_text = (
        '{"appVersion":"0.1.0 (1)","clientDraftId":"8F14E45F-CEEA-467A-9B36-3C2D9F1E0A11",'
        '"deviceInfo":{"accent":null,"appVersion":"0.1.0","appearanceMode":"system","baseTone":"warm",'
        '"build":"1","dataLocation":"iCloud","isUnlocked":false,"languageCode":"de",'
        '"modelIdentifier":"iPad14,5","systemName":"iPadOS","systemVersion":"26.1"},'
        '"kind":"issue","text":"Tafel speichert nicht","topic":"board"}'
    )
    fb = FeedbackIn.model_validate_json(json_text)
    assert fb.kind is FeedbackKind.issue and fb.topic == "board" and fb.deviceInfo.accent is None
    with_accent = json_text.replace('"accent":null', '"accent":"#1A2B3C"')
    assert FeedbackIn.model_validate_json(with_accent).deviceInfo.accent == "#1A2B3C"
    with pytest.raises(ValidationError):
        FeedbackIn.model_validate_json(json_text.replace('"accent":null', '"accent":"#1a2b3c"'))
