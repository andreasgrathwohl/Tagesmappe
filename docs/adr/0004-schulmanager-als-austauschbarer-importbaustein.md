---
status: proposed
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

- Eigener Importbaustein hinter einer gemeinsamen Quellen-Schnittstelle; Import nur auf Knopfdruck und höchstens einmal täglich automatisch; Ergebnis wird als normaler Stundenplan gespeichert
- Laufender Abgleich: Schulmanager bei jedem App-Start bzw. stündlich abfragen, Stundenplan nie lokal pflegen
- Kein Schulmanager im Produkt, nur von Hand

## Decision Outcome

Chosen option: "Eigener Importbaustein, Import auf Knopfdruck und höchstens täglich", because er die
Abhängigkeit hinter einer Grenze hält, den von Hand gepflegten Stundenplan als Rückfall immer erhält
und die Abfragen selten hält. **Noch offen:** ob Vertretungen aus Schulmanager mit bis zu einem Tag
Verzögerung ankommen dürfen (Q-15).

### Consequences

- Nutzen: Ein Bruch bei Schulmanager betrifft nur den Import; Stundenplan und Zuordnungen bleiben
  nutzbar; WebUntis kommt als zweiter Baustein derselben Schnittstelle dazu.
- Kosten (Pflicht): Vertretungen und kurzfristige Änderungen aus Schulmanager erscheinen erst beim
  nächsten Import; ein Import, der einen von Hand geänderten Eintrag überschreiben würde, braucht eine
  Rückfrage (AK-3) – zusätzliche Oberfläche. Die Anbindung muss gepflegt werden, wann immer
  Schulmanager seine Seite ändert, ohne dass wir davon erfahren.

### Revisit if

- Schulmanager bietet eine offizielle Schnittstelle oder Partnerschaft an.
- Der Import bricht innerhalb von drei Monaten mehr als zweimal.

## Pros and Cons of the Options

### Eigener Importbaustein, selten

- Vorzug: robust, austauschbar, schont das Konto.
- Nachteil: Vertretungen verzögert.

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

- Q-15: Dürfen Vertretungen aus Schulmanager mit bis zu einem Tag Verzögerung ankommen, oder muss das Produkt sie am selben Morgen zeigen?
