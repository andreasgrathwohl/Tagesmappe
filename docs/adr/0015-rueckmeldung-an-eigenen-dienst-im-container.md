---
status: accepted
date: 2026-11-16
reversibility: two-way
area: dienst
---

# ADR-0015 — Rückmeldung an einen eigenen Dienst im Container

- Amends: ADR-0014

## Context and Problem Statement

ADR-0014 schickt Rückmeldungen als E-Mail über das Mail-Programm des Systems. Andreas fragt am selben Tag: „Kein eigener
Server (NFR-2): ist es möglich diese funktion in einen container auszulagern? dann eine admin page und landing page dazu
zu bauen.“ Zu entscheiden ist, ob und wie Rückmeldungen an einen Dienst des Betreibers gehen, wie dieser Dienst gebaut
und betrieben wird und wie er sich zu NFR-2 verhält. Die Umkehrkosten sind mäßig: Der Dienst ist ein abgeschlossener
Baustein außerhalb der App; die App spricht ihn über eine Adresse an und behält Mail und Teilen als Rückfall.

## Decision Drivers

- Nutzerdaten der Lehrkraft bleiben bei ihr (NFR-2) – nur was sie ausdrücklich sendet, darf den Betreiber erreichen
- Eine Übersicht über alle Rückmeldungen mit Bildern, Bearbeitungsstand und Löschung (FR-18.1, FR-18.2)
- Der Betreiber behält die Daten selbst, ohne fremden Auftragsverarbeiter für Rückmeldungen
- Ein Betreiber, wenig Last: geringer Betriebsaufwand, ein Container, einfache Sicherung
- Startseite und Datenschutzseite sollen unter derselben Adresse erreichbar sein (FR-19, FR-19.1)

## Considered Options

- Ein eigener Container: Python 3.12, FastAPI, SQLite, Bilder als Dateien, Verwaltungsseite und Startseite im selben Image
- Ein fremder Dienst für Rückmeldungen (z. B. Sentry User Feedback, UserVoice)
- Bei E-Mail bleiben (ADR-0014 ohne Ergänzung)
- Eigener Container mit Node.js/TypeScript statt Python
- Je Teil ein eigener Container (Annahme, Verwaltung, Startseite) und Postgres als Datenbank

## Decision Outcome

Chosen option: "Ein eigener Container mit Python, FastAPI und SQLite", because er die Übersicht liefert, die Daten beim
Betreiber hält und mit einem Image, einer Datei-Datenbank und einem Volume auskommt. Andreas hat die Entscheidungen
delegiert; der Controller hat sie am 2026-11-16 getroffen.

Festgelegt:

- **NFR-2 bleibt für Nutzerdaten** (Stundenplan, Zuordnungen, Material, Stiftnotizen, Tafelbilder, Jahrespläne,
  Erscheinungsbild, Zugangsdaten). Einzige Ausnahme: eine Rückmeldung, die die Lehrkraft ausdrücklich absendet.
- **Der „Frontstage-Dienst“** ist ein Image (Python 3.12, FastAPI, Uvicorn) mit:
  - `POST /api/v1/feedback` – Multipart: ein JSON-Teil (Art, Text, Hilfethema, optional Geräteangaben) und bis zu fünf
    Bilder (PNG oder JPEG, je höchstens 8 MB, zusammen höchstens 25 MB); Header `X-Frontstage-App-Key` als schwache
    Sperre gegen Fremdeinsendungen; Begrenzung je Absenderadresse im Speicher (30 je Stunde, 10 je Minute); Antwort mit
    kurzer Kennung.
  - Verwaltungsseite unter `/admin`: serverseitig gerendert (Jinja2, wenig JavaScript, htmx), Anmeldung mit einem
    Passwort, dessen Hash in `ADMIN_PASSWORD_HASH` steht (Argon2), Sitzungscookie `Secure`, `HttpOnly`,
    `SameSite=Lax` (geändert 2026-11-16: mit Strict meldete ein Admin-Link aus einer Mail ab), CSRF-Schutz für jede ändernde Anfrage, Anmeldeversuche begrenzt.
  - Startseite, Impressum und Datenschutz als statische Dateien unter `/`.
  - `GET /healthz` für den Reverse-Proxy und Docker.
- **Speicher:** SQLite im WAL-Modus und Bilder als Dateien auf einem Docker-Volume (`/data`); IP-Adressen nur
  flüchtig im Speicher für die Begrenzung, nie in der Datenbank.
- **Aufbewahrung:** Rückmeldungen werden nach `RETENTION_DAYS` (Vorgabe 365) samt Bildern gelöscht – beim Start und
  täglich; Löschen einzeln auf der Verwaltungsseite.
