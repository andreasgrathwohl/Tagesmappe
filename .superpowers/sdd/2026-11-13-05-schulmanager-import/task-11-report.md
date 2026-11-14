# Task 11 (Aufgabe 11) - Einrichten > Stundenplan-Quelle

Base f81d9c0. Hinweis: task-brief-Skript fand "Task"-Ueberschriften nicht (Plan nutzt "Aufgabe"); Brief direkt aus dem Plan gelesen.

## Gebaut
- `Frontstage/UI/Setup/TimetableSourceSettingsView.swift`: `init()`, Koordinator aus `@Environment(TimetableSourceCoordinator.self)`, Zugangsdaten ueber `KeychainCredentialStore()` (Vorgabe-Dienst wie `SourceCoordinatorHolder.live`). Quelle waehlen (`switchSource`), Anmeldung (SecureField; speichern -> `refresh(.userRequest)` -> bei `.invalidCredentials` loeschen), angemeldet/nicht angemeldet, Stand, "Jetzt importieren", "Abmelden", Hinweis Geraet-only, Hinweis "inoffiziell, ohne Gewaehr", Fehlertext je `TimetableSourceError` (Symbol + Text). Kein Kaufbezug.
- `TimetableSourceError.settingsMessageKey` (Extension in derselben Datei).
- `Localizable.xcstrings`: Schluessel `timetableSource.*` (Platzhalterwortlaut, unpersoenlich).
- `FrontstageTests/TimetableSources/SourceStringsTests.swift`: unofficialNoticeNamesBoth, everyErrorHasAText.

## Evidenz
swift-parse.ps1: 74 Dateien, 0 Syntaxfehler. Kein Kern-Code -> kein swift-test. Typen per Lesen geprueft (Coordinator, CredentialStore, TimetableRepository, SourceStatus, ModelContainerFactory.makeInMemoryContainer).

## Abweichungen / Entscheidungen
- `ImportPreviewView` existiert noch nicht (Aufgabe 12). Die Ansicht enthaelt ein schlichtes Platzhalter-Sheet (Uebernehmen ohne Konfliktauswahl = eigene Fassung behalten, Verwerfen); Aufgabe 12 ersetzt `previewSheet`.
- Probe-Import: Wurde `refresh` gedrosselt (kein neuer `lastAttemptAt`), werden die Zugangsdaten wieder geloescht und "zu kurz nach letzter Abfrage" gezeigt, damit nichts ungeprueft gespeichert bleibt.
- Anmeldung nur sichtbar, wenn Quelle = Schulmanager (Wechsel zuerst).
- Eingehaengt wird die Ansicht nirgends (Teilplan 04); `#Preview` mit In-Memory-Store.
- Skill apple-design geladen; Gestaltungskategorien (Wortlaut, Anordnung, Fehlerdarstellung) bleiben offen, nichts nach DESIGN.md beschlossen.

## Concerns
Nicht kompiliert (Windows); Risiken: `.textContentType`/`.keyboardType`-Modifier plattformbedingt, `Binding`-Closures mit MainActor-Koordinator (gleiches Muster wie DataLocationSettingsView).
