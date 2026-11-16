---
status: ready
ready-since: 2026-11-13
date: 2026-11-13
---

# Architekturentscheidungen

Ebenenkopf der ADRs; Stand der ADR-Ebene steht hier, die einzelnen ADRs liegen als Dateien in diesem Ordner.

Die ADR-Dateien daneben tragen MADR-Statuswerte (`proposed`, `accepted`, …), dieses README die Dokumentwerte (`draft | clarifying | ready | not-needed`).

Hier steht bewusst keine Liste der ADRs.

## Open Questions

- ~~Q-14~~: Identität der Unterrichtsstunde → answered 2026-11-13: ADR-0005 accepted
- ~~Q-15~~: Abfragehäufigkeit Schulmanager → answered 2026-11-13: ADR-0004 accepted

- ~~Q-17~~: Ort der Stiftnotizen → answered 2026-11-13: ADR-0006 accepted

Offen und für die ADR-Ebene relevant, aber anderswo geführt: Q-16 im PRD (liefern Lehrerkonten
Stundenplan und Vertretungen?); Q-18 in `docs/ARCHITECTURE.md` (AutoSpeichern über die Office-Adresse
auf iPadOS).

Freigegeben von Andreas am 2026-11-13: keine ADR mit `reversibility: one-way` ist `proposed`. Das gilt
auch nach ADR-0006 (am selben Tag von Andreas entschieden und `accepted`).

Ergänzt 2026-11-16: ADR-0014 (Rückmeldung per E-Mail über das System, ohne eigenen Server) ist
`two-way` und `accepted` (Entscheidung von Andreas delegiert); die Freigabe oben gilt unverändert. Offen und
anderswo geführt: Q-42 im PRD (Empfangsadresse und Datenschutz).
