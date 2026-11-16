# Frontstage — Teilplan 12: Rückmeldedienst und Verwaltungsseite

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Rahmen: `docs/superpowers/plans/2026-11-13-00-uebersicht.md` gilt nur in den Zeilen, die nicht Swift/Xcode betreffen (Datenhygiene, Commits, Code-Sprache nach ADR-0009, Gestaltung in den Aufgaben). Dieser Plan ist **unabhängig von den Swift-Teilplänen** ausführbar und braucht keinen macOS-Lauf.

**Goal:** Ein Container „Frontstage-Dienst“ nimmt Rückmeldungen aus der App an (FR-18), bewahrt sie mit Bildern auf, löscht sie nach Frist (FR-18.2) und bietet eine passwortgeschützte Verwaltungsseite mit Liste, Filtern, Detail, Bearbeitungsstand, Notiz, Ausfuhr und Löschen (FR-18.1); er liefert außerdem die statische Startseite aus (Inhalt: Teilplan 13).

**Architecture:** Python 3.12, FastAPI mit Uvicorn, eine App-Fabrik `create_app(settings)`; SQLite (stdlib `sqlite3`, WAL) und Bilddateien auf dem Volume `/data`; Verwaltungsseite serverseitig mit Jinja2 und htmx (lokal ausgeliefert), Sitzung über Starlettes `SessionMiddleware`, CSRF-Token in der Sitzung; Begrenzung im Speicher; Aufräumen beim Start und täglich im `lifespan`. Ein Image, `docker-compose.yml`, Betrieb hinter dem Reverse-Proxy des Betreibers. Tests mit pytest und HTTPX (`TestClient`), TDD; eigener Linux-CI-Lauf.

**Tech Stack:** Python 3.12, uv (Abhängigkeiten gesperrt in `uv.lock`), FastAPI (`fastapi[standard]`), Starlette `SessionMiddleware`, `python-multipart`, Jinja2, Pillow (Bildprüfung, EXIF entfernen), `argon2-cffi` (Passwort), htmx 2 (eine Datei, im Repo), pytest, HTTPX, Ruff; Docker, Docker Compose; GitHub Actions `ubuntu-latest`.

**Spec:** `docs/PRD.md` (NFR-2 geändert, FR-18, FR-18.1, FR-18.2, FR-19.1, AK-61 bis AK-63, RISK-11, RISK-12, Q-43 bis Q-45, Glossar „Rückmeldedienst“ `FeedbackService`/`frontstage_service`, „Verwaltungsseite“ `admin`, „Bearbeitungsstand“ `FeedbackStatus` mit `new`/`inProgress`/`done`/`rejected`, „Rückmeldung“ `Feedback` mit `kind` `idea`/`issue`, „Hilfethema“ `HelpTopic`); `docs/adr/0015-rueckmeldung-an-eigenen-dienst-im-container.md`; `docs/ARCHITECTURE.md` (Area dienst, vollständig); `DESIGN.md` Q-47 (Verwaltungsseite: Verhalten nach `design:enterprise-ux-patterns`, Aussehen schlicht mit den Grundtönen aus UI-8); Vertrag mit der App: `docs/superpowers/plans/2026-11-16-11-hilfe-und-rueckmeldung.md`, Entscheidung 16.

## Global Constraints

- **Alles unter `server/`.** Paket `server/src/frontstage_service/`, Tests `server/tests/`, Vorlagen `server/src/frontstage_service/templates/admin/`, statische Dateien der Verwaltung `server/src/frontstage_service/static/admin/`, Startseite `server/landing/` (Teilplan 13; hier nur ein Platzhalter `index.html`, `impressum/index.html`, `datenschutz/index.html`).
- **Werkzeuge lokal (Windows):** uv installieren, falls `uv --version` fehlt: `powershell -NoProfile -ExecutionPolicy Bypass -c "irm https://astral.sh/uv/install.ps1 | iex"`; uv holt Python 3.12 selbst (`uv python install 3.12`; das lokale Python 3.10 wird nicht benutzt). Tests: `cd server; uv run pytest -q` (einzeln `uv run pytest tests/test_api_feedback.py -q -k <name>`); Stil: `uv run ruff check . ; uv run ruff format --check .`. Docker ist lokal vorhanden: `docker build -t frontstage-service:dev server`.
- **Code-Sprache (ADR-0009):** Bezeichner, Dateien, Module englisch; Kommentare und Docstrings deutsch; Texte der Seiten deutsch (keine Übersetzungstabelle – nur eine Sprache, nur für den Betreiber). Begriffe nach Glossar: `FeedbackStatus` (`new`, `inProgress`, `done`, `rejected`), `kind` (`idea`, `issue`), `topic` mit den 21 Rohwerten von `HelpTopic` (Teilplan 11, Task 1: `gettingStarted`, `dayView`, `openingMaterial`, `penNotes`, `secondScreen`, `classScreen`, `board`, `preparation`, `coursePlan`, `timetable`, `bellSchedule`, `nonTeachingDays`, `schoolYears`, `schulmanager`, `storage`, `dataLocation`, `pairing`, `appearance`, `purchase`, `privacy`, `feedback`).
- **FastAPI-Stil (Skill `fastapi`):** `Annotated` für Parameter und Abhängigkeiten mit Typ-Aliassen (`SettingsDep`, `RepositoryDep`, `AdminSessionDep`); Router mit `prefix`/`tags`/`dependencies` am `APIRouter`; Rückgabetypen statt `response_model`, wo gleich; kein `...` als Vorgabe; blockierende Arbeit (SQLite, Pillow, Dateien) in normalen `def`-Endpunkten, nicht `async def` – außer der Annahme, die `await request.form(...)` braucht und die Speicherarbeit mit `run_in_threadpool` auslagert. Neue FastAPI-Mittel vorher mit Context7 (`/fastapi/fastapi`, `/kludex/starlette`) gegen die gesperrte Version prüfen.
- **Vertrag mit der App (verbindlich, wörtlich aus Teilplan 11, Entscheidung 16):** `POST /api/v1/feedback`, Header `X-Frontstage-App-Key`, Multipart mit Teil `feedback` (JSON) und 0–5 Teilen `attachment`. JSON-Schlüssel `clientDraftId` (UUID), `kind`, `text`, `topic` (oder `null`), `appVersion`, `deviceInfo` (oder `null`) mit `appVersion`, `build`, `systemName`, `systemVersion`, `modelIdentifier`, `dataLocation` (`iCloud`|`oneDrive`), `baseTone` (`warm`|`system`|`cool`|`petrol`), `accent` (`#RRGGBB` oder `null`), `appearanceMode` (`system`|`light`|`dark`), `isUnlocked`, `languageCode`. Antwort `{"id": "<UUID>", "reference": "<8 Zeichen>"}` mit 201, bei bekannter `clientDraftId` 200 mit derselben Antwort.
- **Grenzen (FR-18, ARCHITECTURE Area dienst):** Text 1–10 000 Zeichen; ≤ 5 Bilder; PNG oder JPEG am Inhalt erkannt; je ≤ 8 MiB, zusammen ≤ 25 MiB, Anfrage ≤ 26 MiB (`Content-Length`); JSON-Teil ≤ 64 KiB; Begrenzung 10 je Minute und 30 je Stunde je Absenderadresse; Anmeldung: 5 Fehlversuche je Adresse sperren 10 Minuten.
- **Statuscodes:** 201/200 wie oben; 401 Schlüssel fehlt/falsch; 411 `Content-Length` fehlt (Abschlussreview, endgültig); 413 zu groß oder zu viele Bilder; 415 anderes Bildformat; 422 ungültiges JSON oder Feld; 429 Begrenzung (Header `Retry-After` in Sekunden).
- **Datenhygiene:** keine IP-Adresse in Datenbank oder Log (Uvicorn-Zugriffslog aus: `--no-access-log`; eigenes Log nur mit Kennung); Bilder ohne Metadaten neu geschrieben; Testdaten nur mit `8b`, `9c`, erfundenen Texten, Adressen `example.com`; keine echte Domain, kein echtes Passwort, kein echter Schlüssel im Repo (`.env.example` mit Platzhaltern, `.env` in `server/.gitignore`).
- **Einstellungen nur aus der Umgebung:** `APP_KEY` (≥ 32 Zeichen), `ADMIN_PASSWORD_HASH` (Argon2-Hash), `SESSION_SECRET` (≥ 32 Zeichen), `RETENTION_DAYS` (Vorgabe 365, ≥ 1), `DATA_DIR` (Vorgabe `/data`), `PUBLIC_BASE_URL` (Vorgabe `https://frontstage.example.com`), `COOKIE_SECURE` (Vorgabe `true`), `TRUSTED_PROXIES` (Vorgabe `127.0.0.1`, an Uvicorns `--forwarded-allow-ips`; liest nur der Startbefehl, kein Feld in `Settings`), `LANDING_DIR` (Vorgabe `/app/landing`, Ordner der Startseite). Fehlt eine Pflichtangabe oder ist sie zu kurz, bricht der Start mit einer deutschen Meldung ab.
- **Design-Takt:** Tasks mit Oberfläche tragen `Design-Takt: Hauptstufe` – vor dem Editieren den Skill `design:enterprise-ux-patterns` laden (Verhalten: Liste, Filter, Zustände, Löschen mit Rückfrage, Tastatur) und danach mit ihm prüfen. Aussehen: schlicht, Systemschrift des Browsers, Grundtöne aus UI-8 warm (`#FBF8F2` Grund, `#ECE5D8` Auswahl, `#1F1A14` Text, Akzent `#0E6B7A`), keine eigene Gestaltungsrunde (DESIGN.md Q-47). Lücken in einer Zeile im Abschlussbericht.
- **Commits** englisch mit `Co-Authored-By`-Zeile; kein Push durch Implementierer.

