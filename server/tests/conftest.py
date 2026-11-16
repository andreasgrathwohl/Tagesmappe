from collections.abc import Iterator
from datetime import UTC, datetime
from pathlib import Path

import pytest
from argon2 import PasswordHasher
from fastapi.testclient import TestClient

from frontstage_service.main import create_app
from frontstage_service.settings import Settings

LANDING_DIR = Path(__file__).resolve().parents[1] / "landing"


class Clock:
    """Verstellbare Uhr für Tests."""

    def __init__(self) -> None:
        self.now = datetime(2026, 11, 16, 9, 0, 0, tzinfo=UTC)

    def __call__(self) -> datetime:
        return self.now


@pytest.fixture
def settings(tmp_path: Path) -> Settings:
    return Settings(
        app_key="test-app-key-" + "x" * 20,
        admin_password_hash=PasswordHasher().hash("richtiges-passwort"),
        session_secret="test-session-secret-" + "y" * 20,
        data_dir=tmp_path / "data",
        landing_dir=LANDING_DIR,
        cookie_secure=True,
    )


@pytest.fixture
def clock() -> Clock:
    return Clock()


@pytest.fixture
def client(settings: Settings, clock: Clock) -> Iterator[TestClient]:
    # Nur als Kontextmanager läuft der lifespan; Umleitungen werden bewusst nicht verfolgt.
    with TestClient(
        create_app(settings, clock=clock), base_url="https://testserver", follow_redirects=False
    ) as c:
        yield c
