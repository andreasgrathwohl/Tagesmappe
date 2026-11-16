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
4. `PUBLIC_BASE_URL` anpassen (`TRUSTED_PROXIES` setzt `docker-compose.yml`, siehe Reverse-Proxy).
5. Starten: `docker compose up -d --build`
6. Prüfen: `curl -fsS http://127.0.0.1:8000/healthz` liefert `{"status":"ok"}`.

## Reverse-Proxy (Caddy)

```
frontstage.example.com {
    reverse_proxy 127.0.0.1:8000
    # HSTS setzt der Dienst nicht selbst; Caddy ebenfalls nicht von sich aus
    header Strict-Transport-Security "max-age=31536000"
}
```

Der Dienst glaubt `X-Forwarded-For` nur der Adresse in `TRUSTED_PROXIES`, sonst sieht er alle Absender als eine
Adresse: Die Begrenzung (10 je Minute, 30 je Stunde je Absender) und die Anmeldesperre gälten dann für alle
gemeinsam. Ein Caddy auf demselben Host kommt **nicht** von `127.0.0.1` beim Container an, sondern über
`docker-proxy` bzw. NAT vom Gateway des Compose-Netzes. `docker-compose.yml` legt dafür ein eigenes Netz mit
festem Teilnetz an (`172.31.250.0/24`, Gateway `172.31.250.1`) und setzt `TRUSTED_PROXIES` auf genau diese
Gateway-Adresse; ein Wert in `.env` wird dort überschrieben. Kollidiert das Teilnetz mit einem vorhandenen Netz,
Teilnetz, Gateway und `TRUSTED_PROXIES` in `docker-compose.yml` gemeinsam ändern. Die Adresse ist nur von diesem
Host aus erreichbar (Port nur auf `127.0.0.1`), daher ist ihr zu vertrauen unbedenklich. Uvicorn nimmt auch
Netzangaben in CIDR-Form an.

Läuft der Proxy stattdessen als Container im selben Compose-Projekt, dort statt `127.0.0.1:8000` den
Dienstnamen `frontstage:8000` eintragen und `TRUSTED_PROXIES` auf die feste Adresse dieses Proxy-Containers setzen.
Prüfen: Elf Anfragen mit unterschiedlichen Adressen in `X-Forwarded-For` (über den Proxy) dürfen keine 429 liefern.

## Betrieb mit Dockhand und Cloudflare Tunnel

`deploy/docker-compose.yml` ist ein Stack für Dockhand, der das Image selbst baut und den Dienst ausschließlich
über einen Cloudflare Tunnel (`teach.grathwohl.dev`) erreichbar macht. Es werden **keine Ports veröffentlicht**.
Die Datei `docker-compose.yml` in diesem Ordner bleibt für lokalen Betrieb oder anderes Hosting.

**Aufbau:** Zwei Container. `frontstage-service` hängt nur im internen Netz `edge` (`internal: true`, Teilnetz
`172.31.251.0/24`) und hat keinen Zugang nach außen. `frontstage-tunnel` (cloudflared) hängt in `edge` mit der festen
Adresse `172.31.251.10` und zusätzlich in `egress` für die ausgehende Verbindung zu Cloudflare. Der Tunnel ist lokal
verwaltet und läuft mit Token, das Ziel steht deshalb als `--url http://frontstage-service:8000` im Befehl.
Kollidiert das Teilnetz mit einem vorhandenen, Teilnetz, `ipv4_address` und `TRUSTED_PROXIES` gemeinsam ändern.

**Client-Adresse:** Cloudflare setzt `X-Forwarded-For` (die Adresse des Besuchers steht ganz rechts) und
`Cf-Connecting-Ip`; cloudflared reicht beides durch. Uvicorn wertet `X-Forwarded-For` aus, aber nur, wenn die
Anfrage von `TRUSTED_PROXIES` kommt – hier genau die Adresse des Tunnel-Containers. Das genügt; `Cf-Connecting-Ip`
liest der Dienst nicht. Die Begrenzung und die Anmeldesperre gelten damit je Besucher.

**Einrichten in Dockhand:**

1. Stacks, Neuer Stack, Quelle Git: Repository `https://github.com/andreasgrathwohl/Tagesmappe`, Branch `main`,
   Compose-Pfad `server/deploy/docker-compose.yml`, **Context directory `.`** (Repo-Wurzel). Ohne diese Einstellung
   kopiert Dockhand nur die Compose-Datei, und der Bau scheitert mit „open Dockerfile: no such file or directory“.
   Das Verwaltungspasswort selbst gehört nicht in den Stack, nur sein Hash.
2. Umgebungsvariablen des Stacks setzen (fehlt eine, startet der Stack nicht):
   - `CLOUDFLARE_TUNNEL_TOKEN`: Token des Tunnels `frontstage`.
   - `APP_KEY` und `SESSION_SECRET`: je mindestens 32 Zeichen, z. B. `openssl rand -base64 48`.
   - `ADMIN_PASSWORD_HASH`: Argon2-Hash des Verwaltungspassworts, erzeugt mit
     `uv run python -m frontstage_service.hash_password` im Ordner `server/`. **In einfache Anführungszeichen
     setzen** (`'$argon2id$…'`), weil der Hash aus `$`-Abschnitten besteht und Compose sie sonst ersetzt.
3. Im Cloudflare-Dashboard den öffentlichen Hostnamen `teach.grathwohl.dev` dem Tunnel zuordnen; das Ziel
   (Ingress) kommt aus dem Befehl, nicht aus dem Dashboard.
4. Stack bereitstellen und `https://teach.grathwohl.dev/healthz` prüfen.

`NOINDEX` ist im Stack auf `true`: Der Dienst sendet `X-Robots-Tag: noindex, nofollow` und liefert eine
`robots.txt` mit `Disallow: /`. Zum Freigeben `NOINDEX: "false"` setzen.

**Sicherung:** Die Daten liegen im Volume `frontstage_frontstage-data` (`/data`). Datenbankabzug wie im Abschnitt
Sicherung, aber mit `docker exec frontstage-service …` statt `docker compose exec` (Dateisystem schreibgeschützt,
`/data` ausgenommen):

```
docker exec frontstage-service python -c "import sqlite3; c=sqlite3.connect('/data/frontstage.sqlite3'); c.execute(\"VACUUM INTO '/data/backup.db'\")"
docker cp frontstage-service:/data/backup.db ./backup-$(date +%F).db
docker exec frontstage-service rm /data/backup.db
docker cp frontstage-service:/data/attachments ./attachments-backup
```

**Update:** In Dockhand den Stack erneut aus Git bereitstellen (Pull and Redeploy). Wegen `pull_policy: build`
baut Dockhand das Image neu; das Volume bleibt erhalten. Für Sicherheitsupdates des Basis-Images (RISK-12)
regelmäßig neu bereitstellen. Das Tunnel-Image ist auf eine Version festgelegt und wird bewusst von Hand angehoben.

## Sicherung

Die Daten liegen im Volume `frontstage-data` (`/data`: Datenbank `frontstage.sqlite3`, Anhänge unter
`attachments/`). Täglich (z. B. per Cron auf dem Host) einen konsistenten Datenbankabzug ziehen:

```
docker compose exec frontstage python -c "import sqlite3; c=sqlite3.connect('/data/frontstage.sqlite3'); c.execute(\"VACUUM INTO '/data/backup.db'\")"
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
