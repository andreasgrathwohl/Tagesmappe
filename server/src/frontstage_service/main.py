"""App-Fabrik."""

import sqlite3
from collections.abc import AsyncIterator, Callable
from contextlib import asynccontextmanager
from datetime import UTC, datetime, timedelta

from fastapi import FastAPI
from fastapi.responses import JSONResponse

from .api import router as feedback_router
from .attachments import AttachmentStore
from .db import connect
from .ratelimit import SlidingWindowLimiter
from .repository import FeedbackRepository
from .security_headers import SecurityHeadersMiddleware
from .settings import Settings


def utc_now() -> datetime:
    return datetime.now(UTC)


def create_app(settings: Settings, *, clock: Callable[[], datetime] = utc_now) -> FastAPI:
    connection = connect(settings.data_dir)

    @asynccontextmanager
    async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
        yield
        connection.close()

    # Kein öffentlicher Schnittstellenkatalog: Docs und OpenAPI aus.
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None, lifespan=lifespan)
    app.state.settings = settings
    app.state.clock = clock
    app.state.connection = connection
    app.state.repository = FeedbackRepository(connection, clock)
    app.state.attachment_store = AttachmentStore(settings.data_dir / "attachments")
    # 10 je Minute, 30 je Stunde (AK-61); nur im Speicher, je App
    app.state.limiter = SlidingWindowLimiter([(10, timedelta(minutes=1)), (30, timedelta(hours=1))], clock)
    app.add_middleware(SecurityHeadersMiddleware)
    app.include_router(feedback_router)

    @app.get("/healthz")
    def healthz() -> JSONResponse:
        # Lesbarkeit der Datenbank prüfen, nicht nur dass der Prozess lebt
        try:
            connection.execute("SELECT 1").fetchone()
        except sqlite3.Error:
            return JSONResponse({"status": "unavailable"}, status_code=503)
        return JSONResponse({"status": "ok"})

    return app
