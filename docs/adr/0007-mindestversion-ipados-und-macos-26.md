---
status: accepted
date: 2026-11-13
reversibility: two-way
area: plattform
---

# ADR-0007 — Mindestversion iPadOS 26 und macOS 26

## Context and Problem Statement

Gemäß ADR-0001 ist Frontstage eine native App für iPad und Mac. Offen war, ab welcher Systemversion sie
läuft. Das bestimmt, welche Tablets von Lehrkräften unterstützt werden, welche Schnittstellen ohne
Versionsweiche nutzbar sind, und ob der Zweitbildschirm (FR-6.2) zwei Code-Wege braucht: Ab iOS 27
bekommt eine App die Szene für einen verbundenen Bildschirm nur nach Anmeldung eines Szenen-Zubehörs,
davor verbindet das System sie von selbst. Die Umkehrkosten sind gering: Die Mindestversion lässt sich
mit jedem Update anheben; nur Senken unter 26 wäre teuer (SwiftData-Abgleich und Oberfläche).

## Decision Drivers

- Lehrkräfte haben oft ältere iPads; die App soll sie nicht ausschließen
- SwiftData mit iCloud-Spiegelung (ADR-0002) soll ohne bekannte Schwächen älterer Versionen laufen
- Möglichst wenige Versionsweichen in einem Projekt, das ohne Mac entwickelt wird

## Considered Options

- iPadOS 26 und macOS 26
- iPadOS 27 und macOS 27
- iPadOS 18 und macOS 15

## Decision Outcome

Chosen option: "iPadOS 26 und macOS 26", because es alle Geräte einschließt, die das Vorjahressystem
bekommen haben, und die aktuelle Gestaltung des Systems ohne Weiche nutzt. Andreas entschied am
2026-11-13.

### Consequences

- Nutzen: größere Reichweite unter Lehrkräften als 27; eine Gestaltungsgrundlage (Systemstand 26).
- Kosten (Pflicht): Der Zweitbildschirm braucht zwei Wege – ab 27 Anmelden des Szenen-Zubehörs, auf 26
  die vom System verbundene Szene annehmen – und beide müssen getestet werden. Jede weitere neue
  Schnittstelle aus 27 braucht eine `if #available`-Weiche.

### Revisit if

- Weniger als etwa 5 % der Testerinnen nutzen noch iPadOS 26 – dann auf 27 anheben und die Weiche
  entfernen.

## Pros and Cons of the Options

### iPadOS 26 und macOS 26

- Vorzug: Reichweite bei einem Code-Stand.
- Nachteil: zwei Wege für den Zweitbildschirm.

### iPadOS 27 und macOS 27

- Vorzug (verworfen): ein einziger Code-Weg, neueste Schnittstellen ohne Weiche.
- Nachteil: Wessen iPad 27 nicht mehr bekommt, kann die App nicht nutzen.

### iPadOS 18 und macOS 15

- Vorzug (verworfen): größte Reichweite.
- Nachteil: viele Weichen, ältere Gestaltung, SwiftData mit bekannten Schwächen beim Abgleich.

## More Information

- Area doc: docs/ARCHITECTURE.md#area-plattform
