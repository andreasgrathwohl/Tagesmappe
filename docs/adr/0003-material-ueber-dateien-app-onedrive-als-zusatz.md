---
status: accepted
date: 2026-11-13
reversibility: one-way
area: ablage
---

# ADR-0003 — Material über Dateien-App, OneDrive als Zusatz

## Context and Problem Statement

Material liegt in der Ablage der Lehrkraft, bei beliebigen Anbietern (NFR-3, CON-2), und muss im
Unterricht sofort und aktuell aufgehen (NFR-1). Für Lehrkräfte mit Microsoft 365 sollen
OneDrive-Dateien mit AutoSpeichern öffnen, damit Notizen und Zeichnungen sofort in der Ablage landen
(FR-5.1). Die Umkehrkosten sind hoch: Wie eine Zuordnung auf eine Datei verweist, steht in jeder
gespeicherten Zuordnung; ein Wechsel bedeutet, alle Zuordnungen aller Lehrkräfte umzuschreiben.

## Decision Drivers

- jede Ablage, die das Tablet einbindet (NFR-3)
- keine Kopien, ein Stand je Datei (FR-3.4)
- AutoSpeichern bei OneDrive (FR-5.1)
- keine eigenen Server (NFR-2)

## Considered Options

- Dateien-App als Grundlage (dauerhafter Ordnerzugriff des Systems), OneDrive zusätzlich direkt über die Microsoft-Graph-Schnittstelle
- Nur Dateien-App
- Je Anbieter eine direkte Anbindung (OneDrive, Google Drive, …)

## Decision Outcome

Chosen option: "Dateien-App als Grundlage, OneDrive zusätzlich direkt", because sie mit einem
Mechanismus alle Anbieter abdeckt und für Microsoft-365-Nutzer trotzdem das Öffnen als Cloud-Dokument
mit AutoSpeichern erlaubt. Andreas wählte am 2026-11-13 diesen Weg („C“).

Eine Zuordnung verweist auf eine Datei über einen dauerhaften Systemverweis (Security-Scoped Bookmark)
auf einen von der Lehrkraft freigegebenen Ordner plus den Pfad darin; bei OneDrive-Material
zusätzlich über dessen OneDrive-Kennung, damit es als Cloud-Dokument geöffnet werden kann.

### Consequences

- Nutzen: alle Anbieter auf einen Schlag (iCloud Drive, OneDrive, Google Drive, Nextcloud, …) ohne
  Anmeldung je Anbieter; OneDrive-Nutzer bekommen AutoSpeichern wie beim OneDrive Opener am Mac.
- Kosten (Pflicht):
  - Zwei Wege, eine Datei zu erreichen, und eine Zuordnung kann beide Verweise tragen – mehr Code und
    Testfälle.
  - Aktualität und Offline-Verfügbarkeit von Nicht-OneDrive-Material hängen vom Anbieter ab; das
    Bereithalten (NFR-1) muss je Anbieter über die Dateien-App angestoßen werden und ist nicht bei
    allen gleich zuverlässig.
  - Öffnen über die Dateien-App in PowerPoint startet evtl. ohne AutoSpeichern (RISK-2) – früh auf
    einem echten iPad prüfen.
  - Für OneDrive braucht das Produkt eine App-Registrierung bei Microsoft (für private und
    Schul-/Arbeitskonten) und eine Anmeldung der Lehrkraft; manche Schulträger sperren die Zustimmung
    für fremde Apps.
  - Wird eine Datei außerhalb der App umbenannt oder verschoben, kann der Pfad-Verweis brechen; die
    App muss das erkennen und zum Neuverknüpfen auffordern.

### Confirmation

Eine Zuordnung speichert nie Dateiinhalt, nur Verweise; AK-9, AK-11, AK-12 und AK-19 bestehen.

### Revisit if

- Mehr als 20 % der Lehrkräfte nutzen Google Drive und melden fehlendes Speichern aus Google-Apps
  (dann direkte Google-Anbindung prüfen).
- Der Test zu RISK-2 zeigt, dass PowerPoint aus der Dateien-App heraus auch bei OneDrive mit
  AutoSpeichern öffnet (dann ist der Graph-Zusatz evtl. überflüssig).

## Pros and Cons of the Options

### Dateien-App als Grundlage, OneDrive zusätzlich direkt

- Vorzug: breite Abdeckung plus bestes Verhalten für Microsoft 365.
- Nachteil: zwei Zugriffswege.

### Nur Dateien-App

- Vorzug (verworfen): ein einziger Mechanismus, keine Anmeldung, kein Microsoft-Konto nötig – am
  einfachsten zu bauen.
- Nachteil: OneDrive-Dateien öffnen in PowerPoint möglicherweise ohne AutoSpeichern; FR-5.1 wäre nicht
  sicher erfüllbar.

### Je Anbieter eine direkte Anbindung

- Vorzug (verworfen): bester Stand und gezieltes Vorladen bei jedem unterstützten Anbieter.
- Nachteil: eine Anmeldung und eigene Arbeit je Anbieter; nicht unterstützte Anbieter (z. B.
  Schul-Nextcloud) fallen ganz heraus – widerspricht NFR-3.

## More Information

- Area doc: docs/ARCHITECTURE.md#area-ablage
