# Aufgabe 13 – Einrichten: Unterrichtsfrei (FR-7)

## Gebaut
- `Frontstage/UI/Setup/NonTeachingPeriodsViewModel.swift`: `NonTeachingPeriodError` (`fromAfterTo`, zusätzlich `saveFailed`), View-Modell mit `periods` (sortiert), `add` (leerer Titel -> `setup.nonTeaching.defaultTitle`; Ein-Tages-Zeitraum erlaubt), `remove` (löscht nie Material), `materialsWithoutLesson(in:)` (`orphanedLinkItems(on:)` je Tag), `assignableLessons(after:)` (14 Tage nach dem Zeitraum), `reload()`, `actions: LessonActions`.
- `NonTeachingPeriodsView.swift`: Screen/Host (Muster wie Zeitraster), Liste mit `DisclosureGroup` je Zeitraum (Zahl Material ohne Stunde, „Zuordnen …“ ueber das vorhandene `AssignLessonSheet`, Entfernen), Sheet zum Anlegen, Fehler-Alert, Neuladen bei `store.revision`.
- `SetupView`: NavigationLink „Unterrichtsfrei“ ueber `scoped { … }` (datengebunden, im Datenort-Scope; Kopplung/Datenort bleiben ausserhalb).
- 17 Schluessel `setup.nonTeaching.*` in `Localizable.xcstrings`.
- Tests: `FrontstageTests/UI/NonTeachingPeriodsViewModelTests.swift` (AK-14 verschieben, von>bis, Entfernen behaelt Material, Sortierung/Standardtitel).

## Nachweis
- `scripts/swift-parse.ps1`: 142 Dateien, 0 Syntaxfehler. App-Code, nicht lokal baubar; Typen per Lesen gegen echten Code geprueft. Kein Kern-Code geaendert, daher kein swift-test.

## Abweichungen vom Auftrag (echter Code)
- `NonTeachingPeriodError` um `saveFailed` erweitert (Speichern kann scheitern).
- `AssignLessonSheet` aus der Tagesansicht wiederverwendet statt neuer Auswahl.
- Zusatz `assignableLessons(after:)` im View-Modell.

## Offene Gestaltungskategorien
Alle offen; Systemstandard (List, DisclosureGroup, Form, DatePicker), keine eigene Palette/Typografie. Ruf nach `/design:design-runde` fuer Listen-/Formularoptik.

## Bedenken
- Nicht kompiliert (nur CI/Mac). `String(localized:)` im View-Modell nutzt Bundle.main; im Testhost ist das die App.
