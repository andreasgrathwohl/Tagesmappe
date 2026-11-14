# Aufgabe 6 – Stand, Fehlzähler und Abfrage-Regeln (Kern)

Gebaut: `SourceStatus`, `RefreshTrigger`, `MorningRefreshPolicy` (Kern, TimetableSources/), Tests `MorningRefreshPolicyTests` (10 Tests).
Evidenz: RED (Build-Fehler, Typen fehlten) -> GREEN (10/10), volle Kern-Suite grün.
Abweichung: `TimetableSourceError` von `Equatable` auf `Hashable` erweitert (nötig, damit `SourceStatus` Hashable wird; alle Fälle haben hashbare Werte).
Zusätzliche Tests: Knopfdruck zählt nicht als automatischer Versuch; JSON-Roundtrip des Status.
Semantik: `recordingAttempt` zählt nur automatische Versuche je Kalendertag; Fehlschlag verändert lastAttemptAt nicht (setzt der Versuchsbeginn).
Concerns: keine.
