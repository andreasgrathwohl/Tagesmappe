"""App-Fabrik."""

from collections.abc import Callable
from datetime import UTC, datetime

from fastapi import FastAPI

from .security_headers import SecurityHeadersMiddleware
from .settings import Settings


def utc_now() -> datetime:
    return datetime.now(UTC)


def create_app(settings: Settings, *, clock: Callable[[], datetime] = utc_now) -> FastAPI:
    # Kein öffentlicher Schnittstellenkatalog: Docs und OpenAPI aus.
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    app.state.settings = settings
    app.state.clock = clock
    app.add_middleware(SecurityHeadersMiddleware)

    @app.get("/healthz")
    def healthz() -> dict[str, str]:
        return {"status": "ok"}

    return app