## Entscheidungen dieses Teilplans (mit Begründung)

1. **stdlib `sqlite3` statt SQLModel/SQLAlchemy.** Zwei Tabellen, ein Prozess; ein schmales Repository mit SQL ist lesbarer und hat keine Abhängigkeit. *Verworfen:* SQLModel (Skill-Empfehlung gegenüber SQLAlchemy, hier aber gegenüber gar keinem ORM nicht nötig).
2. **Schema-Version in `PRAGMA user_version`**, Migrationen als nummerierte Funktionen in `db.py`; Start migriert. *Grund:* kein Alembic für zwei Tabellen.
3. **Bilder neu kodieren:** Pillow öffnet (`Image.open` + `verify`, dann erneut öffnen), Format nur `PNG`/`JPEG`, `ImageOps.exif_transpose`, speichern ohne `exif`/`icc_profile`-Metadaten (JPEG Qualität 90, PNG optimiert). Größenprüfung vorher an den Bytes. `Image.MAX_IMAGE_PIXELS = 40_000_000` gegen Dekompressionsbomben. *Grund:* RISK-11 (Ortsangaben in Fotos aus der Mediathek), RISK-12.
4. **Idempotenz über `clientDraftId`** (eindeutige Spalte): Eine Wiederholung nach verlorener Antwort legt nichts doppelt an und bekommt 200 mit derselben Kennung.
5. **`reference`**: acht Zeichen aus `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (ohne 0/O/1/I), `secrets.choice`, eindeutig (bei Kollision neu ziehen).
6. **Begrenzung im Speicher** (`SlidingWindowLimiter` mit eingespeister Uhr), Schlüssel = `request.client.host` nach Uvicorns Proxy-Auswertung (`--proxy-headers --forwarded-allow-ips $TRUSTED_PROXIES`). *Kosten:* gilt je Prozess, vergisst sich beim Neustart (ADR-0015).
7. **Multipart-Grenzen:** zuerst `Content-Length` > 26 MiB → 413 ohne Lesen; dann `await request.form(max_files=5, max_fields=1, max_part_size=65_536)` (der Teil `feedback` kommt laut Teilplan 11 ohne Dateinamen und zählt für Starlette deshalb als Feld – `max_fields`, `max_part_size` –, die `attachment`-Teile mit Dateinamen als Dateien – `max_files`; der Test-Helfer sendet ihn ebenso als Feld); Starlette meldet Überschreitungen als `HTTPException(400)` – „Too many files“ wird zu 413, andere Formfehler zu 422. Je Datei Größe prüfen (`len(await file.read())`).
8. **Sitzung:** Starlette `SessionMiddleware(secret_key=SESSION_SECRET, same_site="strict", https_only=COOKIE_SECURE, max_age=28_800, session_cookie="frontstage_admin")` (setzt `HttpOnly` immer). Sitzung trägt `admin: true`, `csrf: <token>`, `login_at`. Nach Anmeldung neue Sitzung (alte Werte löschen), Abmelden leert sie. *Verworfen:* eigene Sitzungstabelle – ein Betreiber, kein Bedarf an serverseitigem Widerruf über das Abmelden hinaus.
9. **CSRF:** Token (`secrets.token_urlsafe(32)`) in der Sitzung; jede POST-Route der Verwaltung prüft Formfeld `csrf_token` oder Header `X-CSRF-Token` (htmx setzt ihn über `hx-headers` am `<body>`) in konstanter Zeit; Fehler → 403. Anmeldeseite hat ein Vor-Anmelde-Token.
10. **htmx 2 lokal** unter `static/admin/htmx.min.js` (Version gesperrt, Prüfsumme im Kommentar der Vorlage), keine Inline-Skripte; CSP `default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'` für `/admin`. Für die Startseite (Teilplan 13) dieselbe Richtlinie plus `font-src 'self'` (Schriften liegen auf dem eigenen Server, keine Google Fonts – siehe PRD Changes 2026-11-16 zu FR-19).
11. **CSV-Ausfuhr:** UTF-8 mit BOM, Trennzeichen `;`, Spalten `reference;received_at;kind;status;topic;app_version;attachment_count;text;note`; Zellen, die mit `=`, `+`, `-`, `@`, Tab oder CR beginnen, bekommen ein führendes `'` (Formel-Einschleusung in Tabellenprogrammen). JSON: Liste der Objekte mit denselben Feldern plus `device_info`. Ausfuhr folgt den aktuellen Filtern.
12. **Aufräumen** `purge_expired(now)` löscht Datensätze mit `received_at < now − RETENTION_DAYS` und ihre Bildordner; Aufruf beim Start, dann alle 24 h als `asyncio`-Aufgabe im `lifespan`; zusätzlich Befehl `uv run python -m frontstage_service.purge` für den Betreiber.
13. **Startseite und Verwaltung im selben Prozess:** `/api/v1/*`, `/admin/*`, `/healthz` zuerst, danach die Startseite. Laut Skill `fastapi` `app.frontend("/", directory=…)`; kennt die gesperrte Version das nicht, `app.mount("/", StaticFiles(directory=…, html=True))` als letzte Route. Seiten als Ordner mit `index.html` (`/impressum/`, `/datenschutz/`), `/impressum` und `/datenschutz` leiten mit 308 auf die Form mit Schrägstrich – über eigene Routen vor dem Mount, denn `StaticFiles(html=True)` leitet selbst mit 307 um.
14. **Passwort-Hash erzeugen:** `uv run python -m frontstage_service.hash_password` fragt zweimal verdeckt (`getpass`) und gibt den Argon2-Hash aus; der Betreiber trägt ihn in `.env` ein. Kein Klartext-Passwort in der Umgebung.

