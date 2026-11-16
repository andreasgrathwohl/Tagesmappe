"""Annahme der Rückmeldungen aus der App (FR-18)."""

import hmac
import logging
import sqlite3
from typing import Literal

from fastapi import APIRouter, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import JSONResponse
from pydantic import ValidationError
from starlette.datastructures import UploadFile
from starlette.exceptions import HTTPException

from .attachments import AttachmentStore
from .deps import AttachmentStoreDep, LimiterDep, RepositoryDep, SettingsDep
from .images import MAX_IMAGE_BYTES, ImageRejected, clean_image
from .models import FeedbackIn, FeedbackRecord, Receipt
from .repository import FeedbackRepository

router = APIRouter(prefix="/api/v1", tags=["feedback"])
logger = logging.getLogger("frontstage_service.feedback")

MAX_BODY_BYTES = 26 * 1024 * 1024
MAX_IMAGES_TOTAL_BYTES = 25 * 1024 * 1024
MAX_ATTACHMENTS = 5
MAX_FEEDBACK_PART_BYTES = 65_536


def _error(status_code: int, detail: str, headers: dict[str, str] | None = None) -> JSONResponse:
    return JSONResponse({"detail": detail}, status_code=status_code, headers=headers)


def _receipt(record: FeedbackRecord, status_code: int) -> JSONResponse:
    receipt = Receipt(id=record.id, reference=record.reference)
    return JSONResponse(receipt.model_dump(mode="json"), status_code=status_code)


def _store(
    repository: FeedbackRepository,
    store: AttachmentStore,
    feedback: FeedbackIn,
    cleaned: list[tuple[bytes, Literal["png", "jpg"]]],
) -> tuple[FeedbackRecord, int] | None:
    """Speichert Datensatz und Bilder (blockierend, für den Threadpool).

    Ergebnis: Datensatz mit 201 (neu) oder 200 (gleichzeitige Wiederholung); ``None`` heißt 503.
    """
    record: FeedbackRecord | None = None
    try:
        with repository.transaction():
            record = repository.insert(feedback, len(cleaned))
            for position, (data, extension) in enumerate(cleaned):
                store.save(record.id, position, data, extension)
    except sqlite3.IntegrityError:
        # Gleichzeitige Wiederholung derselben clientDraftId
        if record is not None:
            store.discard(record.id)
        existing = repository.find_by_client_draft_id(feedback.clientDraftId)
        return (existing, 200) if existing is not None else None
    except (OSError, sqlite3.OperationalError):
        if record is not None:
            store.discard(record.id)
        logger.warning("feedback storage failed")
        return None

    if cleaned:
        try:
            store.publish(record.id)
        except OSError:
            # Datensatz ist gespeichert; die Bilder fehlen. Nicht ablehnen, sonst käme eine Dublette.
            logger.error("feedback attachments could not be published reference=%s", record.reference)
    return record, 201


@router.post("/feedback")
async def receive_feedback(
    request: Request,
    settings: SettingsDep,
    repository: RepositoryDep,
    store: AttachmentStoreDep,
    limiter: LimiterDep,
) -> JSONResponse:
    # 1. Schlüssel (konstante Zeit; Bytes, weil compare_digest bei Nicht-ASCII-Text sonst abbricht)
    given = request.headers.get("X-Frontstage-App-Key", "").encode()
    if not hmac.compare_digest(given, settings.app_key.encode()):
        return _error(401, "Ungültiger Schlüssel.")

    # 2. Begrenzung je Absender (nach dem Schlüssel: falsche Schlüssel verbrauchen kein Kontingent)
    client_host = request.client.host if request.client else "unknown"
    wait = limiter.check(client_host)
    if wait is not None:
        return _error(429, "Zu viele Anfragen.", {"Retry-After": str(wait)})

    # 3. Größe vorab, ohne den Rumpf zu lesen; ohne Content-Length (chunked) wäre die
    #    Obergrenze umgehbar, die App sendet die Angabe immer
    raw_length = request.headers.get("content-length")
    if raw_length is None:
        return _error(411, "Die Angabe der Länge fehlt.")
    try:
        declared = int(raw_length)
    except ValueError:
        return _error(422, "Ungültige Anfrage.")
    if declared > MAX_BODY_BYTES:
        return _error(413, "Die Anfrage ist zu groß.")

    # 4. Multipart lesen (Entscheidung 7); Starlette meldet Grenzüberschreitungen als 400
    try:
        form = await request.form(
            max_files=MAX_ATTACHMENTS, max_fields=1, max_part_size=MAX_FEEDBACK_PART_BYTES
        )
    except HTTPException as exc:
        if "Too many files" in str(exc.detail):
            return _error(413, "Zu viele Bilder (höchstens 5).")
        return _error(422, "Ungültige Anfrage.")

    try:
        part = form.get("feedback")
        if not isinstance(part, str):
            return _error(422, "Der Teil feedback fehlt.")
        try:
            feedback = FeedbackIn.model_validate_json(part)
        except ValidationError:
            return _error(422, "Ungültige Rückmeldung.")

        # 5. Wiederholung nach verlorener Antwort: vorhandene Quittung, Bilder ignorieren
        existing = await run_in_threadpool(repository.find_by_client_draft_id, feedback.clientDraftId)
        if existing is not None:
            return _receipt(existing, 200)

        # 6. Bilder prüfen und neu kodieren
        uploads = [item for item in form.getlist("attachment") if isinstance(item, UploadFile)]
        if len(uploads) > MAX_ATTACHMENTS:
            return _error(413, "Zu viele Bilder (höchstens 5).")
        raw_images: list[bytes] = []
        total = 0
        for upload in uploads:
            if upload.size is not None and upload.size > MAX_IMAGE_BYTES:
                return _error(413, "Das Bild ist größer als 8 MiB.")
            data = await upload.read()
            total += len(data)
            if total > MAX_IMAGES_TOTAL_BYTES:
                return _error(413, "Die Bilder sind zusammen größer als 25 MiB.")
            raw_images.append(data)
        cleaned: list[tuple[bytes, Literal["png", "jpg"]]] = []
        try:
            for data in raw_images:
                # Pillow rechnet CPU-lastig: nicht im Ereignisschleifen-Thread
                cleaned.append(await run_in_threadpool(clean_image, data))
        except ImageRejected as exc:
            return _error(exc.status_code, exc.reason)

        # 7. Eine Transaktion; Bilder erst nach COMMIT veröffentlichen. SQLite und bis zu 25 MiB
        #    Dateiarbeit im Threadpool, damit die Ereignisschleife (auch /healthz) frei bleibt.
        outcome = await run_in_threadpool(_store, repository, store, feedback, cleaned)
        if outcome is None:
            return _error(503, "Vorübergehend nicht verfügbar.", {"Retry-After": "30"})
        record, status_code = outcome
        if status_code == 201:
            logger.info("feedback received reference=%s attachments=%d", record.reference, len(cleaned))
        return _receipt(record, status_code)
    finally:
        await form.close()
