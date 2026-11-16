"""CSRF-Schutz: Token in der Sitzung, geprüft über Formfeld oder Header (Entscheidung 9)."""

import hmac
import secrets

from fastapi import HTTPException, Request


def csrf_token(request: Request) -> str:
    """Liefert das Token der Sitzung und legt es bei Bedarf an."""
    token = request.session.get("csrf")
    if not isinstance(token, str) or not token:
        token = secrets.token_urlsafe(32)
        request.session["csrf"] = token
    return token


async def require_csrf(request: Request) -> None:
    """Abhängigkeit für jede POST-Route der Verwaltung; Fehler → 403."""
    expected = request.session.get("csrf")
    supplied = request.headers.get("X-CSRF-Token")
    if not supplied:
        # Starlette speichert das gelesene Formular; ``Form(...)``-Parameter funktionieren danach weiter.
        try:
            form = await request.form()
        except Exception:  # noqa: BLE001 - unlesbarer Körper gilt als fehlendes Token
            form = None
        value = form.get("csrf_token") if form is not None else None
        supplied = value if isinstance(value, str) else None
    if (
        not isinstance(expected, str)
        or not supplied
        or not hmac.compare_digest(expected.encode(), supplied.encode())
    ):
        raise HTTPException(status_code=403, detail="Ungültiges oder fehlendes CSRF-Token.")