- **Betrieb:** `docker-compose.yml` mit Volume, hinter dem Reverse-Proxy des Betreibers; TLS endet dort. Domain und
  Hoster offen (Q-43).
- **App:** Adresse aus der Build-Einstellung `FEEDBACK_URL`, Schlüssel aus `FEEDBACK_APP_KEY` (beide CI-Secrets, im
  Repo Platzhalter). Ist keine Adresse hinterlegt oder der Dienst nicht erreichbar, gilt ADR-0014 unverändert
  (Mail, Teilen, Kopieren). Vor dem ersten Senden stimmt die Lehrkraft einmal zu.
- **Repo:** alles unter `server/` (Anwendung, Vorlagen, Startseite, Tests mit pytest und HTTPX, Dockerfile, Compose,
  Betriebsanleitung); eigener Linux-CI-Lauf, unabhängig von den macOS-Läufen.
- **Später:** App Attest, damit nur echte App-Installationen senden können.

### Consequences

- Nutzen: Übersicht mit Bildern, Stand und Notiz; Daten nur beim Betreiber; Löschfristen technisch durchgesetzt; ein
  Image, eine Datei-Datenbank, Sicherung = ein Volume; Startseite und Datenschutz unter einer Adresse; die App bleibt ohne
  Dienst voll nutzbar.
- Kosten (Pflicht):
  - Das Produkt betreibt jetzt einen Server (RISK-12): Ausfälle, Sicherheitsupdates, Angriffsfläche, DSGVO-Pflichten des
    Verantwortlichen (Verzeichnis, Auskunft, Löschung, Auftragsverarbeitung mit dem Hoster).
  - Der App-Schlüssel steckt in der App und ist auslesbar; bis App Attest kann jeder, der ihn ausliest, Rückmeldungen
    einsenden. Begrenzung und Größenlimits mildern das nur.
  - Die Begrenzung im Speicher gilt je Container-Prozess und vergisst sich beim Neustart; für einen Betreiber mit einer
    Instanz genügt das.
  - SQLite trägt nur eine Instanz; Skalieren hieße Datenbankwechsel.
  - Eine zweite Sprache (Python) im Repo, mit eigenen Tests, eigenem CI und eigenen Abhängigkeiten.
  - Die App braucht zusätzlich zum Mail-Weg einen Upload-Weg mit Fortschritt, Wiederholung und Zustimmung.

### Revisit if

- Mehr als eine Instanz nötig wird oder Rückmeldungen 10 000 je Jahr übersteigen (dann Postgres und eine geteilte
  Begrenzung).
- Missbrauch über den ausgelesenen App-Schlüssel auftritt (dann App Attest vorziehen).
- Der Betrieb mehr als etwa eine Stunde je Monat kostet (dann fremder Dienst mit Auftragsverarbeitungsvertrag prüfen).

## Pros and Cons of the Options

### Eigener Container mit Python, FastAPI und SQLite

- Vorzug: alles in einem Image; FastAPI kennt der Entwickler; SQLite braucht keinen zweiten Dienst.
- Nachteil: Server-Betrieb und DSGVO-Pflichten liegen beim Betreiber.

### Fremder Dienst für Rückmeldungen

- Vorzug (verworfen): kein eigener Betrieb, fertige Oberfläche.
- Nachteil: Bilder mit Schul- und Personendaten bei einem Auftragsverarbeiter außerhalb der Kontrolle des Betreibers;
  oft Nutzungsmessung inklusive; Kosten je Monat.

### Bei E-Mail bleiben

- Vorzug (verworfen): kein Server.
- Nachteil: keine Übersicht und kein Bearbeitungsstand; Anhänge über Postfächer verstreut; Löschfristen nur von Hand.

### Node.js/TypeScript statt Python

- Vorzug (verworfen): dieselbe Sprache wie manche Weboberfläche; der Entwickler kennt beides.
- Nachteil: kein Vorteil für diesen Umfang; FastAPI mit Pydantic-Prüfung ist dem Entwickler vertrauter und das Image
  schlank.

### Je Teil ein Container und Postgres

- Vorzug (verworfen): Teile getrennt skalier- und austauschbar; Postgres trägt viele Instanzen.
- Nachteil: drei Images und ein Datenbankdienst für einen Betreiber mit geringer Last – Aufwand ohne Nutzen.

## More Information

- Area doc: docs/ARCHITECTURE.md#area-dienst
- Anforderungen: docs/PRD.md NFR-2 (geändert), FR-17.3 (geändert), FR-18 bis FR-19.1, RISK-12, Q-43 bis Q-45
- Ergänzt: docs/adr/0014-rueckmeldung-per-e-mail-ohne-eigenen-server.md (bleibt als Rückfall gültig)
