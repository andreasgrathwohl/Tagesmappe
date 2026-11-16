"""Sicherheitsheader für jede Antwort."""

from starlette.datastructures import MutableHeaders
from starlette.types import ASGIApp, Message, Receive, Scope, Send

HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "X-Frame-Options": "DENY",
}


# Entscheidung 10: nur eigene Quellen, keine Inline-Skripte
ADMIN_CSP = (
    "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; "
    "frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
)


class SecurityHeadersMiddleware:
    """Reine ASGI-Middleware (kein BaseHTTPMiddleware), damit Streaming unberührt bleibt."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        is_admin = scope["path"] == "/admin" or scope["path"].startswith("/admin/")

        async def send_with_headers(message: Message) -> None:
            if message["type"] == "http.response.start":
                headers = MutableHeaders(scope=message)
                for name, value in HEADERS.items():
                    headers[name] = value
                if is_admin:
                    headers["Content-Security-Policy"] = ADMIN_CSP
            await send(message)

        await self.app(scope, receive, send_with_headers)
