# Stundenplan schnell von Hand eintragen — Design

Stand 2026-11-20. Kleine Änderung; Entscheidungen von Andreas delegiert.

## Absicht

Seit der Schulmanager-Import abgeschaltet ist (ADR-0016), ist der Editor unter „Einrichten › Stundenplan“ der einzige
Weg zum Stundenplan. Heute braucht jede Stunde ein eigenes Blatt mit frei getippter Klasse und Fach: 25–30 Mal je Woche,
mit A/B doppelt so oft, fast immer dieselben Klassen und Fächer. Ziel: Eine Woche lässt sich am Stück eintragen, mit
wenigen Tipps je Stunde.

- Ziele: (1) Vorschläge für Klasse und Fach aus dem vorhandenen Stundenplan; (2) „Sichern und nächste“.
- Nicht-Ziele (später): Doppelstunde als Schalter, Stunde auf andere Tage kopieren, geführter Erststart.
- Anti-Ziel: Der Editor darf nicht unübersichtlicher werden als heute; ein Vorschlag darf nie still etwas eintragen.

## Ansätze

- **Gewählt: Vorschlagszeile unter den Feldern und ein zweiter Sichern-Knopf im vorhandenen Blatt.** Baut auf
  `TimetableEntrySheet` auf, keine neue Ansicht; Logik (Vorschläge, nächstes freies Feld) im Kern, testbar unter Windows.
- Verworfen: Schnelleingabe direkt im Raster (Tippen auf ein Feld wählt aus einer Palette) – neue Bedienform mit offener
  Gestaltung, deutlich mehr Aufwand, am Mac mit Zeiger heikel.
- Verworfen: Systemvorschläge über `searchSuggestions`/Autovervollständigen – an `TextField` in SwiftUI nicht für iPad
  und Mac gleich verfügbar; antippbare Knöpfe sind auf beiden gleich.

## Verhalten

- **Vorschläge Klasse:** alle Klassen des Stundenplans, nach Häufigkeit, bei Gleichstand alphabetisch; gefiltert auf
  Klassen, deren normalisierter Name mit der Eingabe beginnt; die gerade getippte Klasse selbst entfällt. Höchstens 8.
- **Vorschläge Fach:** zuerst Fächer, die die eingegebene Klasse schon hat, dann alle übrigen, je nach Häufigkeit;
  gleich gefiltert. Angezeigt wird die häufigste Schreibweise (`Subject.display`). Höchstens 8.
- Ein Tipp auf einen Vorschlag setzt nur das Feld; gesichert wird weiter nur mit einem Knopf.
- **„Sichern und nächste“** (nur beim Anlegen): sichert wie „Sichern“; danach bleibt das Blatt offen, Wochentag und
  Stunde springen zum nächsten freien Feld der gezeigten Variante (gleicher Tag weiter unten, sonst nächster Tag ab der
  ersten Stunde, Reihenfolge wie im Raster). Klasse und Fach bleiben stehen – so ist eine Doppelstunde ein Tipp. Gibt es
  kein freies Feld mehr, schließt das Blatt. Fehler zeigt das Blatt wie heute und bleibt stehen.
- Gestaltung (Aussehen der Vorschlagszeile, Wortlaut) ist offen und folgt dem Systemstandard (`.bordered`-Knöpfe in
  einer waagerechten Zeile); Kandidat für eine Design-Runde zusammen mit dem übrigen Editor.

## Bau

Auftrag von Andreas am 2026-11-20 („so umsetzen“) auf den Vorschlag, Punkt 1 und 2 sofort zu bauen, 3–5 danach.
In der Unterhaltung war „mit der vorigen Klasse vorbelegt“ genannt; entschieden ist, Klasse **und** Fach stehen zu
lassen, weil dann die Doppelstunde ohne eigenen Schalter ein Tipp ist und die Vorschläge das Ändern billig machen.

- **Neu** `Packages/FrontstageCore/Sources/FrontstageCore/Timetable/TimetableEntrySuggestions.swift`:
  `classes(in:matching:)`, `subjects(in:forClass:matching:)`.
- **Neu** `Packages/FrontstageCore/Sources/FrontstageCore/Timetable/TimetableGridNavigation.swift`:
  `nextFreeSlot(after:weekdays:periods:isOccupied:)`.
- **Neu** Tests dazu unter `Packages/FrontstageCore/Tests/FrontstageCoreTests/Timetable/`.
- **Bestehend** `Frontstage/UI/Setup/TimetableEditorViewModel.swift` (`TimetableEditorViewModel`, nutzt `allEntries`,
  `weekdays`, `gridPeriods`, `entries(weekday:period:)`): neue Methoden `classSuggestions(matching:)`,
  `subjectSuggestions(forClass:matching:)`, `nextFreeSlot(after:period:)`.
- **Bestehend** `Frontstage/UI/Setup/TimetableEntrySheet.swift` (`TimetableEntrySheet`, `save()`): Vorschlagszeilen
  unter `TextField("setup.timetable.entry.class")` und `TextField("setup.timetable.entry.subject")`, neuer Knopf
  „Sichern und nächste“ (neuer Schlüssel `setup.timetable.entry.saveAndNext`) nur bei `editing == nil`.
- Texte in `Frontstage/Resources/Localizable.xcstrings` (bestehend).
- Ein eigener Plan entfällt: Die Änderung ist klein, dieses Dokument nennt alle Dateien.
- PRD: neue Anforderung FR-1.3 [MVP] mit AK, Lieferstufen und Abdeckung; Hilfeartikel „Stundenplan“ ergänzt.
- Prüfung: Kern-Tests lokal, `swift-parse.ps1`, ein CI-Lauf auf macOS am Ende.
