"""Bildprüfung: Hochgeladene Bilder werden nie durchgereicht, sondern neu kodiert.

Grund (RISK-11, RISK-12): Fotos aus der Mediathek tragen Ortsangaben (EXIF-GPS), und ein
getarnter oder aufgeblähter Upload darf weder gespeichert noch den Speicher füllen.
"""

import io
import warnings
from typing import Literal

from PIL import Image, ImageOps, UnidentifiedImageError

MAX_IMAGE_BYTES = 8 * 1024 * 1024
MAX_IMAGE_PIXELS = 40_000_000

# Pillow warnt oberhalb dieser Grenze und bricht erst bei dem Doppelten ab – wir prüfen selbst scharf.
Image.MAX_IMAGE_PIXELS = MAX_IMAGE_PIXELS


class ImageRejected(Exception):
    def __init__(self, status_code: Literal[413, 415], reason: str) -> None:
        super().__init__(reason)
        self.status_code = status_code
        self.reason = reason


def clean_image(data: bytes) -> tuple[bytes, Literal["png", "jpg"]]:
    """Prüft und kodiert neu (ohne EXIF/ICC). 413: zu groß oder Bombe; 415: falsches Format oder defekt."""
    if len(data) > MAX_IMAGE_BYTES:
        raise ImageRejected(413, "Das Bild ist größer als 8 MiB.")
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            probe = Image.open(io.BytesIO(data))
            fmt = probe.format
            if fmt not in ("PNG", "JPEG"):
                raise ImageRejected(415, "Nur PNG und JPEG sind erlaubt.")
            if probe.width * probe.height > MAX_IMAGE_PIXELS:
                raise ImageRejected(413, "Das Bild hat zu viele Bildpunkte.")
            probe.verify()  # verify macht das Objekt unbrauchbar, daher danach neu öffnen
            image = Image.open(io.BytesIO(data))
            image.load()
    except ImageRejected:
        raise
    except (Image.DecompressionBombWarning, Image.DecompressionBombError) as exc:
        raise ImageRejected(413, "Das Bild hat zu viele Bildpunkte.") from exc
    except (UnidentifiedImageError, OSError, SyntaxError, ValueError, EOFError) as exc:
        raise ImageRejected(415, "Das Bild ist kein gültiges PNG oder JPEG.") from exc

    image = ImageOps.exif_transpose(image)  # Drehung einrechnen, bevor die Metadaten wegfallen
    out = io.BytesIO()
    if fmt == "PNG":
        # Neues Bildobjekt ohne info-Einträge: keine Textchunks, kein Profil
        image.save(out, format="PNG", optimize=True)
        return out.getvalue(), "png"
    if image.mode not in ("RGB", "L"):
        image = image.convert("RGB")
    image.save(out, format="JPEG", quality=90)
    return out.getvalue(), "jpg"