## Review Focus

1. **Wiederholung derselben Rückmeldung nach Zeitüberschreitung** → kein Doppel, gleiche Kennung. Test: Task 4 `test_same_client_draft_id_returns_existing`.
2. **Bild mit Ortsangaben oder als PNG getarntes Nicht-Bild, Dekompressionsbombe** → Ortsangaben weg, Fälschung 415, Bombe 413/415 ohne Absturz. Tests: Task 3 `test_strips_exif_gps`, `test_rejects_disguised_file`, `test_rejects_decompression_bomb`.
3. **Text mit `=HYPERLINK(...)` oder `@SUM` in der CSV-Ausfuhr** → als Text, nicht als Formel. Test: Task 8 `test_csv_neutralises_formulas`.
4. **Abgelaufene oder fremde Sitzung, POST ohne CSRF-Token, zu viele Anmeldeversuche** → Anmeldeseite, 403, Sperre mit Hinweis. Tests: Task 6 `test_post_without_csrf_is_403`, `test_login_locks_after_five_failures`, `test_session_cookie_flags`.
5. **Volume voll oder Datenbank gesperrt beim Speichern** → 503 statt halber Datensatz (Bilder ohne Eintrag oder umgekehrt). Test: Task 4 `test_storage_failure_leaves_no_partial_record`.

---

## Dateistruktur

| Datei (unter `server/`) | Verantwortung | Task |
|---|---|---|
| `pyproject.toml`, `uv.lock`, `.gitignore`, `src/frontstage_service/__init__.py`, `settings.py`, `main.py`, `asgi.py`, `security_headers.py`, `tests/conftest.py` | Gerüst, Einstellungen, App-Fabrik, `/healthz`, Sicherheitsheader | 1 |
| `src/frontstage_service/db.py`, `repository.py`, `attachments.py`, `models.py` | Schema, Datensätze, Bilddateien, Pydantic-Modelle | 2 |
| `src/frontstage_service/images.py`, `ratelimit.py` | Bildprüfung und -bereinigung, Begrenzung | 3 |
| `src/frontstage_service/api.py` | Annahme `POST /api/v1/feedback` | 4 |
| `src/frontstage_service/retention.py`, `purge.py` | Aufbewahrung, Aufräumen | 5 |
| `src/frontstage_service/admin/auth.py`, `csrf.py`, `routes_auth.py`, `templates/admin/base.html`, `login.html`, `static/admin/admin.css`, `static/admin/htmx.min.js`, `hash_password.py` | Anmeldung, Sitzung, CSRF | 6 |
| `src/frontstage_service/admin/routes_feedback.py`, `filters.py`, `templates/admin/list.html`, `_table.html`, `detail.html` | Liste, Filter, Detail, Stand, Notiz, Löschen, Bilder | 7 |
| `src/frontstage_service/admin/export.py` | CSV/JSON | 8 |
| `Dockerfile`, `.dockerignore`, `docker-compose.yml`, `.env.example`, `README.md`, `landing/index.html`, `landing/impressum/index.html`, `landing/datenschutz/index.html` (Platzhalter) | Container, Betrieb, Auslieferung der Startseite | 9 |
| `.github/workflows/server.yml` (Repo-Wurzel) | Linux-CI | 10 |
| `tests/test_*.py` je Task | Tests | 1–9 |

---

### Task 1: Gerüst, Einstellungen, App-Fabrik, Gesundheit, Sicherheitsheader

Design-Takt: keiner

**Files:**
- Create: `server/pyproject.toml`, `server/uv.lock` (von `uv lock`), `server/.gitignore` (`.env`, `.venv/`, `data/`, `__pycache__/`), `server/src/frontstage_service/__init__.py`, `settings.py`, `main.py`, `asgi.py`, `security_headers.py`
- Test: `server/tests/conftest.py`, `server/tests/test_settings.py`, `server/tests/test_health.py`

**Interfaces:**
- Produces:

```python
@dataclass(frozen=True)
class Settings:
    app_key: str
    admin_password_hash: str
    session_secret: str
    retention_days: int = 365
    data_dir: Path = Path("/data")
    public_base_url: str = "https://frontstage.example.com"
    cookie_secure: bool = True
    landing_dir: Path = Path("/app/landing")   # LANDING_DIR; ein aus __file__ abgeleiteter Pfad trägt im Image nicht (nicht-editierbare Installation)
    @classmethod
    def from_env(cls, environ: Mapping[str, str]) -> "Settings": ...   # wirft SettingsError mit deutscher Meldung
class SettingsError(Exception): ...
def create_app(settings: Settings, *, clock: Callable[[], datetime] = utc_now) -> FastAPI: ...
# asgi.py: app = create_app(Settings.from_env(os.environ)) – nur für Uvicorn; Tests importieren asgi nie, sondern main.create_app
```

`pyproject.toml`: `requires-python = ">=3.12,<3.13"`; `[build-system]` (z. B. `uv_build`), damit `uv sync` das Paket aus `src/` installiert und Tests `frontstage_service` importieren können (ohne Build-System installiert uv das Projekt nicht); Abhängigkeiten `fastapi[standard]`, `jinja2`, `python-multipart`, `pillow`, `argon2-cffi`, `itsdangerous`; Gruppe `dev`: `pytest`, `httpx`, `ruff`; `[tool.fastapi] entrypoint = "frontstage_service.asgi:app"`; Ruff `line-length = 110`, Regeln `E,F,I,UP,B,S` (Bandit für Sicherheitsmuster), `per-file-ignores` für `tests/**`: `S101` (`assert`), `S105`, `S106` (Testpasswörter) – sonst schlägt `ruff check` an jedem Test fehl. `conftest.py`: Fixture `settings(tmp_path)` mit Testwerten (`app_key="test-app-key-" + "x"*20`, Hash von `"richtiges-passwort"` aus `argon2.PasswordHasher()`, `landing_dir` = `server/landing` im Repo), `clock` (feste Zeit 2026-11-16T09:00:00Z, verstellbar), `client` = `with TestClient(create_app(...), base_url="https://testserver", follow_redirects=False) as c: yield c` (nur als Kontextmanager läuft der `lifespan`; ohne `follow_redirects=False` folgt der Client 303/308 selbst und die Tests auf Umleitungen sehen sie nie).

