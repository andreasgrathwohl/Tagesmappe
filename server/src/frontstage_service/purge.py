"""Aufräumen auf Zuruf: ``python -m frontstage_service.purge``."""

import os
from datetime import UTC, datetime

from .attachments import AttachmentStore
from .db import connect
from .repository import FeedbackRepository
from .retention import purge_expired
from .settings import Settings


def main() -> None:
    settings = Settings.from_env(os.environ)
    connection = connect(settings.data_dir)
    try:
        repository = FeedbackRepository(connection, lambda: datetime.now(UTC))
        store = AttachmentStore(settings.data_dir / "attachments")
        count = purge_expired(
            repository, store, now=datetime.now(UTC), retention_days=settings.retention_days
        )
    finally:
        connection.close()
    print(f"{count} Rückmeldungen gelöscht")  # noqa: T201


if __name__ == "__main__":
    main()
