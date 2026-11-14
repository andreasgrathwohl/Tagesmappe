---
status: accepted
date: 2026-11-14
reversibility: one-way
area: daten
---

# ADR-0012 — Datenort: iCloud oder OneDrive, direkt über Microsoft Graph

- Supersedes: ADR-0010

## Context and Problem Statement

ADR-0010 machte den Datenort wählbar: iCloud oder ein beliebiger Ordner in der Ablage (Dateien-App,
File Provider des jeweiligen Anbieters). Beim Planen des Abgleichs (Teilplan 08) zeigte sich, dass das
Verhalten der File Provider – wann eine Datei ankommt, ob Änderungen gemeldet werden, wie Konfliktkopien
heißen – je Anbieter verschieden und nur durch Ausprobieren belegbar ist. Andreas am 2026-11-14:
„Nextcloud will ich aktuell nicht anbieten, sondern OneDrive nativ.“ Die Umkehrkosten sind hoch: Der
Datenort bestimmt Abgleich, Anmeldung, Datenformat in der Ablage der Lehrkraft und den Umzugsweg.

## Decision Drivers

- Lehrkräfte ohne iCloud sollen am Mac vorbereiten und am iPad unterrichten können (wie ADR-0010)
- Schulen mit Microsoft 365 haben OneDrive ohnehin; Frontstage meldet sich dort für FR-5.1 schon an (ADR-0003)
- keine Server des Produkts (NFR-2), offline voll nutzbar (RISK-3)
- Abgleich soll auf Mac und iPad gleich funktionieren und ohne Ausprobieren je Anbieter belegbar sein

## Considered Options

- iCloud oder OneDrive über Microsoft Graph, im App-Ordner, eine Datei je Datensatz
- iCloud oder ein beliebiger Ordner in der Ablage (ADR-0010)
- Nur iCloud (ADR-0002)

## Decision Outcome

Chosen option: "iCloud oder OneDrive über Microsoft Graph", because Graph eine dokumentierte
Änderungsabfrage (Delta) und eindeutige Datei-Kennungen bietet, auf Mac und iPad gleich arbeitet und
die Microsoft-Anmeldung für FR-5.1 ohnehin gebaut wird. Andreas wählte es am 2026-11-14.

Beibehalten aus ADR-0010:

- Gearbeitet wird immer lokal mit SwiftData. „iCloud“ = SwiftData-Spiegelung in die private
  iCloud-Datenbank; „OneDrive“ = SwiftData ohne Spiegelung plus eigener Abgleich.
- Je Datensatz eine JSON-Datei `<Modell>/<Kennung>.json` mit Kennung, Änderungszeitpunkt, Gerät und
  Inhalt; Zeichnungen und Bilder als eigene Dateien daneben. Löschen schreibt eine Löschmarke.
  Konflikte je Datensatz: der zuletzt geschriebene Stand gilt. Danach dieselben Regeln des
  Zusammenführens wie nach einem iCloud-Abgleich.
- Datenort je Gerät gewählt; auf allen Geräten derselbe. Ein Wechsel zieht alle Daten einmal um.
- Die App schreibt nie in Material (FR-3.4); Stiftnotizen neben dem Dokument (ADR-0011) bleiben
  unberührt – sie laufen über den Zugriff auf das Material, nicht über den Datenort.

Festgelegt für OneDrive:

- **Ort:** der App-Ordner (`/me/drive/special/approot`), in OneDrive sichtbar als `Apps/Frontstage/`.
  Er entsteht beim ersten Zugriff, ist für die Lehrkraft sichtbar und gehört eindeutig der App
  (learn.microsoft.com: „What is an App Folder“). Darin `library.json` mit einer zufälligen
  Bibliothekskennung, daneben je Modell ein Unterordner. *Verworfen:* ein von der Lehrkraft gewählter
  Ordner – braucht eine Ordnerauswahl über Graph, die es auf dem Gerät nicht gibt, und lädt dazu ein,
  den Datenordner neben Material zu legen.
