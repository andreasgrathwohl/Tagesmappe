"""Aufbewahrung: abgelaufene Rückmeldungen samt Bildern löschen (FR-18.2)."""

from datetime import datetime, timedelta
from uuid import UUID

from .attachments import AttachmentStore
from .repository import FeedbackRepository

STAGING_MAX_AGE = timedelta(hours=1)


def purge_expired(
    repository: FeedbackRepository,
    attachments: AttachmentStore,
    *,
    now: datetime,
    retention_days: int,
) -> int:
    """Löscht alles, was älter als ``retention_days`` ist; gibt die Anzahl zurück.

    Genau ``retention_days`` alt bleibt erhalten (strikt älter wird gelöscht).
    Erst COMMIT der Datensätze, dann die Bilder: Bleibt nach einem Absturz ein Ordner übrig,
    ist er nur Ballast; ein Datensatz mit fehlenden Bildern wäre dagegen ein sichtbarer Fehler.
    """
    expired = repository.expired_ids(now - timedelta(days=retention_days))
    deleted: list[UUID] = []
    if expired:
        with repository.transaction():
            deleted = [feedback_id for feedback_id in expired if repository.delete(feedback_id)]
        for feedback_id in deleted:
            attachments.delete_all(feedback_id)
    sweep_leftovers(repository, attachments, now=now)
    return len(deleted)


def sweep_leftovers(repository: FeedbackRepository, attachments: AttachmentStore, *, now: datetime) -> None:
    """Räumt Reste nach Abstürzen weg, damit keine Bilder länger als erlaubt liegen bleiben.

    - Staging-Ordner älter als ``STAGING_MAX_AGE``: Die Annahme braucht Sekunden; ein so alter Ordner
      gehört zu keiner laufenden Anfrage mehr (Absturz zwischen Speichern und Veröffentlichen).
    - Bilderordner ohne Datensatz: Absturz nach dem COMMIT eines Löschens, vor dem Entfernen der Bilder.
      Ein neuer Ordner hat seinen Datensatz immer schon (Veröffentlichen erst nach dem COMMIT).
    """
    for feedback_id in attachments.stale_staging_ids(older_than=(now - STAGING_MAX_AGE).timestamp()):
        attachments.discard(feedback_id)
    for feedback_id in attachments.published_ids():
        if repository.get(feedback_id) is None:
            attachments.delete_all(feedback_id)
