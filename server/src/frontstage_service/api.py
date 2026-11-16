"""Annahme der Rückmeldungen aus der App (FR-18)."""

import hmac
import logging
import sqlite3

from fastapi import APIRouter, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import JSONResponse
from pydantic import ValidationError
from starlette.datastructures import UploadFile
from starlette.exceptions import HTTPException

from .deps import AttachmentStoreDep, LimiterDep, RepositoryDep, SettingsDep
from .images import MAX_IMAGE_BYTES, ImageRejected, clean_image
from .models import FeedbackIn, FeedbackRecord, Receipt

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

    # 3. Größe vorab, ohne den Rumpf zu lesen
    try:
        declared = int(request.headers.get("content-length", "0"))
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
        existing = repository.find_by_client_draft_id(feedback.clientDraftId)
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
        cleaned: list[tuple[bytes, str]] = []
        try:
            for data in raw_images:
                # Pillow rechnet CPU-lastig: nicht im Ereignisschleifen-Thread
                cleaned.append(await run_in_threadpool(clean_image, data))
        except ImageRejected as exc:
            return _error(exc.status_code, exc.reason)

        # 7. Eine Transaktion; Bilder erst nach COMMIT veröffentlichen
        record: FeedbackRecord | None = None
        try:
            with repository.transaction():
                record = repository.insert(feedback, len(cleaned))
                for position, (data, extension) in enumerate(cleaned):
                    store.save(record.id, position, data, extension)  # type: ignore[arg-type]
        except sqlite3.IntegrityError:
            # Gleichzeitige Wiederholung derselben clientDraftId
            if record is not None:
                store.discard(record.id)
            existing = repository.find_by_client_draft_id(feedback.clientDraftId)
            if existing is not None:
                return _receipt(existing, 200)
            return _error(503, "Vorübergehend nicht verfügbar.", {"Retry-After": "30"})
        except (OSError, sqlite3.OperationalError):
            if record is not None:
                store.discard(record.id)
            logger.warning("feedback storage failed")
            return _error(503, "Vorübergehend nicht verfügbar.", {"Retry-After": "30"})

        if cleaned:
            try:
                store.publish(record.id)
            except OSError:
                # Datensatz ist gespeichert; die Bilder fehlen. Nicht ablehnen, sonst käme eine Dublette.
                logger.error("feedback attachments could not be published reference=%s", record.reference)
        logger.info("feedback received reference=%s attachments=%d", record.reference, len(cleaned))
        return _receipt(record, 201)
    finally:
        await form.close()
