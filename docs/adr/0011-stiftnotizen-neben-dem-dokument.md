---
status: accepted
date: 2026-11-14
reversibility: one-way
area: anzeige
---

# ADR-0011 — Stiftnotizen liegen neben dem Dokument: Notiz-Datei und lesbares PDF

- Supersedes: ADR-0006

## Context and Problem Statement

ADR-0006 legte Stiftnotizen getrennt von der Datei in die App-Daten (gespiegelt über iCloud), damit
das Original unberührt bleibt und die App nie in die Ablage schreibt. Andreas am 2026-11-14:
„Notizen zu Dokumenten müssen neben dem eigentlichen Dokument liegen, sonst findet man es nie wieder.“
Mit ADR-0010 schreibt die App ohnehin in die Ablage (Datenordner). Die Umkehrkosten sind hoch: Wo
Notizen liegen, bestimmt Format, Dateinamen in den Ablagen der Lehrkräfte und das Verhalten beim
Verschieben von Material.

## Decision Drivers

- Notizen sollen auffindbar sein, auch außerhalb von Frontstage und an jedem Rechner
- das Original bleibt unverändert – dasselbe Arbeitsblatt wird in der nächsten Klasse sauber gezeigt
- Stiftnotizen gelten je Unterrichtsstunde (FR-6.1)
- zwei Geräte sollen sich beim Schreiben von Notizen möglichst nicht in die Quere kommen

## Considered Options

- Neben dem Dokument: eine Notiz-Datei für Frontstage **und** je Unterrichtsstunde ein lesbares PDF
- Neben dem Dokument: nur ein lesbares PDF je Unterrichtsstunde
- Neben dem Dokument: nur eine Notiz-Datei für Frontstage
- Getrennt in den App-Daten (ADR-0006)

## Decision Outcome

Chosen option: "Notiz-Datei und lesbares PDF neben dem Dokument", because die Notizen damit im Ordner
des Materials auffindbar und in jeder App lesbar sind, Frontstage sie aber verlustfrei weiter
bearbeiten kann. Andreas wählte „Beides“ am 2026-11-14.

Festgelegt (Beispiel Material `Arbeitsblatt Vokabeln.pdf`):

- **Notiz-Datei:** der Ordner `Arbeitsblatt Vokabeln.frontstage-notizen/` neben dem Dokument, darin je
  Unterrichtsstunde eine Datei `<Schlüssel der Unterrichtsstunde>.json` mit den Zeichnungsdaten je Seite
  und der Seitengröße beim Zeichnen. Je Stunde eine Datei, damit zwei Geräte nur dann dieselbe Datei
  schreiben, wenn sie dieselbe Stunde bearbeiten.
- **Lesbares PDF:** beim Schließen der Anzeige `Arbeitsblatt Vokabeln – Notizen 8b 2026-11-17.pdf`
  daneben – das Dokument mit den Strichen als PDF-Anmerkungen (bei Bildern: das Bild als PDF-Seite mit
  Anmerkungen). Es wird bei jedem Schließen neu geschrieben; maßgeblich ist die Notiz-Datei.
- Das Original wird nie verändert; das lesbare PDF ist eine abgeleitete Datei, keine Kopie im Sinn von
  FR-3.4 (Zuordnungen verweisen weiter nur auf das Original).
- „In die nächste Stunde schieben“ und Weiterreichen bei Ausfall benennen Notiz-Datei-Eintrag und PDF
  auf die neue Unterrichtsstunde um; „Für <Klasse> übernehmen“ legt nichts an (FR-6.1).
- Ist der Ordner des Dokuments nicht beschreibbar (z. B. ein nur lesend geteilter Ordner), liegen die
  Notizen der Stunde ersatzweise im Datenort (ADR-0012, damals ADR-0010) und die Anzeige sagt das.

### Consequences

- Nutzen: Notizen sind dort, wo das Material ist – im Dateimanager, in OneDrive im Browser, am
  Schul-PC; das lesbare PDF lässt sich weitergeben; das Original bleibt sauber.
- Kosten (Pflicht):
  - Die App schreibt neben Material in fremde Ordner der Ablage; das Verhalten der Anbieter beim
    Schreiben ist nur durch Ausprobieren belegt (wie ADR-0003, ADR-0010).
  - Zusätzliche Dateien im Ordner der Lehrkraft: je Dokument ein Notiz-Ordner, je Stunde ein PDF.
  - Verschiebt oder benennt die Lehrkraft das Dokument außerhalb von Frontstage, bleiben Notiz-Datei
    und PDF zurück; beim Neu verknüpfen sucht die App sie am alten Ort und bietet an, sie mitzunehmen.
  - Ändert sich das Dokument (Seite eingefügt), passen Striche nicht mehr – wie bisher wird das erkannt
    und angezeigt, nie stillschweigend verworfen.
  - Das lesbare PDF ist eine zweite Fassung des Dokuments; wer es statt des Originals bearbeitet,
    bearbeitet die falsche Datei.

### Revisit if

- Lehrkräfte empfinden die zusätzlichen Dateien im Ordner als Unordnung (dann PDF nur auf Wunsch).
- Ein Ablage-Anbieter lässt das Schreiben neben Dokumenten regelmäßig scheitern.

## Pros and Cons of the Options

### Notiz-Datei und lesbares PDF

- Vorzug: auffindbar, überall lesbar, in Frontstage verlustfrei bearbeitbar.
- Nachteil: zwei Arten zusätzlicher Dateien.

### Nur lesbares PDF

- Vorzug (verworfen): eine Datei je Stunde, überall lesbar.
- Nachteil: Frontstage müsste Striche aus PDF-Anmerkungen zurücklesen; Zeichnungsdetails (Stiftart,
  Druck) gehen dabei verloren.

### Nur Notiz-Datei

- Vorzug (verworfen): eine kompakte Datei, nichts Doppeltes.
- Nachteil: außerhalb von Frontstage nicht lesbar – genau das Wiederfinden, um das es geht, bliebe aus.

### Getrennt in den App-Daten (ADR-0006)

- Vorzug (verworfen): nichts im Ordner der Lehrkraft, kein Schreiben neben Material.
- Nachteil: Notizen sind nur in Frontstage zu finden.

## More Information

- Area doc: docs/ARCHITECTURE.md#area-anzeige
