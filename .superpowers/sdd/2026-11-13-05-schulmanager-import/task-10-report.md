# Aufgabe 10 – Morgendliche Aktualisierung (App)

Hinweis: task-brief fand keine "Task"-Überschrift (Plan nutzt "Aufgabe"); Auftrag direkt aus dem Plan gelesen.

## Gebaut
- `Frontstage/TimetableSources/SourceCoordinatorHolder.swift`: Koordinator je `DataStore` (Identität per `ObjectIdentifier`, Store wird mitgehalten); `live` mit Keychain, `SourceStatusStore()`, `PendingImportStore(defaultDirectory())`.
- `Frontstage/TimetableSources/MorningRefresh.swift`: Kennung, `schedule(after:calendar:)` nur iOS (`BGAppRefreshTaskRequest`, `earliestBeginDate` aus `MorningRefreshPolicy`), `try?` beim Einreichen.
- `FrontstageApp.swift`: `@State sourceCoordinators`; in der `DataScopedRoot`-Closure Koordinator per `.environment`, `.onChange(of: scenePhase, initial: true)` (.active → refresh(.appBecameActive), .background → schedule, iOS); am `WindowGroup` `.backgroundTask(.appRefresh)` (nur iOS) ruft `@MainActor runMorningRefresh()`; bestehender scenePhase-onChange unverändert.
- `project.yml`: `UIBackgroundModes: [remote-notification, fetch]`, `BGTaskSchedulerPermittedIdentifiers` (nur iOS-Ziel).
- Test: `FrontstageTests/TimetableSources/SourceCoordinatorHolderTests.swift` (holderCachesPerStore, coordinatorFollowsStore).

## Evidenz
- `scripts\swift-parse.ps1`: 0 Syntaxfehler (91 Dateien). Kein Bau/Test lokal möglich, kein CI-Lauf.

## Abweichungen
- Die `@MainActor`-Zugriffe der Hintergrundaufgabe stecken in einer privaten `@MainActor`-Methode statt `MainActor.run`; gleiche Wirkung, einfacher unter Swift 6.
- `schedule` hat Vorgabewerte (`Date()`, `.current`).

## Bedenken
- Nicht kompiliert: Sendable-Erfassung von `self` (App-Struct) in der `.backgroundTask`-Closure und `.environment(coordinator)` im CI prüfen.
- `initial: true` im `.id(generation)`-Teilbaum feuert nach Datenort-Wechsel erneut; die Abfrage-Regeln begrenzen das.
- Wirkung (AK-21) nur per Geräte-Checkliste prüfbar. Q-16 weiter unverifiziert.
