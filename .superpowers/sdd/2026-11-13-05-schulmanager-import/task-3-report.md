# Task 3 (Aufgabe 3) — Schulmanager-Antworten lesen und Anfragen bauen

Base: ddbc62b. Brief-Skript fand keine "Task"-Überschriften (Plan nutzt "Aufgabe"); Aufgabe 3 direkt aus dem Plan gelesen.

## Gebaut (Kern, nur Foundation)
- SchulmanagerAPIShape.swift: Struktur mit öffentlichem Init; `.recorded` mit vorläufigen Werten.
- SchulmanagerRequestBuilder.swift: saltBody, loginBody, callsBody (JSONEncoder, sortedKeys).
- SchulmanagerResponseParser.swift: salt, login, lessons(fromCalls:at:), bellSchedule(fromCalls:at:); Typen SchulmanagerLessonInfo, SchulmanagerLessonType, SchulmanagerLesson, SchulmanagerLogin (alle mit öffentlichem Init).
- Tests: SchulmanagerResponseParserTests (20), SchulmanagerRequestBuilderTests (7), SchulmanagerFixtures (erfundene Daten).

## Evidenz
- RED: Parser-Testlauf scheiterte mit "cannot find 'SchulmanagerResponseParser' in scope".
- GREEN: gesamte Kernsuite `scripts\swift-test.ps1`: 255 Tests in 31 Suites bestanden.

## Abweichungen / Entscheidungen
- D1 (Preflight): Q-16 übersprungen, `recorded` ohne Befundtabelle. Belegte Werte (Host, /api/login, /api/calls, schedules/get-actual-lessons, get-class-hours, /api/get-salt aus const.py) stehen mit "belegt"; Lehrer-Werte B1 (user.associatedTeacher), B2 (id), B4 (Schlüssel "teacher", ganzes Objekt), B8-Parameter ([:]), B10 (bundleVersion nil) sind Platzhalter, kommentiert "unbelegt, Q-16 offen". Salt-Pfad B9 widersprüchlich in den Quellen (/api/get-salt vs /api/salt).
- Bodies über JSONEncoder (JSONValue ist Codable) statt JSONSerialization; gleiches Ergebnis.
- Typ `event`: Fach darf fehlen (actual wird dann nil statt Fehler), sonst wäre jeder Termin ohne Fach ein Importabbruch. isCancelled/isSubstitution fehlend = false; Pflicht sind date, classHour.number, type.
- Zeitraster: from > until ist ein Fehler (ClosedRange würde sonst abstürzen). Sekunden werden abgeschnitten (TimeOfDay hat keine).
- Fehlertexte nennen nie Werte aus der Antwort (Test errorTextsNeverContainResponseValues).
- Status 200 wird als JSON-Zahl erwartet.

## Concerns
- Lehrer-spezifische API-Formen sind ungeprüft (Q-16); vor Produktivnutzung Befundtabelle nachtragen und `recorded` anpassen.
