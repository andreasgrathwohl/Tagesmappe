"""Routen: Anmeldung, Abmeldung und Startseite der Verwaltung."""

from math import ceil
from typing import Annotated

from fastapi import APIRouter, Depends, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse, Response

from ..deps import SettingsDep
from .auth import LOGIN_PATH, AdminSessionDep, is_logged_in, safe_next, verify_password
from .csrf import csrf_token, require_csrf
from .templating import templates

router = APIRouter(prefix="/admin", tags=["admin"])

NO_STORE = {"Cache-Control": "no-store"}


def _login_page(
    request: Request, *, next_path: str, error: str | None = None, status_code: int = 200
) -> Response:
    return templates.TemplateResponse(
        request,
        "admin/login.html",
        {"csrf_token": csrf_token(request), "next": next_path, "error": error, "logged_in": False},
        status_code=status_code,
        headers=NO_STORE,
    )


@router.get("/login", response_class=HTMLResponse)
def login_form(request: Request, next: str | None = None) -> Response:
    if is_logged_in(request):
        return RedirectResponse(safe_next(next), status_code=303)
    return _login_page(request, next_path=safe_next(next))


@router.post("/login", dependencies=[Depends(require_csrf)])
def login(
    request: Request,
    settings: SettingsDep,
    password: Annotated[str, Form()] = "",
    next: Annotated[str, Form()] = "",
) -> Response:
    limiter = request.app.state.login_limiter
    host = request.client.host if request.client else "unknown"
    next_path = safe_next(next)

    wait = limiter.blocked_for(host)
    if wait is not None:
        minutes = max(1, ceil(wait / 60))
        unit = "Minute" if minutes == 1 else "Minuten"
        return _login_page(
            request,
            next_path=next_path,
            error=f"Zu viele Versuche. Versuch es in {minutes} {unit} erneut.",
            status_code=429,
        )
    if not verify_password(settings.admin_password_hash, password):
        limiter.record(host)  # nur Fehlversuche zählen
        return _login_page(request, next_path=next_path, error="Passwort stimmt nicht.")

    # Neue Sitzung: alte Werte (auch das Vor-Anmelde-Token) verwerfen
    request.session.clear()
    request.session["admin"] = True
    request.session["login_at"] = request.app.state.clock().isoformat()
    csrf_token(request)
    return RedirectResponse(next_path, status_code=303)


@router.post("/logout", dependencies=[Depends(require_csrf)])
def logout(request: Request) -> Response:
    request.session.clear()
    return RedirectResponse(LOGIN_PATH, status_code=303)


@router.get("/", response_class=HTMLResponse)
def admin_home(request: Request, _: AdminSessionDep) -> Response:
    # Platzhalter bis zur Liste (Task 7)
    return templates.TemplateResponse(
        request,
        "admin/home.html",
        {"csrf_token": csrf_token(request), "logged_in": True},
        headers=NO_STORE,
    )
