"""Bilddateien der Rückmeldungen im Dateisystem.

Erst in ``.staging`` schreiben, nach dem COMMIT per Umbenennen veröffentlichen: So entsteht
weder ein Datensatz ohne Bilder noch ein Bilderordner ohne Datensatz.
"""

import shutil
from pathlib import Path
from typing import Literal
from uuid import UUID

_STAGING = ".staging"


class AttachmentStore:
    def __init__(self, root: Path) -> None:
        self._root = root

    def _staging_dir(self, feedback_id: UUID) -> Path:
        return self._root / _STAGING / str(feedback_id)

    def _final_dir(self, feedback_id: UUID) -> Path:
        return self._root / str(feedback_id)

    def save(self, feedback_id: UUID, position: int, data: bytes, extension: Literal["png", "jpg"]) -> Path:
        if extension not in ("png", "jpg"):
            raise ValueError("Nur png und jpg sind erlaubt.")
        folder = self._staging_dir(feedback_id)
        folder.mkdir(parents=True, exist_ok=True)
        target = folder / f"{int(position)}.{extension}"
        target.write_bytes(data)
        return target

    def publish(self, feedback_id: UUID) -> None:
        staging = self._staging_dir(feedback_id)
        if not staging.is_dir():
            return
        staging.rename(self._final_dir(feedback_id))

    def discard(self, feedback_id: UUID) -> None:
        shutil.rmtree(self._staging_dir(feedback_id), ignore_errors=True)

    def paths(self, feedback_id: UUID) -> list[Path]:
        folder = self._final_dir(feedback_id)
        if not folder.is_dir():
            return []
        return sorted((p for p in folder.iterdir() if p.stem.isdigit()), key=lambda p: int(p.stem))

    def path(self, feedback_id: UUID, position: int) -> Path | None:
        for candidate in self.paths(feedback_id):
            if int(candidate.stem) == position:
                return candidate
        return None

    def delete_all(self, feedback_id: UUID) -> None:
        shutil.rmtree(self._final_dir(feedback_id), ignore_errors=True)
        self.discard(feedback_id)

    def _ids_in(self, folder: Path) -> list[tuple[UUID, Path]]:
        """Unterordner mit Rückmeldungs-Kennung als Namen; alles andere bleibt unberührt."""
        if not folder.is_dir():
            return []
        found: list[tuple[UUID, Path]] = []
        for entry in folder.iterdir():
            if not entry.is_dir():
                continue
            try:
                found.append((UUID(entry.name), entry))
            except ValueError:
                continue
        return found

    def stale_staging_ids(self, older_than: float) -> list[UUID]:
        """Staging-Ordner, die seit ``older_than`` (Unix-Zeit) unverändert sind: Reste eines Absturzes."""
        return [fid for fid, path in self._ids_in(self._root / _STAGING) if path.stat().st_mtime < older_than]

    def published_ids(self) -> list[UUID]:
        return [fid for fid, _ in self._ids_in(self._root)]
