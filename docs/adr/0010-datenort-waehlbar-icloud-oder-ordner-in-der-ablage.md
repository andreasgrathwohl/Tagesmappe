---
status: accepted
date: 2026-11-14
reversibility: one-way
area: daten
---

# ADR-0010 — Datenort wählbar: iCloud oder ein Ordner in der Ablage

- Supersedes: ADR-0002

## Context and Problem Statement

ADR-0002 legte alle App-Daten (Stundenplan, Abweichungen, Zuordnungen, Stiftnotizen, Stundenangaben,
Tafelseiten) in SwiftData, gespiegelt in die private iCloud-Datenbank. Als Kosten stand dort: „Ohne
iCloud kein Abgleich zwischen Geräten.“ Andreas am 2026-11-14: „Nicht jeder nutzt iCloud, daher soll es
auswählbar sein“ – und zwar für alle App-Daten, mit der Wahl zwischen iCloud und einem beliebigen
Ordner in der Ablage (OneDrive, Google Drive, Schul-Nextcloud, iCloud Drive). Die Umkehrkosten sind
hoch: Der Datenort bestimmt Abgleich, Konfliktverhalten und das Datenformat, das in den Ablagen der
Lehrkräfte liegt.

## Decision Drivers

- Lehrkräfte ohne iCloud sollen am Mac vorbereiten und am iPad unterrichten können
- unabhängig vom Ablage-Anbieter (NFR-3), auch ohne Microsoft 365 (CON-2)
- keine Server des Produkts (NFR-2)
- offline voll nutzbar, später abgleichen (RISK-3)
- der in ADR-0002 belegte Grund gegen eine Plan-Datei: zwei Geräte, die **dieselbe** Datei schreiben,
  erzeugen Konfliktkopien und Datenverlust

## Considered Options

- Wählbar: iCloud (wie bisher) oder ein Ordner in der Ablage, dort **eine Datei je Datensatz**
- Wählbar: iCloud oder OneDrive über Microsoft Graph
- Nur iCloud (ADR-0002) – ohne iCloud nur auf einem Gerät
- Eine einzige Plan-Datei in der Ablage

## Decision Outcome

Chosen option: "Wählbar: iCloud oder ein Ordner in der Ablage, eine Datei je Datensatz", because es
jede Ablage abdeckt und den Konflikt, an dem die Plan-Datei in ADR-0002 scheiterte, vermeidet: Zwei
Geräte schreiben nur dann dieselbe Datei, wenn sie denselben Datensatz ändern – dann gilt wie bei
iCloud der zuletzt geschriebene Stand. Andreas wählte Umfang und Orte am 2026-11-14.

Festgelegt:

- Gearbeitet wird immer lokal mit SwiftData. Der Datenort bestimmt nur, **wie abgeglichen** wird:
  „iCloud“ = SwiftData-Spiegelung in die private iCloud-Datenbank (ADR-0002 unverändert);
  „Ordner in der Ablage“ = SwiftData ohne Spiegelung, plus ein eigener Abgleich über Dateien.
- Im Ordner liegt je Datensatz eine JSON-Datei mit Kennung, Änderungszeitpunkt und Inhalt;
  Zeichnungen und Bilder als eigene Dateien daneben. Löschen schreibt eine Löschmarke statt die Datei
  zu entfernen. Die Regeln des Zusammenführens (älteste behalten, fachlicher Schlüssel) gelten
  unverändert für beide Datenorte.
- Der Datenort wird beim Einrichten gewählt und je Gerät gespeichert; auf jedem Gerät derselben
  Lehrkraft muss derselbe Ort gewählt sein. Ein Wechsel zieht alle Daten einmal um.
- Die App schreibt in diesen Datenordner, **nie** in Material-Dateien (FR-3.4, ADR-0006 bleiben).

### Consequences

- Nutzen: Frontstage funktioniert ohne iCloud geräteübergreifend; Daten liegen dort, wo die Schule sie
  haben will (z. B. Microsoft 365); keine Server.
- Kosten (Pflicht):
  - Ein eigener Abgleich über Dateien muss gebaut und getestet werden (Beobachten des Ordners,
    Konflikte je Datensatz, Löschmarken, Zeichnungsdaten) – ein eigener Teilplan.
  - Aktualität hängt vom Ablage-Anbieter ab: Wann eine Datei vom Mac auf dem iPad ankommt, bestimmt der
    Anbieter, nicht die App (RISK-9).
  - Die App schreibt nun doch in die Ablage – in einen eigenen Ordner. Das Verhalten der Anbieter beim
    Schreiben ist nur durch Ausprobieren belegt (wie in ADR-0003).
  - Zwei Wege für dieselben Daten: Jede Änderung am Datenmodell muss in beiden Abgleichwegen
    funktionieren.
  - Gleichzeitiges Bearbeiten desselben Datensatzes auf zwei Geräten verliert wie bei iCloud den
    früheren Stand.

### Revisit if

- Ein Ablage-Anbieter erzeugt trotz einer Datei je Datensatz regelmäßig Konfliktkopien oder verliert
  Änderungen.
- Weniger als 5 % der Lehrkräfte wählen den Ordner – dann den eigenen Abgleich zurückbauen.

## Pros and Cons of the Options

### Wählbar, Ordner mit einer Datei je Datensatz

- Vorzug: jede Ablage, kein Server, Konflikte nur je Datensatz.
- Nachteil: eigener Abgleich, Aktualität vom Anbieter abhängig.

### Wählbar, iCloud oder OneDrive über Graph

- Vorzug (verworfen): Änderungen über die Graph-Schnittstelle gezielt abfragbar (Delta), unabhängig von
  der Dateien-App.
- Nachteil: nur Microsoft 365 – Lehrkräfte mit Google Drive oder Nextcloud blieben ohne Abgleich.

### Nur iCloud

- Vorzug (verworfen): nichts zu bauen, Abgleich durch das System.
- Nachteil: ohne iCloud kein Vorbereiten am Mac – genau das, was Andreas ausschließen will.

### Eine einzige Plan-Datei

- Vorzug (verworfen): eine Datei, einfach zu sichern und von anderen Apps lesbar.
- Nachteil: zwei Geräte schreiben dieselbe Datei – Konfliktkopien und Datenverlust (Grund aus ADR-0002).

## More Information

- Area doc: docs/ARCHITECTURE.md#area-daten
