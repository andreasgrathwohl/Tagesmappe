# Arbeitsweise

Entscheidungen werden nach ihren **Umkehrkosten** geschichtet und in dieser Reihenfolge getroffen:

1. **PRD** (`docs/PRD.md`) – was, für wen, warum; bindendes Glossar. Ohne Technik.
2. **ADRs** (`docs/adr/`) – je architekturrelevante Entscheidung eine Datei; schwer umkehrbare
   („one-way“) zuerst.
3. **Architecture Doc** (`docs/ARCHITECTURE.md`) – wie gebaut wird, je Bereich, mit Verweisen auf ADRs.
4. **UI Spec** (`DESIGN.md`) – Gestaltungsbeschlüsse; darf parallel entstehen.

Regeln, die hier gelten:

- **Nummern werden nie neu vergeben oder umnummeriert** (FR-n, NFR-n, RISK-n, Q-n, ADR-NNNN, UI-n).
  Neues wird angehängt, Zugehöriges wird Unter-Nummer (FR-3.1).
- **Offene Fragen** stehen als `Q-n` unter „Open Questions“; beantwortete werden durchgestrichen,
  nie gelöscht.
- **Rückfluss:** Eine gefallene Entscheidung wird sofort in alle Dokumente geschrieben, die sie
  berührt – auch in dieses Wiki.
- Erst wenn eine Ebene freigegeben ist (`status: ready`), wird in der nächsten entschieden.
