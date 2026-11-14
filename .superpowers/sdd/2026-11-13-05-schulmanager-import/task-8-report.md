# Aufgabe 8 – Baustein „Schulmanager Online“ (App, HTTP)

Hinweis: Der task-brief-Skript fand keine „Task“-Überschrift (Plan nutzt „Aufgabe“); Auftrag direkt aus dem Plan (Aufgabe 8) gelesen.

## Gebaut
- `Frontstage/TimetableSources/HTTPTransport.swift`: Protokoll `HTTPTransport`, `URLSessionTransport`.
- `Frontstage/TimetableSources/SchulmanagerTimetableSource.swift`: Salt -> PBKDF2-Hash -> Login -> ein Calls-POST -> `SourceSnapshot`. Zeitlimit 15 s, User-Agent `Frontstage/<Version> (inoffizielle Anbindung)`, nur `https://<shape.host>`. Fehlerabbildung: 401 bei Salt/Login -> `.invalidCredentials`, URLError (notConnected/connectionLost/timedOut/cannotFindHost) -> `.offline`, sonstiger Status != 2xx -> `.server(status:)`, andere URLErrors -> `.unexpectedResponse("Netzwerkfehler <Code>")`. JWT nur lokal in `fetch`, Passwort nur im Login-Body.
- `FrontstageTests/TimetableSources/SchulmanagerTimetableSourceTests.swift`: 8 Tests (Plan: 7, plus `nonOkSubResultThrowsInsteadOfPartialSnapshot`) mit `FakeTransport` (actor) und `FixedCredentialStore`; eigene Test-Form statt `.recorded`.

## Evidenz
- `scripts\swift-parse.ps1`: 0 Syntaxfehler (82 Dateien). Kein lokaler Bau/Test möglich (App-Code); CI-Lauf nicht ausgeführt.
- Typen gegen reale Kern-API gelesen (`TimetableSource.fetch(range:existing:now:)`, `SchulmanagerResponseParser`, `SchulmanagerRequestBuilder`, `SchulmanagerAPIShape`, `CredentialStore`).

## Abweichungen vom Brief
- Reale Signatur `fetch(range:existing:now:)` (Brief nannte nur den Zweck); `now` wird als `fetchedAt` genutzt.
- Zeitraum (heute + 27 Tage) bestimmt der Koordinator (Aufgabe 9), nicht die Quelle.

## Bedenken
- Q-16 unverifiziert: `.recorded` hat Platzhalter für Lehrerkonten (siehe Kommentar im Kern).
- Salt-Pfad `/api/get-salt` vs. `/api/salt` (B9) offen.
- PBKDF2 (99 999 Runden) läuft synchron im aufrufenden Task; Koordinator sollte nicht auf dem Main-Actor aufrufen.
