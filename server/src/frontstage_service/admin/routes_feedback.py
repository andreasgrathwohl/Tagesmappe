"""Routen der Verwaltung: Liste, Detail, Bearbeitungsstand, Notiz, Löschen, Bilder."""

from datetime import datetime
from math import ceil
from typing import Annotated
from urllib.parse import urlencode
from uuid import UUID
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Form, HTTPException, Request
from fastapi.responses import FileResponse, HTMLResponse, RedirectResponse, Response

from ..deps import AttachmentStoreDep, RepositoryDep
from ..models import FeedbackFilter, FeedbackKind, FeedbackRecord, FeedbackStatus
from ..repository import MAX_NOTE_LENGTH, FeedbackRepository
from .auth import AdminSessionDep
from .csrf import csrf_token, require_csrf
from .export import to_csv, to_json
from .filters import parse_filter
from .templating import templates

router = APIRouter(prefix="/admin", tags=["admin"])

PAGE_SIZE = 50
PREVIEW_LENGTH = 100
BERLIN = ZoneInfo("Europe/Berlin")
NO_STORE = {"Cache-Control": "no-store"}

KIND_LABELS = {FeedbackKind.idea: "Idee", FeedbackKind.issue: "Hinweis"}
STATUS_LABELS = {
    FeedbackStatus.new: "Neu",
    FeedbackStatus.in_progress: "In Arbeit",
    FeedbackStatus.done: "Erledigt",
    FeedbackStatus.rejected: "Verworfen",
}
MEDIA_TYPES = {".png": "image/png", ".jpg": "image/jpeg"}


def _local(value: datetime) -> datetime:
    return value.astimezone(BERLIN)


def _preview(text: str) -> str:
    flat = " ".join(text.split())
    return flat if len(flat) <= PREVIEW_LENGTH else flat[:PREVIEW_LENGTH].rstrip() + "…"


def _row(record: FeedbackRecord) -> dict:
    local = _local(record.received_at)
    return {
        "id": record.id,
        "date": local.strftime("%d.%m.%Y"),
        "time": local.strftime("%H:%M"),
        "kind": KIND_LABELS[record.kind],
        "status": STATUS_LABELS[record.status],
        "status_key": record.status.value,
        "topic": record.topic,
        "images": record.attachment_count,
        "preview": _preview(record.text),
    }


def _uuid_or_404(value: str) -> UUID:
    try:
        return UUID(value)
    except ValueError:
        raise HTTPException(status_code=404) from None


def _page_number(value: str | None) -> int:
    try:
        return max(1, int(value)) if value else 1
    except ValueError:
        return 1


def _is_htmx(request: Request) -> bool:
    # Bei Verlaufswiederherstellung (Zurück-Taste ohne Snapshot) sendet htmx 2
    # zusätzlich HX-Request, erwartet aber eine vollständige Seite.
    if request.headers.get("HX-History-Restore-Request") == "true":
        return False
    return request.headers.get("HX-Request") == "true"


@router.get("/", response_class=HTMLResponse)
def feedback_list(
    request: Request,
    _: AdminSessionDep,
    repository: RepositoryDep,
    kind: str | None = None,
    status: str | None = None,
    since: str | None = None,
    until: str | None = None,
    page: str | None = None,
    deleted: str | None = None,
) -> Response:
    feedback_filter = parse_filter(kind, status, since, until)
    wanted = _page_number(page)
    records, total = repository.list(feedback_filter, limit=PAGE_SIZE, offset=(wanted - 1) * PAGE_SIZE)
    pages = max(1, ceil(total / PAGE_SIZE))
    if wanted > pages:  # Seite hinter dem Ende: letzte Seite zeigen
        wanted = pages
        records, total = repository.list(feedback_filter, limit=PAGE_SIZE, offset=(wanted - 1) * PAGE_SIZE)

    active = {
        "kind": feedback_filter.kind.value if feedback_filter.kind else "",
        "status": feedback_filter.status.value if feedback_filter.status else "",
        "since": feedback_filter.since.isoformat() if feedback_filter.since else "",
        "until": feedback_filter.until.isoformat() if feedback_filter.until else "",
    }

    def page_url(number: int) -> str:
        params = {k: v for k, v in active.items() if v}
        if number > 1:
            params["page"] = str(number)
        return "/admin/" + (f"?{urlencode(params)}" if params else "")

    context = {
        "csrf_token": csrf_token(request),
        "logged_in": True,
        "rows": [_row(r) for r in records],
        "total": total,
        "filtered": any(active.values()),
        "active": active,
        "page": wanted,
        "pages": pages,
        "prev_url": page_url(wanted - 1) if wanted > 1 else None,
        "next_url": page_url(wanted + 1) if wanted < pages else None,
        "export_query": urlencode({k: v for k, v in active.items() if v}),
        "kind_labels": {k.value: v for k, v in KIND_LABELS.items()},
        "status_labels": {k.value: v for k, v in STATUS_LABELS.items()},
        "deleted": deleted if deleted and len(deleted) <= 16 and deleted.isalnum() else None,
    }
    template = "admin/_table.html" if _is_htmx(request) else "admin/list.html"
    return templates.TemplateResponse(request, template, context, headers=NO_STORE)


def _export_response(
    request: Request, repository: FeedbackRepository, feedback_filter: FeedbackFilter, extension: str
) -> Response:
    # limit=-1: in SQLite „ohne Grenze“; die Ausfuhr kennt keine Seiten.
    records, _ = repository.list(feedback_filter, limit=-1, offset=0)
    if extension == "csv":
        body, media_type = to_csv(records), "text/csv; charset=utf-8"
    else:
        body, media_type = to_json(records), "application/json"
    day = _local(request.app.state.clock()).strftime("%Y-%m-%d")
    headers = {
        **NO_STORE,
        "Content-Disposition": f'attachment; filename="frontstage-rueckmeldungen-{day}.{extension}"',
    }
    return Response(body, media_type=media_type, headers=headers)


