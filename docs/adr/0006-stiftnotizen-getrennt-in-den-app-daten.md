---
status: superseded by ADR-0011
date: 2026-11-13
reversibility: one-way
area: anzeige
---

# ADR-0006 — Stiftnotizen liegen getrennt in den App-Daten

## Context and Problem Statement

PDFs und Bilder zeigt die App selbst, und die Lehrkraft schreibt und zeichnet darauf mit dem Stift
(FR-6). Die Frage ist, wo diese Stiftnotizen liegen: in der Datei in der Ablage oder getrennt davon
bei den übrigen App-Daten. Das ist eine Frage, wo die Wahrheit liegt. Die Umkehrkosten sind hoch: Nach
einem Wechsel müssten alle bis dahin entstandenen Stiftnotizen aller Lehrkräfte in die Dateien
hineingeschrieben oder aus ihnen herausgelöst werden – das eine verändert Originale nachträglich, das
andere ist bei Bildern nicht verlustfrei möglich.

## Decision Drivers

- Dasselbe Arbeitsblatt wird in mehreren Klassen und im nächsten Schuljahr wieder gezeigt; es soll
  dann nicht die Notizen der letzten Stunde tragen
- Es gibt nur einen Stand je Datei (FR-3.4); die App soll diesen Stand nicht selbst verändern
- Die App schreibt nicht in fremde Ablagen: Deren Verhalten beim Schreiben ist je Anbieter verschieden
  und nur durch Ausprobieren belegt (ADR-0003)
- Eine Notiz muss das Schließen und erneute Öffnen überstehen (AK-13)

## Considered Options

- Getrennt in den App-Daten, gespiegelt wie Stundenplan und Zuordnungen
- In der Datei in der Ablage
- Getrennt in den App-Daten, zusätzlich Export als beschriftete Kopie

## Decision Outcome

Chosen option: "Getrennt in den App-Daten", because das Original in der Ablage dadurch unberührt
bleibt und die App nirgends in die Ablage schreiben muss. Andreas entschied am 2026-11-13 so (Q-17).

### Consequences

- Nutzen: Das Material bleibt für die nächste Klasse sauber. Kein Schreibzugriff auf die Ablage, also
  keine Schreibkonflikte mit dem Anbieter und kein Risiko, ein Original zu beschädigen. Stiftnotizen
  erscheinen über die Spiegelung (ADR-0002) ohne Zutun auf dem zweiten Gerät.
- Kosten (Pflicht): Stiftnotizen sieht nur diese App – wer das PDF in einer anderen App oder am
  Smartboard-Rechner öffnet, sieht sie nicht, und sie lassen sich nicht mit der Datei weitergeben.
  Die Notiz hängt an Seite und Lage im Dokument: Wird die Datei in der Ablage ersetzt oder umgebaut
  (Seite eingefügt, Bild beschnitten), liegen Notizen daneben oder auf der falschen Seite. Wird die
  Datei so verschoben, dass der Verweis nicht mehr auflöst, hängen ihre Notizen bis zum
  Neuverknüpfen an nichts. Zeichnungsdaten vergrößern den gespiegelten Datenbestand im iCloud-Konto
  der Lehrkraft.

### Revisit if

- Lehrkräfte wollen beschriftete PDFs weitergeben (an Kolleginnen, an die Klasse) oder in einer anderen
  App weiterverwenden.
- Stiftnotizen liegen nach Änderungen an der Datei wiederholt an der falschen Stelle.

## Pros and Cons of the Options

### Getrennt in den App-Daten

- Vorzug: Original unberührt, kein Schreiben in die Ablage.
- Nachteil: Notizen nur in dieser App sichtbar; hängen an Seite und Lage.

### In der Datei in der Ablage

- Vorzug (verworfen): Die Notiz gehört zur Datei – jede App und jedes Gerät sieht sie, sie zieht mit
  der Datei um, und es gibt nichts abzugleichen. Entspricht dem, was PowerPoint mit Zeichnungen tut
  (FR-5.1).
- Nachteil: Das Arbeitsblatt für die nächste Klasse trägt die Notizen der letzten; bei Bildern sind
  Notizen eingebrannt und nicht mehr zu entfernen; die App müsste in jede Ablage schreiben können.

### Getrennt, zusätzlich Export als beschriftete Kopie

- Vorzug (verworfen): verbindet beides – Original bleibt sauber, und eine beschriftete Fassung lässt
  sich bei Bedarf weitergeben.
- Nachteil: Es entsteht eine zweite Datei und damit ein zweiter Stand, was FR-3.4 für diesen Fall
  aufweicht; mehr Bauaufwand in der ersten Version. Kann später als Ergänzung nachkommen, ohne diese
  Entscheidung zu ersetzen (siehe Revisit if).

## More Information

- Area doc: docs/ARCHITECTURE.md#area-anzeige

## Open Questions

- ~~Q-17~~: Wo liegen Stiftnotizen auf PDFs und Bildern – in der Datei in der Ablage oder getrennt in den App-Daten? → answered 2026-11-13: getrennt in den App-Daten.
