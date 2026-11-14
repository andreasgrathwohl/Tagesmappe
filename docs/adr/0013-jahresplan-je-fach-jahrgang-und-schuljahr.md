---
status: accepted
date: 2026-11-14
reversibility: one-way
area: daten
---

# ADR-0013 — Jahresplan je Fach, Jahrgang und Schuljahr

## Context and Problem Statement

Andreas wünscht am 2026-11-14 eine Vorplanung des Schuljahrs: in welcher Woche welches Thema behandelt
wird, wann Tests und Klassenarbeiten geschrieben werden, mit Notizen, „pro Fach und Jahrgang“
gespeichert, und mit einem schnellen Überblick darüber, was für Fach und Klassenstufe in den letzten
Jahren gemacht wurde (FR-15). Zu entscheiden ist, woran ein Jahresplan hängt – an einer Klasse oder an
einem Jahrgang – und woran ein Schuljahr und eine Woche des Plans wiedererkannt werden. Die Umkehrkosten
sind hoch: Die Planungseinheit steckt im Schlüssel jedes gespeicherten Jahresplans, im Dateiformat des
Datenordners (ADR-0012), im Zusammenführen nach dem Abgleich und in der Verknüpfung mit Vorbereiten und
Tagesansicht. Ein Wechsel hieße, alle Pläne aller Jahre umzuschreiben oder aufzuteilen.

## Decision Drivers

- Parallelklassen (8a, 8b) werden in der Regel gleich geplant; doppelte Pflege kostet Zeit und läuft auseinander
- Der Rückblick über Jahre (FR-15.3) und „Vorjahresplan übernehmen“ (FR-15.4) brauchen einen Schlüssel, der von
  Jahr zu Jahr gleich bleibt – Klassennamen tun das nicht (aus der 8b wird die 9b, eine neue 8b kommt)
- Identität ohne Eindeutigkeitsregeln in der Datenhaltung, Dubletten nach dem Abgleich müssen über einen fachlichen
  Schlüssel zusammenführbar sein (ADR-0012, ADR-0002)
- Wochen müssen eine Änderung der Schuljahresdaten oder der Ferien überstehen, ohne dass Einträge verloren gehen

## Considered Options

- Fach + Jahrgang + Schuljahr; Klassen des Jahrgangs folgen, Abweichungen als Notiz
- Fach + Klasse + Schuljahr (ein Jahresplan je Klasse)
- Fach + Jahrgang ohne Schuljahr (ein fortlaufender Plan, jedes Jahr überschrieben)

## Decision Outcome

Chosen option: "Fach + Jahrgang + Schuljahr", because ein Plan für alle Parallelklassen reicht und der
Schlüssel Jahr für Jahr vergleichbar bleibt. Andreas hat die Planungseinheit am 2026-11-14 so vorgegeben
(„pro Fach und Jahrgang abspeichern“); die Festlegungen unten hat der Controller am selben Tag
entschieden.

Festgelegt:

- **Schlüssel des Jahresplans:** Fach (normalisiert wie `Subject`) + Jahrgang (Zahl) + Schuljahr. Gibt es nach
  dem Abgleich zwei Jahrespläne mit gleichem Schlüssel, bleibt der ältere, die Einträge des anderen wandern
  zu ihm.
- **Schuljahr** wird über das Kalenderjahr seines ersten Schultags erkannt (`startYear`, 2026 für „2026/27“),
  nicht über eine Kennung. Erster Schultag, Beginn des zweiten Halbjahrs und letzter Schultag setzt die
  Lehrkraft; zwei Schuljahre dürfen sich nicht überschneiden.
- **Jahrgang einer Klasse:** die erste Ziffernfolge des normalisierten Klassennamens („8b“ → 8, „q11“ → 11);
  ohne Ziffern („ef“) setzt die Lehrkraft ihn von Hand, gespeichert je Schuljahr und Klasse.
- **Planwoche** wird über den Montag ihrer Kalenderwoche erkannt, nicht über die laufende Nummer: Ändern sich
  Daten des Schuljahrs oder Ferien, bleibt ein Eintrag an seiner Kalenderwoche; ist sie keine
  Unterrichtswoche mehr, steht er unter „nicht zugeordnet“. Die Nummer (Woche 1, 2, …) wird berechnet.
- **Unterrichtswochen** werden berechnet, nicht gespeichert: Kalenderwochen im Schuljahr mit mindestens einem
  Tag Montag bis Freitag, der nicht unterrichtsfrei ist (FR-7).
- Klassen folgen dem Plan ihres Jahrgangs; eine Abweichung einzelner Klassen ist eine Notiz, kein eigener
  Datensatz (Q-36).

### Consequences

- Nutzen: eine Planung für alle Parallelklassen; Rückblick und Übernahme über einen gleichbleibenden Schlüssel;
  Dubletten nach dem Abgleich fachlich auflösbar; Einträge überstehen Änderungen an Schuljahr und Ferien.
- Kosten (Pflicht):
  - Laufen Parallelklassen auseinander, sieht die zurückliegende Klasse in Vorbereiten das Thema der
    Kalenderwoche, nicht ihres tatsächlichen Stands; die Lehrkraft korrigiert von Hand (Notiz, Thema der Stunde).
  - Unterrichtet eine Lehrkraft in einem Jahrgang Klassen mit verschiedenen Plänen (z. B. Englisch in einer
    Regel- und einer bilingualen 8), passt ein Plan nicht für beide; das Modell kennt dafür keinen zweiten Plan
    gleichen Schlüssels.
  - Klassennamen ohne Ziffern brauchen eine Zuordnung von Hand, und das jedes Schuljahr neu.
  - Vier neue Datensatzarten im Abgleich beider Datenorte, im Zusammenführen und im Dateiformat des
    Datenordners (`RecordPayload`, `RecordCodec`), mit wachsender Menge über die Jahre (RISK-10).
  - Ein Plan ist nur über Fach und Jahrgang mit den Unterrichtsstunden verknüpft; schreibt sich ein Fach im
    Stundenplan anders als im Plan („E“ statt „Englisch“), findet Vorbereiten den Plan nicht.

### Revisit if

- Lehrkräfte melden, dass sie Parallelklassen regelmäßig getrennt planen oder dass die Notizen dafür nicht
  reichen (Q-36).
- Mehr als jede zehnte Lehrkraft unterrichtet im selben Fach und Jahrgang Klassen mit verschiedenen Plänen
  (Profil- oder bilinguale Klassen).
- Ein Stundenplan-Import liefert Jahrgänge direkt (dann statt Ableitung aus dem Namen übernehmen).

## Pros and Cons of the Options

### Fach + Jahrgang + Schuljahr

- Vorzug: eine Planung je Parallelklassen; Schlüssel über Jahre vergleichbar.
- Nachteil: Abweichungen einzelner Klassen nur als Notiz.

### Fach + Klasse + Schuljahr

- Vorzug (verworfen): feiner – jede Klasse hat ihren eigenen Stand, Vorbereiten schlägt immer das passende Thema vor.
- Nachteil: doppelte Arbeit für Parallelklassen; kein Vergleich über die Jahre, weil Klassennamen jedes Jahr
  wechseln (die 8b von 2026/27 ist 2027/28 die 9b).

### Fach + Jahrgang ohne Schuljahr

- Vorzug (verworfen): kein Schuljahr einzurichten, Übernahme entfällt.
- Nachteil: kein Rückblick auf frühere Jahre (FR-15.3) – genau das, was Andreas ausdrücklich will.

## More Information

- Area doc: docs/ARCHITECTURE.md#area-daten
- Anforderungen: docs/PRD.md FR-15 bis FR-15.6
