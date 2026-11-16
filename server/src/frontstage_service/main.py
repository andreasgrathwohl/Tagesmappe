"""App-Fabrik."""

import asyncio
import contextlib
import logging
import sqlite3
from collections.abc import AsyncIterator, Callable
from contextlib import asynccontextmanager
from datetime import UTC, datetime, timedelta

from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from starlette.middleware.sessions import SessionMiddleware

from .admin.routes_auth import router as admin_auth_router
from .admin.routes_feedback import router as admin_feedback_router
from .admin.templating import STATIC_DIR
from .api import router as feedback_router
from .attachments import AttachmentStore
from .db import connect, open_connection
from .ratelimit import SlidingWindowLimiter
from .repository import FeedbackRepository
from .retention import purge_expired
from .security_headers import SecurityHeadersMiddleware
from .settings import Settings

logger = logging.getLogger(__name__)

PURGE_INTERVAL_SECONDS = 24 * 60 * 60


def utc_now() -> datetime:
    return datetime.now(UTC)


def create_app(settings: Settings, *, clock: Callable[[], datetime] = utc_now) -> FastAPI:
    # Eigene Verbindung nur für Migration und Aufräumen; Anfragen öffnen je ihre eigene (deps.get_repository).
    connection = connect(settings.data_dir)

    def run_purge() -> None:
        """Blockierend: läuft im Thread, nie in der Ereignisschleife."""
        count = purge_expired(
            app.state.repository,
            app.state.attachment_store,
            now=clock(),
            retention_days=settings.retention_days,
        )
        if count:
            logger.info("%d abgelaufene Rückmeldungen gelöscht", count)
        app.state.limiter.sweep()
        app.state.login_limiter.sweep()

    async def run_purge_safely() -> None:
        # Ein Fehlschlag (etwa gesperrte Datenbank, weil das Aufräumkommando gleichzeitig läuft)
        # darf weder den Start verhindern noch die tägliche Schleife beenden.
        try:
            await asyncio.to_thread(run_purge)
        except Exception:  # noqa: BLE001
            logger.exception("Aufräumen fehlgeschlagen")

    async def purge_daily() -> None:
        while True:
            await asyncio.sleep(PURGE_INTERVAL_SECONDS)
            await run_purge_safely()

    @asynccontextmanager
    async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
        await run_purge_safely()  # einmal beim Start, bevor Anfragen kommen
        task = asyncio.create_task(purge_daily())
        try:
            yield
        finally:
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task
            connection.close()

    # Kein öffentlicher Schnittstellenkatalog: Docs und OpenAPI aus.
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None, lifespan=lifespan)
    app.state.settings = settings
    app.state.clock = clock
    # Nur Aufräumlauf (und Tests); Routen nutzen RepositoryDep mit eigener Verbindung je Anfrage
    app.state.connection = connection
    app.state.repository = FeedbackRepository(connection, clock)
    app.state.run_purge = run_purge
    app.state.attachment_store = AttachmentStore(settings.data_dir / "attachments")
    # 10 je Minute, 30 je Stunde (AK-61); nur im Speicher, je App
    app.state.limiter = SlidingWindowLimiter([(10, timedelta(minutes=1)), (30, timedelta(hours=1))], clock)
    # Anmeldung: 5 Fehlversuche je Adresse sperren 10 Minuten (AK-62)
    app.state.login_limiter = SlidingWindowLimiter([(5, timedelta(minutes=10))], clock)
    app.add_middleware(SecurityHeadersMiddleware)
    # Sitzung der Verwaltung (Entscheidung 8); HttpOnly setzt Starlette immer
    app.add_middleware(
        SessionMiddleware,
        secret_key=settings.session_secret,
        session_cookie="frontstage_admin",
        max_age=28_800,
        same_site="strict",
        https_only=settings.cookie_secure,
    )
    app.include_router(feedback_router)
    app.include_router(admin_auth_router)
    app.include_router(admin_feedback_router)
    app.mount("/admin/static", StaticFiles(directory=STATIC_DIR), name="admin-static")

    @app.get("/healthz")
    def healthz() -> JSONResponse:
        # Lesbarkeit der Datenbank prüfen, nicht nur dass der Prozess lebt (eigene Verbindung)
        try:
            probe = open_connection(settings.data_dir)
            try:
                probe.execute("SELECT COUNT(*) FROM feedback").fetchone()
            finally:
                probe.close()
        except sqlite3.Error:
            return JSONResponse({"status": "unavailable"}, status_code=503)
        return JSONResponse({"status": "ok"})

    # 308 statt der 307 des Frontends, über eigene Routen. Die Seite mit Schrägstrich wird ebenfalls explizit
    # ausgeliefert: sonst leitet der Router `/impressum/` zurück (redirect_slashes).
    for page in ("impressum", "datenschutz"):

        def redirect(page: str = page) -> RedirectResponse:
            return RedirectResponse(f"/{page}/", status_code=308)

        def serve(page: str = page) -> FileResponse:
            return FileResponse(settings.landing_dir / page / "index.html")

        app.add_api_route(f"/{page}", redirect, methods=["GET", "HEAD"], include_in_schema=False)
        app.add_api_route(f"/{page}/", serve, methods=["GET", "HEAD"], include_in_schema=False)

    # Entscheidung 13: Startseite als Frontend mit niedriger Priorität – /api, /admin und /healthz gehen vor.
    app.frontend("/", directory=settings.landing_dir)

    return app
