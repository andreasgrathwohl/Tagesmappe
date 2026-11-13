---
status: proposed
date: 2026-11-13
reversibility: one-way
area: daten
---

# ADR-0005 — Unterrichtsstunde: Identität über Datum und Klasse

## Context and Problem Statement

Material hängt an Unterrichtsstunden (Glossar, FR-3). Der Stundenplan kann sich ändern – von Hand oder
durch einen Schulmanager-Import (FR-2): eine Klasse wandert von der 2. in die 3. Stunde, ein Fach
kommt dazu. Die Frage ist, woran eine Unterrichtsstunde wiedererkannt wird, damit die Zuordnungen
einer Lehrkraft eine solche Änderung überstehen. Die Umkehrkosten sind hoch: Die Identität steckt in
jeder gespeicherten Zuordnung; ein Wechsel heißt, alle Zuordnungen aller Lehrkräfte umzuschreiben,
mit Verlustrisiko.

## Decision Drivers

- Vorbereitetes Material darf bei einer Stundenplan-Änderung nicht verloren gehen oder in der falschen
  Klasse landen
- Lehrkräfte denken „Dienstag, 8b Englisch“, nicht „Dienstag, 2. Stunde“
- Doppelstunden und zwei Stunden derselben Klasse am selben Tag müssen unterscheidbar sein
- Eindeutigkeit muss die App selbst sichern (ADR-0002: keine Eindeutigkeitsregeln in der Datenhaltung)

## Considered Options

- Datum + Klasse + Fach + laufende Nummer am Tag (Material folgt der Klasse)
- Datum + Stunde (Material bleibt am Zeitfeld)
- Eigene Kennung je Unterrichtsstunde, beim Anlegen vergeben, ohne fachliche Bedeutung

## Decision Outcome

Chosen option: "Datum + Klasse + Fach + laufende Nummer am Tag", because das Material für „8b Englisch
am Dienstag“ vorbereitet wird und auch dann dort bleiben soll, wenn die Stunde im Plan verschoben wird.
**Vorgeschlagen, wartet auf Bestätigung (Q-14).**

### Consequences

- Nutzen: Verschiebt sich eine Stunde im Plan, wandert das Material mit der Klasse; Parallelklassen und
  Weiterschieben (FR-3.2, FR-3.3) lassen sich über Klasse und Fach eindeutig ausdrücken.
- Kosten (Pflicht): Ändert sich der Klassenname (z. B. Schuljahreswechsel 8b → 9b) oder die
  Schreibweise beim Import („8 b“, „08b“), passt keine Zuordnung mehr – Klassennamen müssen
  normalisiert und ein Schuljahreswechsel ausdrücklich behandelt werden. Fällt eine Klasse an einem Tag
  ganz weg, hat ihr Material keine Stunde mehr und muss sichtbar „ohne Stunde“ bleiben statt zu
  verschwinden (wie FR-7 bei unterrichtsfreien Tagen).

### Revisit if

- Lehrkräfte melden, dass Material nach einem Stundenplan-Import in einer anderen Klasse auftaucht oder fehlt.

## Pros and Cons of the Options

### Datum + Klasse + Fach + laufende Nummer

- Vorzug: Material folgt der Klasse.
- Nachteil: hängt an gleichbleibenden Klassennamen.

### Datum + Stunde

- Vorzug (verworfen): einfachste Identität, unabhängig von Klassennamen und Schreibweisen.
- Nachteil: Wird 8b von der 2. in die 3. Stunde verschoben, steht ihr Material plötzlich bei der Klasse,
  die jetzt die 2. Stunde hat – vor der falschen Klasse geöffnet.

### Eigene Kennung ohne Bedeutung

- Vorzug (verworfen): stabil gegen Umbenennungen; keine Normalisierung nötig.
- Nachteil: Nach einem Import weiß niemand, welche neue Stunde welcher alten entspricht – die
  Zuordnung müsste doch über Datum und Klasse geraten werden; zusätzlich Dubletten nach dem Abgleich
  (ADR-0002) ohne fachlichen Schlüssel zum Zusammenführen.

## More Information

- Area doc: docs/ARCHITECTURE.md#area-daten

## Open Questions

- Q-14: Soll vorbereitetes Material der Klasse folgen, wenn deren Stunde im Stundenplan verschoben wird (Vorschlag), oder am Zeitfeld bleiben?
