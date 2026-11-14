# Lauf-Ledger — Frontstage, Teilpläne 02–07 (unbeaufsichtigt, „mach weiter bis du fertig bist“, 2026-11-14)

Reihenfolge und Bündel (je Bündel ein Branch/Worktree, ein CI-Lauf, dann selbst mergen):
- Bündel A: 02 Daten + 03 Ablage — Worktree C:/Dev/Tagesmappe-A, Branch feature/batch-a-daten-ablage
- Bündel B: 05 Schulmanager + 04 Oberfläche Kern
- Bündel C: 06 Anzeige/Zweitbildschirm + 07 Klassenbildschirm/Tafel/Kauf

Rulings:
- Ruling: Lotse nicht installiert — alle Lotse-Schritte entfallen.
- Ruling: CI je Bündel einmal (Sparregel CLAUDE.md), nicht je Teilplan — Kosten falls falsch: Compilerfehler zweier Teilpläne gemeinsam statt getrennt beheben.
- Ruling: Teilplan 05 wird ohne den Prüfschritt Q-16 (Aufgabe 1, braucht Andreas' Lehrerkonto) umgesetzt, damit 04 seine Einhängepunkte bekommt; der Baustein bleibt bis zur Prüfung als „inoffiziell, ohne Gewähr“ — Kosten falls falsch: Teile von 05 müssen nach der Kontoprüfung angepasst oder verworfen werden.
- Ruling: TestFlight-Bau (04/16) übersprungen — keine Secrets (APPLE_TEAM_ID, ASC_*) im Repo hinterlegt.
- Ruling: Design-Runden (04/18) und Geräte-Checklisten übersprungen — brauchen Andreas bzw. echte Geräte; Oberfläche bleibt beim Systemstandard.
- 2026-11-14: Andreas: Datenort wählbar (ADR-0010, FR-14) und Stiftnotizen neben dem Dokument (ADR-0011, FR-6.1) — auf main (PR #7) während Teilplan 02 lief.
  Folgen für den Lauf: (1) nach 02/03 Teilplan 08 „Datenordner-Abgleich“ schreiben (Opus, writing-plans) und im Bündel A umsetzen; (2) vor Bündel C Teilplan 06 (und 02-Reste) auf ADR-0011 umstellen; (3) Bündel-A-Branch vor dem Merge auf main bringen (git merge main).
- Teilplan 02: complete (f4375cb..46abaf1; preflight 14 Plan-Korrekturen; 10 Aufgaben sauber, Aufgabe 11 = CI → Controller; Gesamtprüfung Ready with fixes → Fix-Welle → Ready to merge; main (ADR-0010/0011) eingemergt). App-Code noch nicht kompiliert (CI am Bündelende).
- 2026-11-14: Andreas: kein eigener Server (Website/Konto/Docker verworfen, NFR-2 bleibt), dafür QR-Code zum Koppeln → FR-14.1/AK-44, kommt in Teilplan 08 (Plan-Autor beauftragt, inkl. PRD/Architektur). Eigener Server weiterhin möglich als Nextcloud-Datenordner ohne Backend-Code.
- 2026-11-14: Andreas: Nextcloud aktuell nicht anbieten, Datenort = iCloud oder OneDrive nativ (Graph) → ADR-0012 löst ADR-0010 ab; Plan-08-Autor beauftragt (ADR, PRD, Architektur, Übersicht, Plan, README/Wiki, Sitzungsnotiz). Teilplan 08 hängt damit an der Microsoft-Anmeldung aus Teilplan 03.
- Teilplan 08 geschrieben und auf main (PR #8): 15 Aufgaben (1–7 Kern, 8–14 App, 15 CI). ADR-0012, FR-14 geändert, FR-14.1/AK-44, Q-33 (Delta auf App-Ordner bei Schulkonten), Q-34 (Zustimmung Files.ReadWrite sperrbar). Vor Ausführung main in Bündel A mergen.
- Teilplan 03: complete (46abaf1..6383409; preflight 17 Korrekturen; 11 Aufgaben sauber (2 mit Fix-Runde), 12 CI → Controller, 13 Geräte-Checkliste → Andreas; Gesamtprüfung Ready with fixes (u. a. Doppelkodierung OneDrive-Adresse) → Fix-Welle → Ready to merge).
  Ruling: Ordnerfreigaben mit Lesen+Schreiben (Bookmark ohne read-only, macOS files.user-selected.read-write) — ADR-0011 verlangt Schreiben neben Dokumenten — Kosten falls falsch: FR-3.4 hängt an Code-Disziplin; Wächter-Test als offene Frage für die Gesamtschau.
  Ruling: RelinkResult bekommt Fall saveFailed (vom Fixer eingeführt) — 04 muss ihn behandeln — Kosten: eine zusätzliche Meldung.
  Ruling: open wartet bis 120 s auf den Download; 04 zeigt währenddessen eine Ladeanzeige aus availability — Kosten falls falsch: ein längerer Tipp ohne sofortige Rückkehr.
- Teilplan 08: Umsetzung gestartet auf Bündel A (Start ef28909, main mit Plan 08/ADR-0012 eingemergt, Konflikt in Übersicht zugunsten main gelöst). Parallel: Pläne 04–07 werden auf ADR-0011/0012 und 03-Änderungen nachgezogen (Doku-PR, selbst gemergt).
- Pläne 04–07 nachgezogen (PR #9): 06 weitgehend neu (Notizen neben Dokument), DataScopedRoot/ScopedAppContent in 04/05/07, saveFailed, Ladezustand, Abmelde-Warnung, geteilte Kamera-Berechtigung.
  Ruling: Stunden-Datei heißt z. B. 2026-11-17_8b_englisch_1.json statt storageText mit „|“ (in OneDrive/Windows verboten) — Kosten falls falsch: keine, Schlüssel steht in der Datei.
  Ruling: Notiz-PDF nur nach Änderung oder wenn es fehlt, ohne Striche entfernt (statt bei jedem Schließen) — vermeidet unnötige Dateien und Abgleich — Kosten: ein bloß angesehenes Dokument bekommt kein PDF.
  Ruling: gleicher Grundname mit anderer Endung → <Schlüssel>.<endung>.json; gleiches Dokument in zwei Fächern am selben Tag → letztes PDF gewinnt (Notiz-Dateien getrennt).
  Ruling: ADR-0011-Verweis auf den Ersatz-Datenort auf ADR-0012 korrigiert (Link-Korrektur). Architektur angepasst (PR #10).
  Hinweis: 06 braucht drei neue Methoden in 02/03 (StorageService.withDocumentLocation, MaterialResolver.resolveFolder, DataStore.removePenNotes) — legt 06 selbst an.
- Teilplan 08: complete (ef28909..753967d; preflight 17 Korrekturen; 14 Aufgaben (3 mit Fix-Runde), 15 CI → Controller; Gesamtprüfung Ready with fixes (u. a. Rennen Abgleich vs. Datenort-Wechsel) → Fix-Welle → keine wichtigen Befunde).
  Ruling: Downloads von OneDrive laufen über Microsoft-Speicher-Hosts statt nur graph.microsoft.com — Regel auf „Microsoft-Hosts“ erweitert (NFR-2/AK-18 erlauben Microsoft) — Kosten: keine.
  Ruling: Einrichten › Datenort aus 08 ist eigenständige Ansicht (DataLocationSettingsView), 04 hängt sie ein; Einrichten/Koppeln liegt in 04 AUSSERHALB des generation-gebundenen DataScopedRoot-Teilbaums, damit ein Datenort-Wechsel den Kopplungsablauf nicht abreißt — für Bündel B mitgeben.
  Ruling: Microsoft-Token zuerst still holen, interaktiv nur bei Bedarf (keine doppelte Anmeldung) — für Bündel B/04 prüfen und ggf. nachziehen.
  Ruling: Statuszeile „Stand des Abgleichs“ behält einen Fehlerstand bei Hintergrundabfragen, bis ein Durchgang gelingt (kein Flackern) — für Bündel B mitgeben.
- Bündel A CI: 6 Läufe bis grün (43546001765 Syntax; 43546397969 Sendable; 43547742608 DataStore-Namenskollision Tests; 43548109087 2 Testfehler Abgleich-Reihenfolge; 43548893870 Absturz durch verwaisten Merge-Auslöser; 43550466708 grün: 177 App-Tests, 221 Kern-Tests).
  Lehre: scripts/swift-parse.ps1 (Syntax lokal) eingeführt; ci.yml baut beide Plattformen auch bei Fehler; echte Fehler gefunden: verlorener zweiter Abgleich-Aufruf, Task-Lebensdauer (starkes self) in SyncMergeTrigger/DataFolderSync.
