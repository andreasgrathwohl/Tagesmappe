"""SQLite-Verbindung und Schema-Migrationen (Version in PRAGMA user_version)."""

import sqlite3
from pathlib import Path

# Nummerierte Migrationen; Index + 1 = Zielversion. Nie ändern, nur anhängen.
_MIGRATIONS: list[str] = [
    """
    CREATE TABLE feedback (
        id TEXT PRIMARY KEY,
        client_draft_id TEXT NOT NULL UNIQUE,
        reference TEXT NOT NULL UNIQUE,
        received_at TEXT NOT NULL,
        kind TEXT NOT NULL,
        text TEXT NOT NULL,
        topic TEXT,
        app_version TEXT NOT NULL,
        device_info TEXT,
        status TEXT NOT NULL DEFAULT 'new',
        note TEXT NOT NULL DEFAULT '',
        attachment_count INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
    );
    CREATE INDEX idx_feedback_received_at ON feedback (received_at);
    CREATE INDEX idx_feedback_status ON feedback (status);
    CREATE INDEX idx_feedback_kind ON feedback (kind);
    """,
]


def _migrate(connection: sqlite3.Connection) -> None:
    version = connection.execute("PRAGMA user_version").fetchone()[0]
    for target, script in enumerate(_MIGRATIONS, start=1):
        if target <= version:
            continue
        # Skript samt Versionsnummer in einer Transaktion (Autocommit-Verbindung, daher explizit)
        connection.executescript(f"BEGIN;\n{script}\nPRAGMA user_version = {target};\nCOMMIT;")


def connect(data_dir: Path) -> sqlite3.Connection:
    """Öffnet (und migriert) die Datenbank unter ``data_dir``.

    ``check_same_thread=False``, weil def-Endpunkte und ``run_in_threadpool`` in anderen Threads
    laufen; ``isolation_level=None`` (Autocommit), Transaktionen steuert das Repository selbst.
    """
    data_dir.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(
        data_dir / "frontstage.db", check_same_thread=False, isolation_level=None, timeout=10
    )
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA journal_mode = WAL")
    connection.execute("PRAGMA foreign_keys = ON")
    _migrate(connection)
    return connection
