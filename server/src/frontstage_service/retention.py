"""Aufbewahrung: abgelaufene Rückmeldungen samt Bildern löschen (FR-18.2)."""

from datetime import datetime, timedelta

from .attachments import AttachmentStore
from .repository import FeedbackRepository


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
    if not expired:
        return 0
    with repository.transaction():
        deleted = [feedback_id for feedback_id in expired if repository.delete(feedback_id)]
    for feedback_id in deleted:
        attachments.delete_all(feedback_id)
    return len(deleted)