@router.get("/export.csv")
def export_csv(
    request: Request,
    _: AdminSessionDep,
    repository: RepositoryDep,
    kind: str | None = None,
    status: str | None = None,
    since: str | None = None,
    until: str | None = None,
) -> Response:
    return _export_response(request, repository, parse_filter(kind, status, since, until), "csv")


@router.get("/export.json")
def export_json(
    request: Request,
    _: AdminSessionDep,
    repository: RepositoryDep,
    kind: str | None = None,
    status: str | None = None,
    since: str | None = None,
    until: str | None = None,
) -> Response:
    return _export_response(request, repository, parse_filter(kind, status, since, until), "json")


def _record_or_404(repository: RepositoryDep, feedback_id: str) -> FeedbackRecord:
    record = repository.get(_uuid_or_404(feedback_id))
    if record is None:
        raise HTTPException(status_code=404, detail="Rückmeldung nicht gefunden.")
    return record


@router.get("/feedback/{feedback_id}", response_class=HTMLResponse)
def feedback_detail(
    request: Request,
    feedback_id: str,
    _: AdminSessionDep,
    repository: RepositoryDep,
    store: AttachmentStoreDep,
    saved: str | None = None,
) -> Response:
    record = _record_or_404(repository, feedback_id)
    context = {
        "csrf_token": csrf_token(request),
        "logged_in": True,
        "record": record,
        "received": _local(record.received_at).strftime("%d.%m.%Y, %H:%M Uhr"),
        "kind": KIND_LABELS[record.kind],
        "status_labels": {k.value: v for k, v in STATUS_LABELS.items()},
        "positions": [int(p.stem) for p in store.paths(record.id)],
        "device_info": sorted(record.device_info.items()) if record.device_info else None,
        "max_note": MAX_NOTE_LENGTH,
        "saved": saved if saved in ("status", "note") else None,
    }
    return templates.TemplateResponse(request, "admin/detail.html", context, headers=NO_STORE)


def _saved_response(request: Request, record: FeedbackRecord, what: str) -> Response:
    if _is_htmx(request):
        return templates.TemplateResponse(request, "admin/_saved.html", {"saved": what}, headers=NO_STORE)
    return RedirectResponse(f"/admin/feedback/{record.id}?saved={what}", status_code=303)


@router.post("/feedback/{feedback_id}/status", dependencies=[Depends(require_csrf)])
def set_status(
    request: Request,
    feedback_id: str,
    _: AdminSessionDep,
    repository: RepositoryDep,
    status: Annotated[str, Form()] = "",
) -> Response:
    record = _record_or_404(repository, feedback_id)
    try:
        new_status = FeedbackStatus(status)
    except ValueError:
        raise HTTPException(status_code=400, detail="Unbekannter Bearbeitungsstand.") from None
    repository.set_status(record.id, new_status)
    return _saved_response(request, record, "status")


@router.post("/feedback/{feedback_id}/note", dependencies=[Depends(require_csrf)])
def set_note(
    request: Request,
    feedback_id: str,
    _: AdminSessionDep,
    repository: RepositoryDep,
    note: Annotated[str, Form()] = "",
) -> Response:
    record = _record_or_404(repository, feedback_id)
    note = note.replace("\r\n", "\n")
    if len(note) > MAX_NOTE_LENGTH:
        raise HTTPException(
            status_code=400, detail=f"Die Notiz darf höchstens {MAX_NOTE_LENGTH} Zeichen lang sein."
        )
    repository.set_note(record.id, note)
    return _saved_response(request, record, "note")


@router.get("/feedback/{feedback_id}/delete", response_class=HTMLResponse)
def delete_confirmation(
    request: Request, feedback_id: str, _: AdminSessionDep, repository: RepositoryDep
) -> Response:
    """Bestätigungsseite; funktioniert ohne JavaScript und löscht selbst nie."""
    record = _record_or_404(repository, feedback_id)
    context = {"csrf_token": csrf_token(request), "logged_in": True, "record": record}
    return templates.TemplateResponse(request, "admin/delete.html", context, headers=NO_STORE)


@router.post("/feedback/{feedback_id}/delete", dependencies=[Depends(require_csrf)])
def delete_feedback(
    feedback_id: str, _: AdminSessionDep, repository: RepositoryDep, store: AttachmentStoreDep
) -> Response:
    record = _record_or_404(repository, feedback_id)
    with repository.transaction():
        repository.delete(record.id)
    store.delete_all(record.id)  # nach dem COMMIT, wie im Aufräumlauf
    return RedirectResponse(f"/admin/?deleted={record.reference}", status_code=303)


@router.get("/attachments/{feedback_id}/{position}")
def attachment(
    feedback_id: str,
    position: str,
    _: AdminSessionDep,
    repository: RepositoryDep,
    store: AttachmentStoreDep,
) -> Response:
    record = _record_or_404(repository, feedback_id)
    try:
        number = int(position)
    except ValueError:
        raise HTTPException(status_code=404) from None
    path = store.path(record.id, number)
    if path is None:
        raise HTTPException(status_code=404)
    return FileResponse(
        path,
        media_type=MEDIA_TYPES.get(path.suffix, "application/octet-stream"),
        headers={"Cache-Control": "private, no-store"},
    )