- [ ] **Step 1: Failing Tests schreiben**

```python
def test_from_env_reads_all_values(): ...
def test_missing_app_key_fails_in_german():   # SettingsError, Meldung enthält "APP_KEY fehlt"
def test_short_secrets_fail():                # APP_KEY/SESSION_SECRET < 32 Zeichen → SettingsError
def test_retention_must_be_positive():        # "0" → SettingsError
def test_healthz_ok(client):                  # 200 {"status": "ok"}
def test_security_headers_on_every_response(client):  # X-Content-Type-Options nosniff, Referrer-Policy no-referrer, X-Frame-Options DENY
def test_openapi_and_docs_disabled(client):   # /docs, /redoc, /openapi.json → 404 (kein öffentlicher Schnittstellenkatalog)
```

- [ ] **Step 2: Rot belegen** – `cd server; uv run pytest -q` → ImportError.
- [ ] **Step 3: Implementieren** – `FastAPI(docs_url=None, redoc_url=None, openapi_url=None, lifespan=…)`; Header als Middleware.
- [ ] **Step 4: Grün belegen** – `uv run pytest -q`; `uv run ruff check . ; uv run ruff format --check .`.
- [ ] **Step 5: Commit** – `git commit -m "server: scaffold feedback service with settings, health and security headers"`

---

### Task 2: Speicher – Schema, Datensätze, Bilddateien

Design-Takt: keiner

**Files:**
- Create: `server/src/frontstage_service/db.py`, `repository.py`, `attachments.py`, `models.py`
- Test: `server/tests/test_repository.py`, `server/tests/test_attachments.py`

**Interfaces:**
- Consumes: `Settings` (1)
- Produces:

```python
class FeedbackKind(StrEnum): idea = "idea"; issue = "issue"
class FeedbackStatus(StrEnum): new = "new"; in_progress = "inProgress"; done = "done"; rejected = "rejected"
class DeviceInfoIn(BaseModel):  # Felder und Werte wie Vertrag; extra="forbid"
    appVersion: str; build: str; systemName: str; systemVersion: str; modelIdentifier: str
    dataLocation: Literal["iCloud", "oneDrive"]; baseTone: Literal["warm", "system", "cool", "petrol"]
    accent: Annotated[str, Field(pattern=r"^#[0-9A-F]{6}$")] | None; appearanceMode: Literal["system", "light", "dark"]
    isUnlocked: bool; languageCode: Annotated[str, Field(max_length=8)]
HelpTopic = Literal[...21 Rohwerte...]   # vor FeedbackIn definieren
class FeedbackIn(BaseModel):    # extra="forbid"
    clientDraftId: UUID; kind: FeedbackKind; text: Annotated[str, Field(min_length=1, max_length=10_000)]
    topic: HelpTopic | None; appVersion: Annotated[str, Field(max_length=32)]; deviceInfo: DeviceInfoIn | None
class Receipt(BaseModel): id: UUID; reference: str
@dataclass(frozen=True)
class FeedbackRecord:
    id: UUID; client_draft_id: UUID; reference: str; received_at: datetime; kind: FeedbackKind; text: str
    topic: str | None; app_version: str; device_info: dict | None; status: FeedbackStatus; note: str
    attachment_count: int; updated_at: datetime
@dataclass(frozen=True)
class FeedbackFilter: kind: FeedbackKind | None = None; status: FeedbackStatus | None = None; since: date | None = None; until: date | None = None
def connect(data_dir: Path) -> sqlite3.Connection   # WAL, foreign_keys on, migriert (user_version); check_same_thread=False
# (def-Endpunkte und run_in_threadpool laufen in anderen Threads); die App öffnet je Anfrage eine Verbindung
# (Abhängigkeit mit yield, schließt danach), der lifespan eine eigene fürs Aufräumen
class FeedbackRepository:
    def __init__(self, connection: sqlite3.Connection, clock: Callable[[], datetime]) -> None
    def transaction(self) -> AbstractContextManager[None]   # COMMIT am Ende, ROLLBACK bei Ausnahme (Task 4)
    def find_by_client_draft_id(self, client_draft_id: UUID) -> FeedbackRecord | None
    def insert(self, feedback: FeedbackIn, attachment_count: int) -> FeedbackRecord   # erzeugt id, reference (Entscheidung 5);
    # committet innerhalb von transaction() nicht selbst; doppelte clientDraftId → sqlite3.IntegrityError
    def get(self, id: UUID) -> FeedbackRecord | None
    def list(self, filter: FeedbackFilter, *, limit: int, offset: int) -> tuple[list[FeedbackRecord], int]   # neueste zuerst, Gesamtzahl
    def set_status(self, id: UUID, status: FeedbackStatus) -> bool
    def set_note(self, id: UUID, note: str) -> bool        # Notiz ≤ 5 000 Zeichen
    def delete(self, id: UUID) -> bool
    def expired_ids(self, before: datetime) -> list[UUID]
class AttachmentStore:
    def __init__(self, root: Path) -> None              # root = data_dir / "attachments"
    def save(self, feedback_id: UUID, position: int, data: bytes, extension: Literal["png", "jpg"]) -> Path
    # schreibt nach root/.staging/<id>/<position>.<ext> (Task 4: erst nach COMMIT veröffentlichen)
    def publish(self, feedback_id: UUID) -> None        # benennt root/.staging/<id> nach root/<id> um; ohne Bilder nichts
    def discard(self, feedback_id: UUID) -> None        # löscht root/.staging/<id> (Fehlerfall)
    def paths(self, feedback_id: UUID) -> list[Path]     # veröffentlichte Bilder, nach Position sortiert
    def path(self, feedback_id: UUID, position: int) -> Path | None
    def delete_all(self, feedback_id: UUID) -> None
```

Tabellen: `feedback` (Spalten wie `FeedbackRecord`, `client_draft_id UNIQUE`, `reference UNIQUE`, Zeiten ISO-8601 UTC, `device_info` als JSON-Text, Index auf `received_at`, `status`, `kind`); keine Spalte für Adressen.

- [ ] **Step 1: Failing Tests schreiben**

```python
def test_insert_and_get_roundtrip(repo): ...
def test_reference_format_and_unique(repo):   # 8 Zeichen aus dem Alphabet, 200 Einträge ohne Dublette
def test_list_newest_first_with_total(repo):
def test_filter_by_kind_status_and_dates(repo):   # until ist einschließlich (Tagesende UTC)
def test_set_status_and_note_persist(repo):
def test_delete_removes_row(repo):
def test_schema_has_no_address_column(conn):   # PRAGMA table_info: kein Name mit "ip" oder "addr"
def test_wal_mode(conn):                        # PRAGMA journal_mode == "wal"
def test_attachment_paths_sorted_and_deleted(tmp_path):   # save → publish → paths sortiert → delete_all
def test_attachment_discard_removes_staging(tmp_path):    # save → discard → kein Ordner, paths leer
def test_transaction_rolls_back_on_error(repo):          # insert in transaction(), Ausnahme → keine Zeile
def test_feedback_in_rejects_unknown_fields():  # extra="forbid" → ValidationError
def test_feedback_in_accepts_contract_example():   # JSON aus Teilplan 11, Task 3 encodesContract
```

