---
status: draft
date: 2026-11-13
---

# Tagesmappe — Architektur

**Beschreibt, entscheidet nicht.** Jede Festlegung ist eine ADR (`docs/adr/NNNN-titel.md`); dieses
Dokument sagt, wie gebaut wird, innerhalb dessen, was die ADRs festgelegt haben, und verweist mit
„gemäß ADR-NNNN“ darauf.

**Besitzt nicht:** was das Produkt kann (`docs/PRD.md`) und wie es aussieht (`DESIGN.md`).

---

## Area: plattform

- area-status: draft

App-Technik, Gerätearten, Bauweg und Verteilung.

## Area: daten

- area-status: draft

Stundenplan, Unterrichtsstunden und Zuordnungen: wo sie liegen, wie sie zwischen Mac und Tablet
abgeglichen werden, wovon die Identität einer Unterrichtsstunde abhängt.

## Area: ablage

- area-status: draft

Zugriff auf Material in der Ablage der Lehrkraft, Öffnen in der passenden App, Bereithalten für den
Unterricht, OneDrive-Zusatz mit AutoSpeichern.

## Area: stundenplan-quellen

- area-status: draft

Austauschbare Bausteine, die einen Stundenplan liefern: von Hand, Schulmanager Online, später WebUntis.

## Area: anzeige

- area-status: draft

Eigene Anzeige von PDFs und Bildern mit Stift (FR-6).

---

## Open Questions

- ~~Q-14~~: Wovon hängt die Identität einer Unterrichtsstunde ab, damit Zuordnungen eine Änderung des Stundenplans überstehen? → answered 2026-11-13: Datum + Klasse + Fach + laufende Nummer, Material folgt der Klasse (ADR-0005, accepted)
- ~~Q-15~~: Wie oft und wodurch ausgelöst wird der Schulmanager abgefragt, und wie spät dürfen Vertretungen dort ankommen? → answered 2026-11-13: einmal je Morgen und auf Knopfdruck; Vertretungen am selben Morgen (ADR-0004, accepted)

## Changes

- 2026-11-13: plattform, daten, ablage, stundenplan-quellen, anzeige new — Bereichsliste vor der ersten ADR
