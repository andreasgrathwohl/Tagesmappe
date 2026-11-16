"""Hilfsprogramm für den Betreiber: Argon2-Hash für ``ADMIN_PASSWORD_HASH`` erzeugen.

Aufruf: ``uv run python -m frontstage_service.hash_password``
"""

import getpass
import sys

from argon2 import PasswordHasher

from .admin.auth import verify_password

__all__ = ["main", "verify_password"]

MIN_LENGTH = 12


def main() -> int:
    first = getpass.getpass("Neues Passwort: ")
    if len(first) < MIN_LENGTH:
        print(f"Das Passwort ist zu kurz (mindestens {MIN_LENGTH} Zeichen).", file=sys.stderr)
        return 1
    if getpass.getpass("Passwort wiederholen: ") != first:
        print("Die Eingaben stimmen nicht überein.", file=sys.stderr)
        return 1
    # Nur der Hash geht auf die Standardausgabe, damit er sich in .env übernehmen lässt
    print(PasswordHasher().hash(first))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