- [ ] **Step 2: Rot belegen**, **Step 3: Implementieren**, **Step 4: Grün belegen** (wie Task 1).
- [ ] **Step 5: Commit** – `git commit -m "server: add sqlite schema, feedback repository and attachment store"`

---

### Task 3: Bildprüfung und Begrenzung

Design-Takt: keiner

**Files:**
- Create: `server/src/frontstage_service/images.py`, `ratelimit.py`
- Test: `server/tests/test_images.py`, `server/tests/test_ratelimit.py`

**Interfaces:**
- Produces:

```python
class ImageRejected(Exception):
    def __init__(self, status_code: Literal[413, 415], reason: str) -> None
MAX_IMAGE_BYTES = 8 * 1024 * 1024
def clean_image(data: bytes) -> tuple[bytes, Literal["png", "jpg"]]   # Entscheidung 3; zu groß → 413; kein PNG/JPEG, kaputt → 415; Bombe → 413
class SlidingWindowLimiter:
    def __init__(self, rules: Sequence[tuple[int, timedelta]], clock: Callable[[], datetime]) -> None   # [(10, 1 min), (30, 1 h)]
    def check(self, key: str) -> int | None   # None = erlaubt (und gezählt); sonst Sekunden bis zur nächsten Erlaubnis
    def blocked_for(self, key: str) -> int | None   # wie check, zählt aber nicht (Task 6: Sperre prüfen vor dem Passwort)
    def record(self, key: str) -> None              # zählt ohne zu prüfen (Task 6: nur Fehlversuche)
```

Jede App legt ihre Begrenzer in `create_app` an (`app.state`), nie auf Modulebene – sonst teilen sich Tests und App-Neustarts im Test den Zähler.

- [ ] **Step 1: Failing Tests schreiben** (Bilder mit Pillow im Test erzeugen)

```python
def test_png_and_jpeg_accepted_and_reencoded(): ...
def test_strips_exif_gps():               # JPEG mit GPS-EXIF → Ergebnis ohne EXIF (Image.getexif() leer)
def test_applies_orientation():            # EXIF-Orientierung 6 → Breite/Höhe vertauscht
def test_rejects_disguised_file():         # b"%PDF-1.7..." mit Endung .png → 415
def test_rejects_gif_and_webp():           # 415
def test_rejects_over_8_mib():             # 413
def test_rejects_decompression_bomb():     # PNG 10000×10000 einfarbig (klein komprimiert) → 413, kein MemoryError
def test_limiter_minute_rule():            # 10 erlaubt, 11. → Sekunden > 0
def test_limiter_hour_rule_and_window_slides():   # Uhr vorstellen
def test_limiter_keys_independent():
def test_limiter_blocked_for_does_not_count():   # 5× blocked_for → None; 5× record → blocked_for > 0
```

- [ ] **Step 2–4:** rot, implementieren, grün.
- [ ] **Step 5: Commit** – `git commit -m "server: add image sanitising and sliding window rate limiter"`

---

### Task 4: Annahme `POST /api/v1/feedback` (FR-18, AK-61)

Design-Takt: keiner

**Files:**
- Create: `server/src/frontstage_service/api.py`
- Modify: `server/src/frontstage_service/main.py` (Router einhängen, Abhängigkeiten `RepositoryDep`, `AttachmentStoreDep`, `LimiterDep`; `/healthz` prüft jetzt mit `SELECT 1`, dass die Datenbank lesbar ist, sonst 503 – ARCHITECTURE Area dienst)
- Test: `server/tests/test_api_feedback.py`

**Interfaces:**
- Consumes: Tasks 1–3
- Produces: `router = APIRouter(prefix="/api/v1", tags=["feedback"])`; `async def receive_feedback(request: Request, settings: SettingsDep, ...) -> JSONResponse` (201/200 mit `Receipt`).

Ablauf (Reihenfolge fest): Schlüssel prüfen (`hmac.compare_digest`) → 401; Begrenzung (`request.client.host`) → 429 mit `Retry-After`; `Content-Length` fehlt → 411, zu groß → 413; Form lesen (Entscheidung 7); Teil `feedback` als `FeedbackIn` (`model_validate_json`) → 422; bekannte `clientDraftId` → 200 mit vorhandener Quittung (Bilder werden dann ignoriert); jedes `attachment` durch `clean_image` (413/415), Summe ≤ 25 MiB → 413; in **einer** Transaktion (`with repository.transaction():`): Datensatz einfügen, Bilder mit `AttachmentStore.save` in den Bereitstellungsordner schreiben und erst nach erfolgreichem `COMMIT` mit `publish` an den endgültigen Ort umbenennen; bei Fehler (`OSError`, `sqlite3.OperationalError`) `discard`, Rollback → 503; `sqlite3.IntegrityError` auf `client_draft_id` (gleichzeitige Wiederholung) → `discard`, vorhandene Quittung mit 200. Log-Zeile nur `feedback received reference=<ref> attachments=<n>`.

- [ ] **Step 1: Failing Tests schreiben** (Hilfsfunktion `post_feedback(client, json=…, images=[…], key=…)`)

```python
def test_valid_feedback_with_two_images_returns_201_and_receipt(client): ...   # AK-61; Dateien unter data_dir/attachments/<id>/
def test_missing_or_wrong_key_is_401(client):
def test_six_images_is_413(client):
def test_nine_mib_image_is_413(client):
def test_content_length_over_26_mib_is_413_without_reading(client):
def test_gif_is_415(client):
def test_unknown_topic_or_extra_field_is_422(client):
def test_empty_text_is_422(client):
def test_11th_request_in_a_minute_is_429_with_retry_after(client):   # AK-61: 10 je Minute, die 11. → 429 mit Retry-After
def test_31st_request_in_an_hour_is_429(client, clock):               # 30 je Stunde, Uhr zwischen den Zehnergruppen vorstellen
def test_same_client_draft_id_returns_existing(client):               # Review 1: zweimal → 201, dann 200, gleiche reference, ein Datensatz
def test_storage_failure_leaves_no_partial_record(client, monkeypatch):   # Review 5: AttachmentStore.save wirft OSError → 503, keine Zeile, kein Ordner
def test_no_ip_address_persisted(client, conn):                        # AK-61: kein Wert "testclient"/"127.0.0.1" in irgendeiner Spalte
def test_record_survives_app_restart(settings):                        # neue App auf gleichem data_dir sieht den Datensatz
```

- [ ] **Step 2–4:** rot, implementieren, grün.
- [ ] **Step 5: Commit** – `git commit -m "server: add feedback intake endpoint with limits and idempotency"`

---

### Task 5: Aufbewahrung und Aufräumen (FR-18.2, AK-63)

Design-Takt: keiner

**Files:**
- Create: `server/src/frontstage_service/retention.py`, `server/src/frontstage_service/purge.py`
- Modify: `server/src/frontstage_service/main.py` (`lifespan`: einmal `purge_expired`, dann `asyncio`-Aufgabe alle 24 h, beim Herunterfahren abbrechen)
- Test: `server/tests/test_retention.py`

**Interfaces:**
- Produces: `def purge_expired(repository: FeedbackRepository, attachments: AttachmentStore, *, now: datetime, retention_days: int) -> int` (Anzahl gelöschter); `purge.py`: `main() -> None` liest `Settings.from_env`, ruft `purge_expired`, gibt „<n> Rückmeldungen gelöscht“ aus.

