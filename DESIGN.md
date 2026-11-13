---
status: draft
date: 2026-11-13
---

# Tagesmappe — Gestaltung

**Besitzt:** wie sich das Produkt zeigt und verhält. Farbbedeutungen, Dichte, Zustände,
Interaktionsgrammatik, Wortlaut in der Oberfläche.

**Besitzt nicht:** was das Produkt kann. Steht hier eine Fähigkeit, gehört sie ins PRD.

**Status:** `/design:design-runde` ist der Träger der Beschlüsse. `ready` heißt hier „alle gewollten
Kategorien sind entschieden“ — kein Phasen-Tor, das den Bau aufhält.

## Wie ein Beschluss hier entsteht

Diese Ebene ist beim Anlegen **leer**, und das ist richtig so. Sie füllt sich dadurch, dass jemand
zwischen gerenderten Varianten wählt — an der echten Oberfläche, mit dem Ist-Zustand als Nullpunkt.
Runde 0 (Rahmen: welche Oberfläche ist Referenz) kann vorab laufen; die Runden 1–10 laufen erst, wenn
der erste lauffähige Bildschirm existiert.

- **Solange für eine Kategorie kein Beschluss existiert, wird sie nicht stillschweigend
  mitentschieden.** Eine Aufgabe, die daran stößt, wird nicht angehalten — aber die Lücke wird in einer
  Zeile benannt, statt sie durch eine Einzelentscheidung zu schließen.
- **Alle Kategorien sind offen.** Das ist der ehrliche Ausgangszustand.
- Skizzen im Wiki (`wiki/Ueberblick.md`) sind Veranschaulichung, kein Beschluss.

Rahmen aus den Architekturentscheidungen, der jede Gestaltung bindet (kein Beschluss dieser Ebene):
native Apple-App für iPad und Mac (ADR-0001) — Apples Gestaltungsrichtlinien sind der Bezugsrahmen;
Prüfungen dagegen laufen mit dem projektlokalen Skill `apple-design`.

**Änderungen** laufen per `## Changes`, nicht per Ablösung.

---

*(noch keine Beschlüsse — der erste wird `### UI-1 — <Beschluss als Aussage>`)*

---

## Wiederkehrende Fallen

- **Eine Farbe, die zwei Dinge bedeutet, bedeutet keines.**
- **Zustände nicht allein am Farbton unterscheiden.**
- **Was nur durch Bewegung erkennbar ist, ist in einem Standbild nicht vorhanden.**
- **Abwesenheit und Leere dürfen nie gleich aussehen.** Hier besonders: „keine Unterrichtsstunde“,
  „Unterrichtsstunde ohne Material“, „Material nicht verfügbar“ und „Ausfall“ sind vier Aussagen.
- **Jede angezeigte Zahl wird aus den Daten berechnet**, nie danebengepflegt.
- **Der leere Zustand ist eine Aussage, keine Abwesenheit.**

## Open Questions

- Q-19: Die Tagesansicht ist während des Unterrichts per Bildschirmspiegelung für die Klasse sichtbar. Was darf dort stehen, was nicht (z. B. Material anderer Klassen, Lösungen, Namen von Dateien wie „KA 1 9b“)?

## Changes

- 2026-11-13: DESIGN.md new — leer angelegt, alle Kategorien offen
