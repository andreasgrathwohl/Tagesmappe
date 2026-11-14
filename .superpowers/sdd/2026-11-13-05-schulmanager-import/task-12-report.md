# Aufgabe 12 – Import-Abgleich mit Vorschau

BASE dc0397e. Hinweis: task-brief-Skript fand keine "Task"-Überschriften (Plan nutzt "Aufgabe"); Aufgabe direkt aus dem Plan gelesen.

## Gebaut
- `Frontstage/UI/Setup/ImportPreviewView.swift`: `ImportPreviewModel` (Gruppen added/changed/conflicts/removed, Zeitraster, fetchedAt, `acceptedFromSource` Startwert leer, `choose(source:for:)` mit `mine` als Konfliktschlüssel, `==` von Hand, `isEmpty`) und `ImportPreviewView(preview:)` (Sheet mit NavigationStack, leere Gruppen ausgeblendet, je Konflikt Picker eigene/Quelle, Abbrechen -> discardPendingPreview, Übernehmen -> applyPendingPreview, Fehler bei Wurf als Symbol+Text).
- `TimetableSourceSettingsView`: Platzhalter-Sheet durch `ImportPreviewView` ersetzt.
- `Localizable.xcstrings`: Schlüssel `importPreview.*` (de). Alte Platzhalter-Schlüssel `timetableSource.preview.placeholder/accept/discard` sind jetzt ungenutzt, bewusst nicht entfernt.
- Tests `FrontstageTests/TimetableSources/ImportPreviewModelTests.swift` (5 Tests, inkl. der drei geforderten).

## Nachweis
swift-parse.ps1: 0 Syntaxfehler (95 Dateien). Kein Kern-Code geändert; App-Tests nicht lokal lauffähig (CI Aufgabe 14). Typen per Lesen geprüft (ImportPreview/ImportDiff real vorhanden in Koordinator bzw. Kern; nicht dupliziert).

## Abweichungen
- `ImportPreviewView` hat `init(preview:)` statt parameterlosem Init (Plan lässt es offen); `ImportPreview` ist real im App-Target definiert.
- Schritt 12.4 (apple-design-Prüfer) nicht ausgeführt: Skill-Lauf als Subagent verboten; Selbstdurchsicht stattdessen.

## Offene Gestaltungskategorien (nicht entschieden, Systemstandard)
Zustände (leer/Fehler), Wortlaut (Platzhalter), Dichte/Anordnung der Zeilen, Darstellung der Konfliktwahl (inline Picker), Wochentagsformat.

## Concerns
Sheet-Inhalt folgt `coordinator.pendingPreview`; das `@State`-Modell wird nur bei Erstellung aus der Vorschau gebaut. Nicht kompiliert (Windows).