- [ ] **Step 1: Failing Tests schreiben**

```python
def test_ak63_deletes_older_than_retention_with_images(): ...   # 2025-11-15 weg samt Ordner, 2026-11-15 bleibt (now 2026-11-16, 365 Tage)
def test_boundary_exactly_retention_days_is_kept():
def test_purge_runs_on_startup(settings):                      # Datensatz vom 2024 → nach create_app + TestClient-Start weg
def test_purge_command_prints_count(capsys, monkeypatch):
```

- [ ] **Step 2–4:** rot, implementieren, grün.
- [ ] **Step 5: Commit** – `git commit -m "server: purge expired feedback on startup, daily and on demand"`

---

### Task 6: Verwaltung – Anmeldung, Sitzung, CSRF, Sperre (FR-18.1, AK-62)

Design-Takt: Hauptstufe (Skill `design:enterprise-ux-patterns`: Anmeldeformular, Fehlerzustände, Fokus, Tastatur)

**Files:**
- Create: `server/src/frontstage_service/admin/__init__.py`, `auth.py`, `csrf.py`, `routes_auth.py`, `server/src/frontstage_service/hash_password.py`, `templates/admin/base.html`, `templates/admin/login.html`, `static/admin/admin.css`, `static/admin/htmx.min.js`
- Modify: `server/src/frontstage_service/main.py` (`SessionMiddleware` nach Entscheidung 8, `StaticFiles` für `/admin/static`, Jinja2-Umgebung mit Autoescape)
- Test: `server/tests/test_admin_auth.py`

**Interfaces:**
- Produces:

```python
def verify_password(password_hash: str, password: str) -> bool        # argon2, Fehler → False
def require_admin(request: Request) -> None                            # nicht angemeldet: HTML-Anfrage → 303 /admin/login?next=…, htmx-Anfrage (Header HX-Request) → 401 mit HX-Redirect
AdminSessionDep = Annotated[None, Depends(require_admin)]
def csrf_token(request: Request) -> str                                # legt bei Bedarf an
async def require_csrf(request: Request) -> None                       # Entscheidung 9; Fehler 403; async, weil das Formfeld
                                                                       # nur über await request.form() lesbar ist (Starlette speichert das Formular, Form-Parameter danach gehen weiter)
# in create_app: app.state.login_limiter = SlidingWindowLimiter([(5, timedelta(minutes=10))], clock)   # aus Task 3;
# vor der Passwortprüfung blocked_for(host) → Sperrhinweis; nur Fehlversuche record(host); Schlüssel = request.client.host
# Routen: GET /admin/login, POST /admin/login (Formular password, csrf_token, next), POST /admin/logout
```

Anmeldeseite: ein Passwortfeld (`autocomplete="current-password"`, Fokus beim Laden über `autofocus`), Fehlermeldung „Passwort stimmt nicht.“ bzw. „Zu viele Versuche. Versuch es in <n> Minuten erneut.“ über dem Feld mit `role="alert"`; `next` nur relative Pfade unter `/admin` (offene Umleitung verhindern). `base.html`: `<body hx-headers='{"X-CSRF-Token": "…"}'>`, Kopfzeile „Frontstage · Rückmeldungen“ und „Abmelden“ (Formular-POST).

- [ ] **Step 1: Failing Tests schreiben**

```python
def test_admin_requires_login_redirects(client): ...             # GET /admin/ → 303 /admin/login?next=%2Fadmin%2F
def test_wrong_password_rejected(client):                        # 200 Anmeldeseite mit Fehlermeldung, keine Sitzung
def test_correct_password_logs_in_and_rotates_session(client):
def test_session_cookie_flags(client):                           # Review 4: Set-Cookie enthält Secure, HttpOnly, SameSite=strict, Max-Age=28800 (ohne Groß-/Kleinschreibung vergleichen: Starlette schreibt `httponly; samesite=strict; secure`)
def test_post_without_csrf_is_403(client):                       # Review 4
def test_login_locks_after_five_failures(client):                # Review 4: 6. Versuch mit richtigem Passwort → Sperrhinweis
def test_logout_clears_session(client):
def test_next_parameter_rejects_external_urls(client):           # next=https://evil.example.com → /admin/
def test_htmx_request_without_session_gets_hx_redirect(client):
def test_csp_header_on_admin(client):                            # Entscheidung 10, wörtlich
def test_hash_password_cli_outputs_argon2_hash(monkeypatch, capsys):
```

- [ ] **Step 2: Skill laden** – `design:enterprise-ux-patterns` (Formular, Fehlerzustand, Fokus).
- [ ] **Step 3–5:** rot belegen, implementieren, grün belegen; Ruff.
- [ ] **Step 6: Commit** – `git commit -m "server: admin login with argon2, strict session cookie, csrf and lockout"`

---

### Task 7: Verwaltung – Liste, Filter, Detail, Stand, Notiz, Löschen, Bilder (FR-18.1, AK-62)

Design-Takt: Hauptstufe (Skill `design:enterprise-ux-patterns`: Datentabelle, Filterleiste, leere/kein-Treffer-Zustände, Löschen mit Rückfrage, Tastatur)

**Files:**
- Create: `server/src/frontstage_service/admin/routes_feedback.py`, `admin/filters.py`, `templates/admin/list.html`, `templates/admin/_table.html`, `templates/admin/detail.html`
- Modify: `server/src/frontstage_service/static/admin/admin.css`
- Test: `server/tests/test_admin_feedback.py`

**Interfaces:**
- Consumes: `FeedbackRepository`, `AttachmentStore`, `FeedbackFilter` (2); `AdminSessionDep`, `require_csrf` (6)
- Produces:

```python
def parse_filter(kind: str | None, status: str | None, since: str | None, until: str | None) -> FeedbackFilter   # ungültig → ignoriert, nie 500
# GET  /admin/                         Liste (Seiten zu 50, Parameter page); mit HX-Request nur _table.html
# GET  /admin/feedback/{id}            Detail
# POST /admin/feedback/{id}/status     Formfeld status → 303 zurück (htmx: Teil-Antwort)
# POST /admin/feedback/{id}/note       Formfeld note
# POST /admin/feedback/{id}/delete     löscht Datensatz und Bilder → 303 /admin/ mit Hinweis
# GET  /admin/attachments/{id}/{position}   Bild mit Cache-Control: private, no-store
```

Liste: Filterleiste oben (Art, Bearbeitungsstand, von/bis als `<input type="date">`, „Filter zurücksetzen“), Filter wirken per htmx sofort (`hx-get` auf das Formular, `hx-push-url="true"`, `hx-target="#table"`) und funktionieren ohne JavaScript per Absenden; Tabelle mit Spalten Eingang (Datum, Uhrzeit Europe/Berlin), Art, Stand, Hilfethema, Bilder (Zahl), Anfang des Texts (100 Zeichen); Zeile verlinkt das Detail; Zähler „<n> Rückmeldungen“; leer ohne Filter: „Noch keine Rückmeldungen.“; leer mit Filter: „Keine Rückmeldungen für diese Filter.“ mit „Filter zurücksetzen“. Detail: Kennung, Eingang, Art, Hilfethema, App-Version, Text (Zeilenumbrüche erhalten, autoescaped), Geräteangaben als Definitionsliste (oder „Keine Geräteangaben“), Bilder in Originalgröße verlinkt, Vorschau max. 480 px breit mit `alt="Bildschirmfoto <n>"`; Bearbeitungsstand als Auswahl mit Speichern, Notiz als Textfeld mit Speichern (Hinweis „Gespeichert“ mit `aria-live="polite"`), „Löschen“ als Formular mit Rückfrage über `hx-confirm` bzw. eigene Bestätigungsseite ohne JavaScript („Rückmeldung <Kennung> samt Bildern endgültig löschen?“). Anzeigenamen: Art `idea` „Idee“, `issue` „Hinweis“; Stand `new` „Neu“, `inProgress` „In Arbeit“, `done` „Erledigt“, `rejected` „Verworfen“.

