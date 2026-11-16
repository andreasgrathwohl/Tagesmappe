"""Abhängigkeiten der Routen: was ``create_app`` in ``app.state`` ablegt, dazu die Verbindung je Anfrage."""

from collections.abc import Iterator
from typing import Annotated

from fastapi import Depends, Request

from .attachments import AttachmentStore
from .db import open_connection
from .ratelimit import SlidingWindowLimiter
from .repository import FeedbackRepository
from .settings import Settings


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


def get_repository(request: Request) -> Iterator[FeedbackRepository]:
    """Je Anfrage eine eigene Verbindung samt Repository; danach geschlossen.

    Eine geteilte Verbindung ließe die Anweisungen paralleler Anfragen in fremde Transaktionen
    laufen: Ein ROLLBACK dort nähme eine bereits bestätigte Änderung mit.
    """
    connection = open_connection(request.app.state.settings.data_dir)
    try:
        yield FeedbackRepository(connection, request.app.state.clock)
    finally:
        connection.close()


def get_attachment_store(request: Request) -> AttachmentStore:
    return request.app.state.attachment_store


def get_limiter(request: Request) -> SlidingWindowLimiter:
    return request.app.state.limiter


SettingsDep = Annotated[Settings, Depends(get_settings)]
RepositoryDep = Annotated[FeedbackRepository, Depends(get_repository)]
AttachmentStoreDep = Annotated[AttachmentStore, Depends(get_attachment_store)]
LimiterDep = Annotated[SlidingWindowLimiter, Depends(get_limiter)]
