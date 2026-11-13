---
status: accepted
date: 2026-11-13
reversibility: one-way
area: plattform
---

# ADR-0009 — Quellcode englisch, Kommentare deutsch

- Amends: ADR-0008

## Context and Problem Statement

Das Glossar im PRD ist bindend für Dokumente und Code. Offen war, in welcher Sprache Bezeichner im Code
stehen (Typen, Funktionen, Variablen, Dateien, Ordner, Paketnamen) und in welcher Kommentare. Die
Umkehrkosten steigen mit jeder Zeile: Vor dem ersten Code kostet die Entscheidung nichts, danach heißt
ein Wechsel, jede Datei und jede Schnittstelle umzubenennen.

## Decision Drivers

- Apples Schnittstellen, Swift und fast alle Beispiele sind englisch; gemischte Bezeichner lesen sich holprig
- Der Entwickler erklärt und prüft auf Deutsch; Begründungen im Code sollen ohne Übersetzung verständlich sein
- Fachbegriffe dürfen im Code nicht vom Glossar abweichen

## Considered Options

- Bezeichner englisch nach Glossar-Spalte „Im Code“, Kommentare deutsch
- Bezeichner und Kommentare deutsch
- Bezeichner und Kommentare englisch

## Decision Outcome

Chosen option: "Bezeichner englisch, Kommentare deutsch", because es Swift und Apples APIs folgt und
Begründungen trotzdem in der Sprache des Entwicklers stehen. Andreas legte das am 2026-11-13 fest
(„der Sourcecode muss englisch sein, Kommentare auch deutsch“).

- Alle Bezeichner, Datei-, Ordner-, Ziel- und Paketnamen sind englisch. Fachbegriffe nehmen genau den
  Namen aus der Spalte „Im Code“ des Glossars im PRD; ein neuer Fachbegriff bekommt dort zuerst eine
  Zeile, dann erst Code.
- Kommentare und Doku-Kommentare (`///`) sind deutsch.
- Testnamen sind englisch; die Beschreibung im `@Test("…")`-Text darf deutsch sein und nennt das AK.
- Oberflächentexte bleiben deutsch in `Localizable.xcstrings`; ihre Schlüssel sind englisch.
- Ergänzt ADR-0008: Das Kern-Paket heißt `FrontstageCore` (`Packages/FrontstageCore`) statt
  `FrontstageKern`.

### Consequences

- Nutzen: Code liest sich wie Apples Beispiele; die Brücke Fachsprache ↔ Code steht an einer Stelle.
- Kosten (Pflicht): Zwei Namen je Fachbegriff – im Gespräch und in Dokumenten deutsch, im Code englisch;
  die Glossar-Spalte muss gepflegt werden, sonst entstehen zwei englische Namen für einen Begriff.
  Englische Begriffe wie `Lesson` oder `Board` tragen nicht jede Nuance des deutschen (etwa
  Unterrichtsstunde gegenüber Stunde als Zeitfeld, im Code `period`).

### Revisit if

- Ein Mitentwickler ohne Deutschkenntnisse kommt dazu – dann auch Kommentare englisch.

## Pros and Cons of the Options

### Bezeichner englisch, Kommentare deutsch

- Vorzug: idiomatischer Swift-Code, Begründungen auf Deutsch.
- Nachteil: Übersetzungstabelle nötig.

### Alles deutsch

- Vorzug (verworfen): Fachbegriffe ohne Übersetzung, Glossar und Code identisch.
- Nachteil: Mischung mit englischen APIs (`func unterrichtsstunden(…) -> some View`), Umlaute nicht in
  Bezeichnern üblich.

### Alles englisch

- Vorzug (verworfen): international lesbar, ein Sprachraum im Code.
- Nachteil: Begründungen in Kommentaren nicht in der Sprache des Entwicklers.

## More Information

- Area doc: docs/ARCHITECTURE.md#area-plattform
- Glossar: docs/PRD.md#glossar--bindend (Spalte „Im Code“)