- [ ] **Step 1: Failing Tests schreiben** (Fixture `logged_in_client`, fünf Rückmeldungen wie AK-62)

```python
def test_list_shows_all_newest_first(logged_in_client): ...
def test_filter_issue_shows_three(logged_in_client):              # AK-62
def test_htmx_filter_returns_table_partial_only(logged_in_client):
def test_invalid_filter_values_are_ignored(logged_in_client):     # kind=xyz, since=2026-13-40 → 200
def test_empty_states(logged_in_client):                          # beide Texte
def test_detail_shows_text_device_info_and_images(logged_in_client):
def test_text_is_escaped(logged_in_client):                       # "<script>" erscheint als &lt;script&gt;
def test_status_and_note_persist_after_reload(logged_in_client):  # AK-62
def test_delete_removes_record_and_files(logged_in_client):       # AK-62: Ordner unter attachments fehlt
def test_attachment_requires_login_and_is_not_cached(client, logged_in_client):
def test_unknown_id_is_404(logged_in_client):
```

- [ ] **Step 2: Skill laden** – `design:enterprise-ux-patterns`.
- [ ] **Step 3–5:** rot, implementieren, grün; Ruff.
- [ ] **Step 6: Prüfen mit dem Skill** – Liste und Detail gegen die Muster aus Step 2 (Filter, Zustände, Rückfrage, Tastaturreihenfolge); Befunde fixen oder im Abschlussbericht nennen.
- [ ] **Step 7: Commit** – `git commit -m "server: admin list with filters, detail, status, note, delete and images"`

---

### Task 8: Ausfuhr als CSV und JSON (FR-18.1)

Design-Takt: keiner

**Files:**
- Create: `server/src/frontstage_service/admin/export.py`
- Modify: `admin/routes_feedback.py` (`GET /admin/export.csv`, `GET /admin/export.json`, Filter wie die Liste, ohne Seiten), `templates/admin/list.html` (zwei Links „Als CSV“, „Als JSON“ mit den aktuellen Filtern)
- Test: `server/tests/test_export.py`

**Interfaces:**
- Produces: `def to_csv(records: Iterable[FeedbackRecord]) -> bytes`, `def to_json(records: Iterable[FeedbackRecord]) -> bytes` (Entscheidung 11); Dateiname `frontstage-rueckmeldungen-<JJJJ-MM-TT>.csv|json` per `Content-Disposition`.

- [ ] **Step 1: Failing Tests schreiben**

```python
def test_csv_has_bom_header_and_rows(): ...          # AK-62: Kopfzeile + 5 Zeilen, beginnt mit b"\xef\xbb\xbf"
def test_csv_neutralises_formulas():                 # Review 3: "=HYPERLINK(...)" → "'=HYPERLINK(...)"; "@SUM(1)" → "'@SUM(1)"
def test_csv_keeps_semicolons_and_newlines_quoted():
def test_json_contains_device_info():
def test_export_follows_filters(logged_in_client):
def test_export_requires_login(client):
```

- [ ] **Step 2–4:** rot, implementieren, grün.
- [ ] **Step 5: Commit** – `git commit -m "server: export filtered feedback as csv and json"`

---

### Task 9: Container, Betrieb, Auslieferung der Startseite

Design-Takt: keiner

**Files:**
- Create: `server/Dockerfile`, `server/.dockerignore`, `server/docker-compose.yml`, `server/.env.example`, `server/README.md`, `server/landing/index.html`, `server/landing/impressum/index.html`, `server/landing/datenschutz/index.html` (Platzhalter: Titel, ein Satz, „Platzhalter – wird in Teilplan 13 ersetzt“)
- Modify: `server/src/frontstage_service/main.py` (Startseite nach Entscheidung 13, CSP der Startseite nach Entscheidung 10, 308 für `/impressum`, `/datenschutz`)
- Test: `server/tests/test_landing_served.py`

Dockerfile (Regeln, nicht Wortlaut): Basis `python:3.12-slim` mit fester Digest-Zeile als Kommentar-Hinweis; uv aus `ghcr.io/astral-sh/uv` per `COPY --from` mit fester Version; `uv sync --frozen --no-dev --no-editable` in einer Build-Stufe (die Laufzeit-Stufe kopiert nur `.venv`; eine editierbare Installation zeigte auf fehlende Quellen); Laufzeit-Stufe ohne Build-Werkzeuge; `landing/` nach `/app/landing` (`LANDING_DIR`); Nutzer `frontstage` (UID 10001); `/data` im Image anlegen und `frontstage` übereignen, **vor** `VOLUME /data` (ein neues Volume übernimmt Eigentümer aus dem Image, sonst kann UID 10001 nicht schreiben); `EXPOSE 8000`; `HEALTHCHECK` mit `python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/healthz').status==200 else 1)"`; `CMD ["uvicorn", "frontstage_service.asgi:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips", "${TRUSTED_PROXIES}", "--no-access-log"]` über ein kleines `sh -c`, damit die Variable greift. Compose: Dienst `frontstage`, `image: frontstage-service:latest`, `build: .`, `env_file: .env`, `volumes: [frontstage-data:/data]`, `ports: ["127.0.0.1:8000:8000"]` (nur lokal, der Proxy davor), `restart: unless-stopped`, `read_only: true` mit `tmpfs: [/tmp]`. README (deutsch): Voraussetzungen; `.env` aus `.env.example` füllen (`openssl rand -base64 48` für Geheimnisse, `hash_password` für das Passwort; den Argon2-Hash in **einfache** Anführungszeichen setzen – Compose ersetzt `$…` in `env_file`-Werten ohne Anführung oder in doppelten, und der Hash besteht aus `$`-Abschnitten; `.env.example` zeigt es so); `docker compose up -d --build`; Beispiel-Konfiguration für Caddy (`frontstage.example.com { reverse_proxy 127.0.0.1:8000 }`) und den Hinweis auf `TRUSTED_PROXIES`; Sicherung (`docker compose exec frontstage python -c "…VACUUM INTO…"` täglich, Volume kopieren); Update (`git pull`, `docker compose build --pull`, `up -d`); Löschung auf Anfrage (Kennung suchen, löschen); Aufräumen von Hand (`docker compose exec frontstage python -m frontstage_service.purge`); Bezug zu RISK-12 und Q-43–Q-45.

- [ ] **Step 1: Failing Tests schreiben**

