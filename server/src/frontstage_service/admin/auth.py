"""Anmeldung: Passwortprüfung und Sitzungsschutz der Verwaltung."""

from typing import Annotated
from urllib.parse import quote

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError
from fastapi import Depends, HTTPException, Request

LOGIN_PATH = "/admin/login"
ADMIN_HOME = "/admin/"

_hasher = PasswordHasher()


def verify_password(password_hash: str, password: str) -> bool:
    """Prüft das Passwort gegen den Argon2-Hash; jeder Fehler (auch ein kaputter Hash) ergibt False."""
    try:
        return _hasher.verify(password_hash, password)
    except (VerificationError, InvalidHashError):
        return False


def safe_next(value: str | None) -> str:
    """Erlaubt nur relative Pfade unterhalb von /admin (keine offene Umleitung)."""
    if not value or not value.startswith("/admin"):
        return ADMIN_HOME
    rest = value[len("/admin") :]
    if rest and rest[0] not in "/?":
        return ADMIN_HOME
    if "\\" in value or ".." in value or any(ord(c) < 32 for c in value):
        return ADMIN_HOME
    return value


def is_logged_in(request: Request) -> bool:
    return request.session.get("admin") is True


def require_admin(request: Request) -> None:
    """Abhängigkeit: ohne Sitzung 303 auf die Anmeldung, bei htmx 401 mit ``HX-Redirect``."""
    if is_logged_in(request):
        return
    target = request.url.path
    if request.url.query:
        target += "?" + request.url.query
    location = f"{LOGIN_PATH}?next={quote(target, safe='')}"
    if request.headers.get("HX-Request") == "true":
        raise HTTPException(status_code=401, headers={"HX-Redirect": location})
    raise HTTPException(status_code=303, headers={"Location": location})


AdminSessionDep = Annotated[None, Depends(require_admin)]
