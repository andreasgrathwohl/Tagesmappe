# Frontstage-Dienst

Rückmeldedienst (`/api/v1/feedback`), Verwaltung (`/admin`) und Startseite (`/`, `/impressum/`,
`/datenschutz/`) in einem Prozess. Python 3.12, FastAPI, SQLite, Jinja2. Alle Beispieladressen sind
Platzhalter (`example.com`).

## Voraussetzungen

- Ein Linux-Server mit Docker und Docker Compose.
- Ein Reverse-Proxy mit TLS davor (unten Caddy). Der Dienst selbst spricht nur HTTP und lauscht nur auf
  `127.0.0.1:8000`.
- Zum Erzeugen des Passwort-Hashs lokal `uv` oder ein Python 3.12 mit installierten Abhängigkeiten.

## Einrichten

1. `.env` aus der Vorlage anlegen: `cp .env.example .env`.
2. Geheimnisse erzeugen und eintragen (`APP_KEY`, `SESSION_SECRET`):
   `openssl rand -base64 48`
3. Passwort-Hash für die Verwaltung erzeugen:
   `uv run python -m frontstage_service.hash_password` (fragt das Passwort ab, mindestens 12 Zeichen) und
   die Ausgabe als `ADMIN_PASSWORD_HASH` eintragen. **Den Hash in einfache Anführungszeichen setzen:**
   Compose ersetzt `$…` in `env_file`-Werten ohne Anführung oder in doppelten, und der Argon2-Hash besteht
   aus `$`-Abschnitten. `.env.example` zeigt es so.
4. `PUBLIC_BASE_URL` und `TRUSTED_PROXIES` anpassen.
5. Starten: `docker compose up -d --build`
6. Prüfen: `curl -fsS http://127.0.0.1:8000/healthz` liefert `{"status":"ok"}`.

## Reverse-Proxy (Caddy)

```
frontstage.example.com {
    reverse_proxy 127.0.0.1:8000
}
```

`TRUSTED_PROXIES` muss die Adresse enthalten, von der der Proxy beim Dienst ankommt (bei Caddy auf demselben
Host `127.0.0.1`; über das Docker-Netz ist es die Gateway-Adresse der Bridge, z. B. `172.17.0.1`). Nur diesen
Adressen glaubt der Dienst `X-Forwarded-For`; ist der Wert zu weit gefasst, lässt sich die Ratenbegrenzung je
Adresse umgehen, ist er falsch, sieht der Dienst nur die Proxy-Adresse.

## Sicherung

Die Daten liegen im Volume `frontstage-data` (`/data`: Datenbank `frontstage.db`, Anhänge unter
`attachments/`). Täglich (z. B. per Cron auf dem Host) einen konsistenten Datenbankabzug ziehen:

```
docker compose exec frontstage python -c "import sqlite3; c=sqlite3.connect('/data/frontstage.db'); c.execute(\"VACUUM INTO '/data/backup.db'\")"
docker compose cp frontstage:/data/backup.db ./backup-$(date +%F).db
docker compose exec frontstage rm /data/backup.db
```

Das Dateisystem des Containers ist schreibgeschützt, `/data` und `/tmp` ausgenommen. Die Anhänge
(`/data/attachments`) mit `docker compose cp frontstage:/data/attachments ./attachments-backup` mitsichern.
Sicherungen enthalten Rückmeldungen und gehören verschlüsselt und befristet aufbewahrt.

## Update

```
git pull
docker compose build --pull
docker compose up -d
```

`--pull` holt das aktuelle Basis-Image mit Sicherheitsupdates (RISK-12); regelmäßig wiederholen.

## Löschung auf Anfrage

Wer die Löschung seiner Rückmeldung verlangt, nennt die Kennung aus der Eingangsbestätigung. In der Verwaltung
(`/admin`) die Rückmeldung über die Kennung suchen, öffnen und löschen; Anhänge verschwinden mit ihr.
Abgelaufene Rückmeldungen löscht der Dienst selbst (`RETENTION_DAYS`, täglich und beim Start).

## Aufräumen von Hand

```
docker compose exec frontstage python -m frontstage_service.purge
```

Gibt die Zahl der gelöschten Rückmeldungen aus.

## Offene Punkte

Zu Risiken und offenen Fragen siehe RISK-12 (Betrieb und Sicherheitsupdates) und Q-43 bis Q-45 im PRD
(`docs/PRD.md`).

## Entwicklung

```
uv sync
uv run pytest
uv run ruff check .
```
