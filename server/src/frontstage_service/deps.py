"""Abhängigkeiten der Routen: alles, was ``create_app`` in ``app.state`` ablegt."""

from typing import Annotated

from fastapi import Depends, Request

from .attachments import AttachmentStore
from .ratelimit import SlidingWindowLimiter
from .repository import FeedbackRepository
from .settings import Settings


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


def get_repository(request: Request) -> FeedbackRepository:
    return request.app.state.repository


def get_attachment_store(request: Request) -> AttachmentStore:
    return request.app.state.attachment_store


def get_limiter(request: Request) -> SlidingWindowLimiter:
    return request.app.state.limiter


SettingsDep = Annotated[Settings, Depends(get_settings)]
RepositoryDep = Annotated[FeedbackRepository, Depends(get_repository)]
AttachmentStoreDep = Annotated[AttachmentStore, Depends(get_attachment_store)]
LimiterDep = Annotated[SlidingWindowLimiter, Depends(get_limiter)]
