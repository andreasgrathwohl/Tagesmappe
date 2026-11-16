"""Einstellungen – ausschließlich aus der Umgebung."""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path

MIN_SECRET_LENGTH = 32


class SettingsError(Exception):
    """Fehlende oder ungültige Einstellung; die Meldung ist deutsch und für den Betreiber gedacht."""


def _required(environ: Mapping[str, str], name: str) -> str:
    value = environ.get(name, "").strip()
    if not value:
        raise SettingsError(f"{name} fehlt (Umgebungsvariable nicht gesetzt).")
    return value


def _secret(environ: Mapping[str, str], name: str) -> str:
    value = _required(environ, name)
    if len(value) < MIN_SECRET_LENGTH:
        raise SettingsError(f"{name} ist zu kurz: mindestens {MIN_SECRET_LENGTH} Zeichen erforderlich.")
    return value


def _bool(environ: Mapping[str, str], name: str, default: bool) -> bool:
    raw = environ.get(name)
    if raw is None or not raw.strip():
        return default
    value = raw.strip().lower()
    if value in ("true", "1", "yes"):
        return True
    if value in ("false", "0", "no"):
        return False
    raise SettingsError(f"{name} muss true oder false sein, nicht {raw!r}.")


@dataclass(frozen=True)
class Settings:
    app_key: str
    admin_password_hash: str
    session_secret: str
    retention_days: int = 365
    data_dir: Path = Path("/data")
    public_base_url: str = "https://frontstage.example.com"
    cookie_secure: bool = True
    # LANDING_DIR: ein aus __file__ abgeleiteter Pfad trägt im Image nicht (nicht editierbare Installation).
    landing_dir: Path = Path("/app/landing")

    @classmethod
    def from_env(cls, environ: Mapping[str, str]) -> Settings:
        app_key = _secret(environ, "APP_KEY")
        session_secret = _secret(environ, "SESSION_SECRET")
        admin_password_hash = _required(environ, "ADMIN_PASSWORD_HASH")

        raw_days = environ.get("RETENTION_DAYS", "").strip()
        retention_days = 365
        if raw_days:
            try:
                retention_days = int(raw_days)
            except ValueError:
                raise SettingsError(
                    f"RETENTION_DAYS muss eine ganze Zahl sein, nicht {raw_days!r}."
                ) from None
            if retention_days < 1:
                raise SettingsError("RETENTION_DAYS muss mindestens 1 sein.")

        defaults = cls.__dataclass_fields__
        return cls(
            app_key=app_key,
            admin_password_hash=admin_password_hash,
            session_secret=session_secret,
            retention_days=retention_days,
            data_dir=Path(environ.get("DATA_DIR") or defaults["data_dir"].default),
            public_base_url=environ.get("PUBLIC_BASE_URL") or defaults["public_base_url"].default,
            cookie_secure=_bool(environ, "COOKIE_SECURE", True),
            landing_dir=Path(environ.get("LANDING_DIR") or defaults["landing_dir"].default),
        )
