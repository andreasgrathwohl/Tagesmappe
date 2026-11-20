---
status: accepted
date: 2026-11-20
reversibility: two-way
area: stundenplan-quellen
---

# ADR-0016 — Schulmanager-Anbindung abgeschaltet, Baustein bleibt im Code

- Amends: ADR-0004

## Context and Problem Statement

ADR-0004 hat Schulmanager Online als austauschbaren Importbaustein angebunden, über eine inoffizielle Schnittstelle
(RISK-1). Andreas am 2026-11-20: „die anbindung an den schulmanager müssen wir erstmal streichen. nicht löschen nur
nicht mehr verfügbar machen.“ Grund sind rechtliche bzw. Datenschutz-Bedenken: Ob eine inoffizielle Anbindung mit
den Zugangsdaten der Lehrkraft zulässig ist, ist ungeklärt – genau die zweite Hälfte von RISK-1 („bricht oder ist
unzulässig“). Zugangsdaten wurden bisher nicht weitergegeben; es gibt keine Nutzer, deren Konten betroffen wären.

## Decision Drivers

- Keine Funktion anbieten, deren Zulässigkeit offen ist
- Der Baustein ist gebaut und getestet; ein Wiedereinschalten soll ohne Neubau gehen
- Ungenutzte Zugangsdaten sollen nicht auf Geräten liegen bleiben
- Werbung und Hilfe dürfen nichts versprechen, was die App nicht anbietet

## Considered Options

- Abschalten über einen festen Schalter im Code; Baustein, Texte und Tests bleiben, Oberfläche und Abfrage entfallen
- Code löschen
- Ausschluss beim Übersetzen (`#if`)
- Schalter in den Einstellungen bzw. per Fernkonfiguration

## Decision Outcome

Chosen option: "Abschalten über einen festen Schalter im Code", because er die Funktion sofort aus Oberfläche, Hilfe
und Abfrage nimmt, den getesteten Baustein aber weiter übersetzt und prüft. Wieder einschalten heißt: den Schalter
umlegen und diese ADR ablösen.

Umsetzung: `TimetableSourceKind.isAvailable` ist für `.schulmanager` `false`. Daraus folgt:

- Einrichten zeigt den Eintrag „Stundenplan-Quelle“ nicht mehr, solange nur „von Hand“ angeboten wird.
- Das Hilfethema „Schulmanager“ fehlt in Gliederung, Suche und bei den verwandten Themen; die Hilfetexte der
  übrigen Themen nennen Schulmanager nicht mehr.
- Steht in einem Datenort noch Schulmanager als Quelle, gilt beim Start „von Hand“ (wie ein Wechsel von Hand: der
  übernommene Stundenplan bleibt, Abweichungen der Quelle ab heute fallen weg). Zugangsdaten für Schulmanager
  werden aus dem Schlüsselbund des Geräts gelöscht.
- Startseite und Datenschutzseite erwähnen Schulmanager nicht mehr.

### Consequences

- Nutzen: kein offenes Rechts- oder Datenschutzrisiko aus der Anbindung; der Stundenplan wird von Hand gepflegt
  (FR-1), Vertretungen und Ausfälle als Abweichungen von Hand.
- Kosten (Pflicht): Vertretungen erscheinen morgens nicht mehr von selbst (FR-2.2 entfällt im MVP); die Lehrkraft
  trägt den Stundenplan einmal von Hand ein. Der ruhende Baustein wird weiter übersetzt und getestet, ohne dass
  jemand ihn nutzt; ändert Schulmanager seine Seite, merkt das niemand, bis er wieder eingeschaltet wird.

### Revisit if

- Die Zulässigkeit ist geklärt, etwa durch eine Vereinbarung oder offizielle Schnittstelle des Anbieters.
- Eine datenschutzrechtliche Prüfung erlaubt die Anbindung mit den Zugangsdaten der Lehrkraft.

## Pros and Cons of the Options

### Fester Schalter im Code

- Vorzug: sofort wirksam, umkehrbar mit einer Zeile, der Baustein bleibt geprüft.
- Nachteil: toter Code im Build, Pflege ohne Nutzen.

### Code löschen

- Vorzug (verworfen): kein ruhender Code.
- Nachteil: Andreas will ausdrücklich nicht löschen; ein Wiedereinschalten wäre ein Neubau.

### Ausschluss beim Übersetzen (`#if`)

- Vorzug (verworfen): nichts davon im ausgelieferten Programm.
- Nachteil: Der ausgeschlossene Code wird nicht mehr übersetzt und verrottet unbemerkt.

### Schalter in den Einstellungen oder per Fernkonfiguration

- Vorzug (verworfen): Einschalten ohne neue App-Version.
- Nachteil: Die Funktion bliebe erreichbar, solange ihre Zulässigkeit offen ist; Fernkonfiguration bräuchte einen
  Server (NFR-2).

## More Information

- ADR-0004 gilt für den Baustein weiter, sobald er wieder eingeschaltet wird.
- PRD: FR-2, FR-2.2 und FR-13.1 auf `[Later]`, RISK-1 ergänzt.
