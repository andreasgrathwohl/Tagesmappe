---
status: accepted
date: 2026-11-13
reversibility: two-way
area: stundenplan-quellen
---

# ADR-0004 — Schulmanager als austauschbarer Importbaustein

## Context and Problem Statement

Der Stundenplan soll alternativ aus Schulmanager Online kommen (FR-2, MVP). Schulmanager bietet keine
offizielle Schnittstelle; inoffizielle Bibliotheken melden sich wie ein Browser an, warnen selbst vor
Risiken und vor häufigen Abfragen (RISK-1). Zugangsdaten bleiben auf dem Gerät (NFR-4). Später soll
WebUntis dazukommen (FR-2.1). Die Umkehrkosten sind gering, solange die Anbindung hinter einer eigenen
Grenze liegt: Sie lässt sich dann austauschen oder abschalten, ohne Datenmodell oder Oberfläche zu
ändern.

## Decision Drivers

- Ausfall oder Änderung bei Schulmanager darf das Produkt nicht lahmlegen
- seltene Abfragen (Warnung der Bibliotheken, Kontosperre vermeiden)
- Zugangsdaten nur im Schlüsselbund (NFR-4)
- weitere Quellen (WebUntis) ohne Umbau

## Considered Options

- Eigener Importbaustein hinter einer gemeinsamen Quellen-Schnittstelle; Import auf Knopfdruck und automatisch einmal je Morgen; Ergebnis wird als normaler Stundenplan gespeichert
- Laufender Abgleich: Schulmanager bei jedem App-Start bzw. stündlich abfragen, Stundenplan nie lokal pflegen
- Kein Schulmanager im Produkt, nur von Hand

## Decision Outcome

Chosen option: "Eigener Importbaustein, Import auf Knopfdruck und einmal je Morgen", because er die
Abhängigkeit hinter einer Grenze hält, den von Hand gepflegten Stundenplan als Rückfall immer erhält,
die Abfragen selten hält und Vertretungen trotzdem am Morgen zeigt (FR-2.2). Andreas am 2026-11-13:
Vertretungen „müssen morgens da sein“ (Q-15).

Der Morgen-Import läuft beim ersten Öffnen der App am Tag und zusätzlich, soweit das System es
zulässt, als Hintergrund-Aktualisierung vor Unterrichtsbeginn. Das System garantiert keine feste
Uhrzeit für Hintergrund-Aktualisierungen – maßgeblich ist deshalb der Abruf beim ersten Öffnen; die
Tagesansicht zeigt, von wann der Stand ist.

### Consequences

- Nutzen: Ein Bruch bei Schulmanager betrifft nur den Import; Stundenplan und Zuordnungen bleiben
  nutzbar; WebUntis kommt als zweiter Baustein derselben Schnittstelle dazu; ein bis zwei Abfragen je
  Tag und Lehrkraft.
- Kosten (Pflicht): Änderungen, die Schulmanager erst im Lauf des Vormittags einträgt, erscheinen nur
  nach „Aktualisieren“ von Hand. Ist morgens kein Netz da, zeigt die Tagesansicht den Stand des
  Vortags – sichtbar gekennzeichnet. Ein Import, der einen von Hand geänderten Eintrag überschreiben
  würde, braucht eine Rückfrage (AK-3) – zusätzliche Oberfläche. Die Anbindung muss gepflegt werden,
  wann immer Schulmanager seine Seite ändert, ohne dass wir davon erfahren. Ob Lehrerkonten überhaupt
  Stundenplan und Vertretungen liefern, ist ungeprüft (Q-16 im PRD).

### Revisit if

- Schulmanager bietet eine offizielle Schnittstelle oder Partnerschaft an.
- Der Import bricht innerhalb von drei Monaten mehr als zweimal.
- Die Prüfung zu Q-16 zeigt, dass Lehrerkonten keine Vertretungen liefern.

## Pros and Cons of the Options

### Eigener Importbaustein, auf Knopfdruck und einmal je Morgen

- Vorzug: robust, austauschbar, schont das Konto; Vertretungen morgens da.
- Nachteil: Änderungen im Lauf des Tages nur nach Aktualisieren von Hand.

### Laufender Abgleich

- Vorzug (verworfen): Vertretungen und Änderungen erscheinen nahezu sofort.
- Nachteil: viele Abfragen gegen eine inoffizielle Schnittstelle (Sperrrisiko); bricht Schulmanager,
  steht die Tagesansicht ohne Stundenplan da.

### Kein Schulmanager

- Vorzug (verworfen): kein Fremdrisiko, kein Pflegeaufwand.
- Nachteil: widerspricht FR-2 (MVP, von Andreas bestätigt).

## More Information

- Area doc: docs/ARCHITECTURE.md#area-stundenplan-quellen

## Open Questions

- ~~Q-15~~: Dürfen Vertretungen aus Schulmanager mit bis zu einem Tag Verzögerung ankommen, oder muss das Produkt sie am selben Morgen zeigen? → answered 2026-11-13: am selben Morgen (FR-2.2); Import einmal je Morgen und auf Knopfdruck.
