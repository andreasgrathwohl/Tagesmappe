from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from frontstage_service import purge
from frontstage_service.attachments import AttachmentStore
from frontstage_service.db import connect
from frontstage_service.main import create_app
from frontstage_service.models import FeedbackIn
from frontstage_service.repository import FeedbackRepository
from frontstage_service.retention import purge_expired

NOW = datetime(2026, 11, 16, 9, 0, 0, tzinfo=UTC)


def make() -> FeedbackIn:
    return FeedbackIn.model_validate(
        {
            "clientDraftId": str(uuid4()),
            "kind": "idea",
            "text": "Text",
            "topic": None,
            "appVersion": "0.1.0 (1)",
            "deviceInfo": None,
        }
    )


def add(repo: FeedbackRepository, store: AttachmentStore, clock, when: datetime):
    """Legt eine Rückmeldung mit einem Bild zum Zeitpunkt ``when`` an."""
    clock.now = when
    record = repo.insert(make(), attachment_count=1)
    store.save(record.id, 1, b"x", "png")
    store.publish(record.id)
    return record


@pytest.fixture
def env(tmp_path: Path, clock):
    connection = connect(tmp_path / "data")
    repo = FeedbackRepository(connection, clock)
    store = AttachmentStore(tmp_path / "data" / "attachments")
    yield repo, store, clock
    connection.close()


def test_ak63_deletes_older_than_retention_with_images(env):
    repo, store, clock = env
    old = add(repo, store, clock, datetime(2025, 11, 15, 9, 0, tzinfo=UTC))
    new = add(repo, store, clock, datetime(2026, 11, 15, 9, 0, tzinfo=UTC))
    assert store.paths(old.id)

    deleted = purge_expired(repo, store, now=NOW, retention_days=365)

    assert deleted == 1
    assert repo.get(old.id) is None
    assert store.paths(old.id) == []
    assert not (store._root / str(old.id)).exists()  # noqa: SLF001
    assert repo.get(new.id) is not None
    assert store.paths(new.id)


def test_boundary_exactly_retention_days_is_kept(env):
    repo, store, clock = env
    edge = add(repo, store, clock, NOW - timedelta(days=365))
    older = add(repo, store, clock, NOW - timedelta(days=365, microseconds=1))

    assert purge_expired(repo, store, now=NOW, retention_days=365) == 1
    assert repo.get(edge.id) is not None
    assert repo.get(older.id) is None


def test_purge_runs_on_startup(settings, clock):
    # Datensatz vorab in dieselbe Datenbank legen, dann App starten
    connection = connect(settings.data_dir)
    repo = FeedbackRepository(connection, clock)
    store = AttachmentStore(settings.data_dir / "attachments")
    old = add(repo, store, clock, datetime(2024, 5, 1, 9, 0, tzinfo=UTC))
    connection.close()
    clock.now = NOW

    with TestClient(create_app(settings, clock=clock)) as c:
        assert c.app.state.repository.get(old.id) is None
    assert not (settings.data_dir / "attachments" / str(old.id)).exists()


def test_purge_command_prints_count(capsys, monkeypatch, settings, clock):
    connection = connect(settings.data_dir)
    repo = FeedbackRepository(connection, clock)
    store = AttachmentStore(settings.data_dir / "attachments")
    add(repo, store, clock, datetime(2020, 1, 1, tzinfo=UTC))
    add(repo, store, clock, datetime(2021, 1, 1, tzinfo=UTC))
    connection.close()

    env = {
        "APP_KEY": settings.app_key,
        "SESSION_SECRET": settings.session_secret,
        "ADMIN_PASSWORD_HASH": settings.admin_password_hash,
        "DATA_DIR": str(settings.data_dir),
    }
    for key, value in env.items():
        monkeypatch.setenv(key, value)

    purge.main()

    assert capsys.readouterr().out.strip() == "2 Rückmeldungen gelöscht"