```python
def test_landing_index_served(client): ...               # GET / → 200 text/html
def test_impressum_and_datenschutz_redirect_and_serve(client):   # /impressum → 308 /impressum/ → 200
def test_api_and_admin_take_precedence(client):          # /api/v1/feedback ohne Schlüssel → 401, nicht 404/405 von der Startseite
def test_landing_csp_allows_only_self(client):            # keine fremde Quelle in der CSP
def test_landing_sets_no_cookie(client):
```

- [ ] **Step 2–4:** rot, implementieren, grün.
- [ ] **Step 5: Image bauen und anfassen** – `docker build -t frontstage-service:dev server`; `docker run --rm -d --name fs-test -e APP_KEY=<32+ Zeichen> -e SESSION_SECRET=<32+> -e ADMIN_PASSWORD_HASH='<hash>' -e COOKIE_SECURE=false -p 127.0.0.1:8099:8000 frontstage-service:dev`; `curl -fsS http://127.0.0.1:8099/healthz` → `{"status":"ok"}`; `docker inspect --format '{{.State.Health.Status}}' fs-test` nach 40 s → `healthy`; `docker exec fs-test id -u` → `10001`; `docker rm -f fs-test`. Ist Docker lokal nicht erreichbar, übernimmt Task 10 den Bau.
- [ ] **Step 6: Commit** – `git commit -m "server: container image, compose file, operations guide and landing route"`

---

### Task 10: Linux-CI anlegen und einmal laufen lassen – führt der Controller aus

Design-Takt: keiner

**Files:**
- Create: `.github/workflows/server.yml`

Inhalt: `on: workflow_dispatch` und `pull_request` mit `paths: ["server/**", ".github/workflows/server.yml"]`; `concurrency` nach dem Muster von `ci.yml`, aber mit eigener Gruppe `server-${{ github.ref }}` (dieselbe Gruppe `ci-…` würde mit `cancel-in-progress` den macOS-Lauf auf demselben Ref abbrechen); Job `test` auf `ubuntu-latest`, `timeout-minutes: 10`, `defaults.run.working-directory: server`; Schritte: `actions/checkout@v4`, `astral-sh/setup-uv` (feste Hauptversion) mit `python-version: "3.12"`, `uv sync --frozen`, `uv run ruff check .`, `uv run ruff format --check .`, `uv run pytest -q`, `docker build -t frontstage-service:ci .`, Rauchtest wie Task 9 Step 5 (Container starten, `/healthz` mit Wiederholung bis 30 s, stoppen). Keine Secrets nötig (Testwerte im Lauf erzeugt). Berührt `ci.yml` nicht.

- [ ] **Step 1: Gesamtdiff durchsehen** – `git diff main...HEAD -- server .github/workflows/server.yml`: keine echte Domain, kein echter Schlüssel, `.env` nicht im Repo, keine IP-Spalte, keine Inline-Skripte in Vorlagen, `htmx.min.js` mit gesperrter Version.
- [ ] **Step 2: Lokal** – `cd server; uv run ruff check . ; uv run pytest -q` → grün.
- [ ] **Step 3: Lauf** – `workflow_dispatch` startet nur, wenn die Datei auf `main` liegt (Übersicht, Abstimmung 7). Deshalb: Pull Request öffnen (löst den Lauf über `paths` aus) oder nach dem Merge `gh workflow run server.yml --ref <branch>`; `gh run watch <id> --exit-status`. Linux-Minuten sind frei für öffentliche Repos bzw. günstig; die macOS-Sparregeln betreffen diesen Lauf nicht.
- [ ] **Step 4: Bei Rot** – Log lesen (`gh run view <id> --log-failed`), Ursache mit superpowers:systematic-debugging, ein neuer Lauf.

---

## Betriebs-Checkliste (Mensch, nach Task 10 und vor dem ersten echten Einsatz)

| # | Schritt | Erwartet | Ergebnis |
|---|---|---|---|
| 1 | Q-43 klären, Domain und Proxy einrichten, `.env` füllen, `docker compose up -d --build` | `https://<domain>/healthz` → ok, Zertifikat gültig | ☐ |
| 2 | **AK-61** mit `curl`-Skript aus dem README gegen die echte Adresse | 201, 401, 413, 429 wie AK-61; Neustart behält Daten | ☐ |
| 3 | **AK-62** im Browser | wie AK-62; Cookie mit `Secure`, `SameSite=Lax` (Entwicklerwerkzeuge) | ☐ |
| 4 | **AK-63**: Rückmeldung mit altem Datum per SQL anlegen, `purge` ausführen | gelöscht samt Ordner | ☐ |
| 5 | Sicherung einrichten und einmal zurückspielen | Daten nach Rückspielen vollständig | ☐ |
| 6 | Secrets der App setzen (`FEEDBACK_URL`, `FEEDBACK_APP_KEY` = `APP_KEY`), Teilplan 11 Checkliste 6a | Ende-zu-Ende-Upload mit Bild | ☐ |

## Abdeckung

| Anforderung | Task |
|---|---|
| FR-18 – Annahme, Prüfung, Grenzen, Schlüssel, Begrenzung, keine IP | 2, 3, 4; Betrieb 2 |
| FR-18.1 – Anmeldung, Liste, Filter, Detail, Stand, Notiz, Ausfuhr, Löschen | 6, 7, 8; Betrieb 3 |
| FR-18.2 – Aufbewahrung, Löschen | 5, 7; Betrieb 4 |
| AK-61, AK-62, AK-63 | 4; 6, 7, 8; 5 |
| NFR-2 (geändert) – nur ausdrücklich gesendete Rückmeldungen, keine Nutzerdaten | 2 (Schema), 4 |
| RISK-11, RISK-12 – EXIF, Größen, Begrenzung, Sicherheitsheader, Sperre, Sicherung | 1, 3, 4, 6, 9 |
| ADR-0015 – ein Container, SQLite, Volume, Proxy, Linux-CI | 1, 2, 9, 10 |
| FR-19, FR-19.1 – Auslieferung (Inhalt in Teilplan 13) | 9 |

## Abstimmungsbedarf

- **Q-43** Domain/Hoster, **Q-44** Impressum/Datenschutz (Teilplan 13), **Q-45** Frist (bis dahin 365 Tage).
- **DESIGN.md Q-47:** Aussehen der Verwaltungsseite entsteht beim Bau; Lücken im Abschlussbericht.
- **App Attest** ist bewusst nicht Teil dieses Plans (ADR-0015, später).

## Offene Risiken

1. **App-Schlüssel auslesbar** (ADR-0015): Fremdeinsendungen möglich; Begrenzung und Größenlimits mildern; App Attest später.
2. **Begrenzung je Prozess:** Mehrere Uvicorn-Worker würden sie aufweichen – Compose startet bewusst einen Prozess.
3. **`app.frontend()`** ist eine neue FastAPI-Fähigkeit; fehlt sie in der gesperrten Version, gilt der `StaticFiles`-Rückfall (Entscheidung 13).
4. **Starlettes Meldungstext „Too many files“** ist die Grundlage für 413 statt 400 (Entscheidung 7); ändert er sich, zeigt `test_six_images_is_413` das sofort.
5. **Sicherheitsupdates** (RISK-12): Image regelmäßig mit `--pull` neu bauen; Dependabot oder Renovate für `uv.lock` ist ein späterer Schritt.
