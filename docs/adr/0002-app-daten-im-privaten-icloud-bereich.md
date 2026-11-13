---
status: superseded by ADR-0010
date: 2026-11-13
reversibility: one-way
area: daten
---

# ADR-0002 — App-Daten im privaten iCloud-Bereich

## Context and Problem Statement

Stundenplan, Unterrichtsstunden und Zuordnungen entstehen am Mac oder Tablet und müssen auf dem
jeweils anderen Gerät sofort erscheinen (FR-3, AK-4, AK-5). Das Produkt betreibt keine eigenen Server
(NFR-2), und das Tablet gehört genau einer Lehrkraft (PRD, Q-13). Die Umkehrkosten sind hoch: Wo die
Wahrheit dieser Daten liegt, bestimmt Datenmodell, Abgleich und Konfliktverhalten; ein Wechsel
bedeutet Datenumzug bei jeder Lehrkraft.

## Decision Drivers

- keine eigenen Server, keine Nutzerdaten beim Anbieter (NFR-2)
- Abgleich zwischen Mac und Tablet ohne Zutun
- funktioniert auch ohne Netz (Schulnetz, RISK-3) und gleicht später ab
- ein Gerät = eine Lehrkraft

## Considered Options

- Lokale Datenhaltung mit SwiftData, gespiegelt in die private iCloud-Datenbank (CloudKit) der Lehrkraft
- Eine Plan-Datei (z. B. JSON) in der Ablage der Lehrkraft, von beiden Geräten gelesen und geschrieben
- Eigener Server mit Konto beim Produkt

## Decision Outcome

Chosen option: "Lokale Datenhaltung mit SwiftData, gespiegelt in die private iCloud-Datenbank", because
sie ohne eigene Server abgleicht, offline voll funktioniert und Konflikte auf Datensatzebene statt auf
Dateiebene behandelt. Andreas stimmte am 2026-11-13 dem Abgleich über iCloud zu.

### Consequences

- Nutzen: keine Server, keine Konten beim Produkt; Daten liegen im Apple-Konto der Lehrkraft;
  Offline-Betrieb und späterer Abgleich durch das System; Datenschutz-Argument für Schulen.
- Kosten (Pflicht):
  - Eine Lehrkraft braucht ein Apple-Konto mit iCloud; ohne iCloud kein Abgleich zwischen Geräten.
  - Die CloudKit-Spiegelung erzwingt Regeln im Datenmodell: keine Eindeutigkeitsregeln
    (`@Attribute(.unique)`/`#Unique` sind nicht erlaubt und brechen sonst auch die lokalen Daten), alle
    Eigenschaften optional oder mit Vorgabewert, alle Beziehungen optional. Eindeutigkeit (z. B. eine
    Unterrichtsstunde nicht doppelt) muss die App selbst sicherstellen und Dubletten nach dem Abgleich
    zusammenführen.
  - Gleichzeitige Änderung desselben Datensatzes auf zwei Geräten: der zuletzt abgeglichene Stand
    gewinnt; feinere Konfliktregeln muss die App selbst bauen (siehe Architecture Doc, Nebenläufigkeit).
  - Mehrere Lehrkräfte auf einem Gerät sind ausgeschlossen (PRD, Out of Scope); Teilen von Plänen
    zwischen Lehrkräften bräuchte später geteilte CloudKit-Bereiche.
  - Kein Zugriff auf diese Daten außerhalb von Apple-Geräten (passt zu ADR-0001).

### Confirmation

Alle Modelle sind SwiftData-`@Model`-Klassen mit aktivierter CloudKit-Spiegelung auf die private
Datenbank; kein Modell nutzt `#Unique` oder `@Attribute(.unique)`; AK-4 und AK-5 bestehen.

### Revisit if

- Lehrkräfte wollen Pläne mit Kolleginnen teilen (dann geteilte CloudKit-Bereiche prüfen).
- Mehr als 5 % der Rückmeldungen melden verlorene oder doppelte Zuordnungen nach dem Abgleich.

## Pros and Cons of the Options

### SwiftData mit Spiegelung in die private iCloud-Datenbank

- Vorzug: kein Server, offline, Abgleich durch das System, Daten im Konto der Lehrkraft.
- Nachteil: Modellregeln der Spiegelung; Konfliktauflösung grob; nur Apple.

### Plan-Datei in der Ablage der Lehrkraft

- Vorzug (verworfen): offen und für andere Apps lesbar; anbieterunabhängig; keine Apple-Bindung der
  Daten.
- Nachteil: zwei Geräte schreiben dieselbe Datei – Konflikte entstehen auf Dateiebene und erzeugen
  „Konfliktkopien“ beim Anbieter; Aktualität hängt vom Ablage-Anbieter ab; Offline-Schreiben auf
  beiden Geräten führt zu Datenverlust ohne eigene Zusammenführung.

### Eigener Server mit Konto

- Vorzug (verworfen): volle Kontrolle über Abgleich, Teilen und plattformübergreifenden Zugriff.
- Nachteil: widerspricht NFR-2; Betrieb, Haftung und Datenschutz-Prüfung bei jeder Schule.

## More Information

- Area doc: docs/ARCHITECTURE.md#area-daten