- **Berechtigung:** `Files.ReadWrite` (delegiert), angefordert erst bei der Wahl von OneDrive als
  Datenort (nachträgliche Zustimmung; für FR-5.1 genügt weiter `Files.Read`). Die engere
  `Files.ReadWrite.AppFolder` gilt laut Microsoft nur für private Konten, nicht für Schul- und
  Arbeitskonten (learn.microsoft.com, OneDrive „permissions reference“; Microsoft Q&A 1418013) – und
  Schulkonten sind der Hauptfall. Schreiben außerhalb des App-Ordners verbietet sich die App selbst.
- **Änderungen erkennen:** Delta-Abfrage auf den App-Ordner (`…/special/approot/delta`, Folgeabfragen
  mit `@odata.deltaLink`, bei `410 Gone` neu aufzählen); Elemente werden über ihre Kennung verfolgt.
  Ist Delta auf dem App-Ordner für Schulkonten nicht verfügbar, fällt die App auf das Auflisten der
  Modellordner zurück (Prüfung am Gerät, Q-33).
- **Schreiben:** `PUT …:/content` (bis 250 MB), mit `If-Match` auf das zuletzt bekannte eTag, damit ein
  fremder neuerer Stand nicht blind überschrieben wird.
- Private Microsoft-Konten und Schul-/Arbeitskonten (Authority `common`, wie ADR-0003).
- Voraussetzung: App-Registrierung in Microsoft Entra (MSAL-Client-ID, schon für FR-5.1 vorgesehen).

### Consequences

- Nutzen: geräteübergreifend ohne iCloud; Daten liegen im Microsoft-Konto der Lehrkraft (bei Schulen oft
  ausdrücklich gewünscht); Abgleich über eine dokumentierte Schnittstelle statt über das Verhalten
  einzelner File Provider; gleiches Verhalten auf Mac und iPad.
- Kosten (Pflicht):
  - Der zweite Datenort hängt an Microsoft. Lehrkräfte mit Google Drive oder Nextcloud und ohne
    iCloud haben keinen geräteübergreifenden Abgleich.
  - Anmeldung und Token-Handhabung über MSAL werden für den Abgleich tragend, nicht nur Zusatz; eine
    abgelaufene Anmeldung hält den Abgleich an, bis die Lehrkraft sich neu anmeldet.
  - Abgleich braucht Netz; offline arbeitet die App lokal weiter und gleicht später ab.
  - Auf jedem Gerät muss dasselbe Microsoft-Konto angemeldet sein.
  - `Files.ReadWrite` ist weiter gefasst als nötig; der Zustimmungsdialog nennt Zugriff auf alle
    Dateien. Schulträger können die Zustimmung durch Nutzer sperren (Q-34).
  - Zwei Wege für dieselben Daten (wie ADR-0010): Jede Änderung am Datenmodell muss in beiden
    funktionieren.

### Revisit if

- Lehrkräfte fragen nach Google Drive oder Nextcloud als Datenort.
- Microsoft öffnet `Files.ReadWrite.AppFolder` für Schul- und Arbeitskonten (dann engere Berechtigung).
- Weniger als 5 % der Lehrkräfte wählen OneDrive – dann den eigenen Abgleich zurückbauen.

## Pros and Cons of the Options

### iCloud oder OneDrive über Graph

- Vorzug: dokumentierte Änderungsabfrage, eindeutige Kennungen, gleiches Verhalten auf allen Geräten,
  Anmeldung ohnehin vorhanden.
- Nachteil: nur Microsoft; Netz und Anmeldung für den Abgleich nötig.

### iCloud oder ein beliebiger Ordner in der Ablage (ADR-0010)

- Vorzug (verworfen): jeder Anbieter, auch Nextcloud und Google Drive, ohne Anmeldung in der App.
- Nachteil: Verhalten der File Provider je Anbieter unsicher (Änderungsmeldungen, Platzhalter,
  Konfliktkopien); Nextcloud und Google Drive sollen aktuell nicht angeboten werden.

### Nur iCloud

- Vorzug (verworfen): nichts zu bauen.
- Nachteil: ohne iCloud kein Vorbereiten am Mac.

## More Information

- Area doc: docs/ARCHITECTURE.md#area-daten
- Quellen: learn.microsoft.com/onedrive/developer/rest-api/concepts/special-folders-appfolder,
  learn.microsoft.com/graph/api/driveitem-delta, learn.microsoft.com/graph/api/driveitem-put-content,
  learn.microsoft.com/onedrive/developer/rest-api/concepts/permissions_reference
