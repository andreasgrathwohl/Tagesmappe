# Aufgabe 9 – Koordinator (App)

Hinweis: task-brief fand keine "Task"-Überschrift (Plan nutzt "Aufgabe"); Auftrag direkt aus dem Plan (Aufgabe 9) gelesen.

## Gebaut
- `Frontstage/TimetableSources/TimetableRepository.swift`: Protokoll + `extension DataStore: TimetableRepository {}` + `timetableSourceKind()`/`setTimetableSourceKind(_:)`.
- `SourceStatusStore.swift` (UserDefaults, Schlüssel `timetableSource.status`), `PendingImportStore.swift` (`pending-import.json`, `defaultDirectory()` zusätzlich).
- `TimetableSourceCoordinator.swift`: `ImportPreview` (Equatable von Hand), `@MainActor @Observable` Koordinator mit `refresh`, `applyPendingPreview`, `discardPendingPreview`, `switchSource`.
- Tests: `TimetableSourceCoordinatorTests.swift` (9 Tests aus dem Plan, FakeSource, CountingRepository, steuerbare Uhr), `TimetableRepositoryTests.swift` (2 Tests).

## Evidenz
- `scripts\swift-parse.ps1`: 0 Syntaxfehler (88 Dateien). Kein lokaler Bau/Test möglich (App-Code); kein CI-Lauf.
- Typen gegen reale Kern-/DataStore-API gelesen (SourceStatus, MorningRefreshPolicy, ImportDiffer/Applier, SourceChangeResolver, ScheduleChangeMerger, DataStore+Sources).

## Entwurfsentscheidungen / Abweichungen
- Fetch läuft in `Task.detached` (PBKDF2 mit 99 999 Runden blockiert sonst den Main-Actor; Bedenken aus Aufgabe 8).
- Zeitraum: heute bis heute+27 Tage (Koordinator, wie in Bericht 8 vermerkt).
- `applyPendingPreview` gleicht gegen den Stand zum Übernahmezeitpunkt neu ab (zwischenzeitliche Handarbeit bleibt geschützt); die angezeigte Vorschau kann dadurch minimal vom Ergebnis abweichen.
- Gemerkte Vorschau wird beim Start gegen den aktuellen Stand neu berechnet und entfällt, wenn nichts mehr zu zeigen ist.
- `switchSource` setzt den Stand (`SourceStatus()`) zurück und löscht die Vorschau; gleiche Quelle = No-op.
- Fehler beim Lesen/Schreiben des Repositorys werden als `.unexpectedResponse("Datenspeicher …")` im Status erfasst; `lastError` bleibt bei Fehlern bis zum nächsten Erfolg bestehen (Ruling 3).
- Wurde die Quelle während der Abfrage gewechselt, wird das Ergebnis verworfen.
- Ohne vorhandenen Stundenplan werden Ausfälle gegen einen leeren Plan aufgelöst (bleiben unmatched), Vertretungen werden trotzdem gespeichert.
- Testklasse `TestClock` statt `Clock` (Namenskollision mit Swift.Clock).

## Bedenken
- Nicht kompiliert (CI steht aus): insbesondere Isolation der `now`-Closure (@MainActor-Uhr in nicht-Sendable Closure) und `Task.detached`-Captures bitte im CI-Lauf prüfen.
- Q-16 weiterhin unverifiziert (Quelle läuft gegen dokumentierte inoffizielle API).
