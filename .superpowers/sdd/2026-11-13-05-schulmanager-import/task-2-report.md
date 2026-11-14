# Aufgabe 2 – Protokoll TimetableSource und gemeinsame Typen (Kern)

Base: d5cad56

## Gebaut
- `Packages/FrontstageCore/Sources/FrontstageCore/TimetableSources/TimetableSource.swift`: `TimetableSourceKind`, `TimetableSourceError`, `SourceChange`, `DerivedTimetable`, `TimetableDerivationOutcome`, `SourceSnapshot`, Protokoll `TimetableSource`, `ManualTimetableSource` (alle `public`, öffentliche Initialisierer).
- `.../TimetableSources/JSONValue.swift`: roher JSON-Wert mit Pfad-Subscript.
- `Packages/FrontstageCore/Tests/FrontstageCoreTests/TimetableSources/TimetableSourceTests.swift`: 5 Tests (die 4 aus dem Plan plus Rundreise von Fehlern/Ergebnisarten).

## Evidenz
- RED: Testmodul kompiliert nicht (`cannot find 'TimetableSourceKind' in scope`).
- GREEN: `-Filter TimetableSourceTests` 5 Tests bestanden; volle Kern-Suite 226 Tests in 29 Suites bestanden.

## Abweichungen
- Aufgabennummer: Der Plan nutzt "Aufgabe 2"; das task-brief-Skript fand nur "Task"-Überschriften, daher Brief direkt aus dem Plan gelesen.
- Keine API-Abweichungen: `CalendarDay`, `TimetableEntry`, `Timetable`, `BellSchedule`, `SchoolClass`, `Subject` und Test-Helfer `d`/`t`/`entry` existieren wie im Plan.

## Bedenken
- Keine.
