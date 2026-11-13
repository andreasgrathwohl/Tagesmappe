---
status: draft
date: 2026-11-13
---

# Tagesmappe (Arbeitstitel) — Product Requirements

**Besitzt:** was gebaut wird, für wen, warum. Anforderungen, Lieferstufen, Risiken, offene Fragen,
Kennzahlen, Abnahmekriterien — und das Glossar, an das alle späteren Ebenen gebunden sind.

**Besitzt nicht:** wie etwas gebaut wird. Steht hier eine Technologie, gehört sie eine Ebene tiefer.

---

## Zweck in drei Sätzen

Lehrkräfte suchen ihr Unterrichtsmaterial vor und in jeder Stunde in tiefen Ordnerstrukturen
zusammen und verlieren damit Zeit und Ruhe vor der Klasse. Dieses Produkt lässt sie das Material
vorab den Stunden ihres festen Stundenplans zuordnen und zeigt im Unterricht nur den heutigen Tag:
eine Stunde antippen, das Material öffnet sich und wird über die vorhandene Klassenraum-Technik
gezeigt. Gelöst ist es, wenn eine Lehrkraft im Unterricht ihr Material ohne Suchen öffnet und es
dabei immer der aktuelle Stand aus ihrer eigenen Ablage ist.

## Nutzerschaft

Lehrkräfte, die mit einem Tablet unterrichten und ihr Material in einer Cloud-Ablage halten — mit
oder ohne Microsoft 365, mit oder ohne Mac. Ausgangsfall (Kontext, keine Anforderung): eine Realschul-Lehrkraft mit
Mac, iPad und OneDrive, die PowerPoint vom iPad per Apple TV auf ein Smartboard spiegelt und auf dem
iPad in der Präsentation schreibt und zeichnet.

| Gruppe | Braucht vor allem | Bindet an |
|---|---|---|
| Lehrkraft beim Vorbereiten | Material schnell den kommenden Stunden zuordnen | FR-1, FR-2, FR-3 |
| Lehrkraft im Unterricht | den heutigen Tag auf einen Blick, Material mit einem Tipp öffnen und zeigen | FR-4, FR-5, FR-6 |

Nicht Zielgruppe: Schülerinnen und Schüler, Eltern, Schulverwaltung.

Das Tablet ist persönlich: Es gehört einer Lehrkraft, und sie ist auf ihm immer die handelnde
Person (Q-13).

## Glossar — bindend

| Begriff | Bedeutung | Nicht zu verwechseln mit |
|---|---|---|
| Stundenplan | die wiederkehrende Wochenstruktur einer Lehrkraft: welche Klasse in welchem Fach an welchem Wochentag in welcher Stunde | Tagesansicht |
| Stundenplan-Eintrag | ein Feld im Stundenplan, z. B. „Dienstag, 2. Stunde, 8b, Englisch“ | Unterrichtsstunde |
| Unterrichtsstunde | ein konkreter Stundenplan-Eintrag an einem bestimmten Datum, z. B. „Di 17.11., 2. Stunde, 8b“ — Material wird Unterrichtsstunden zugeordnet | Stundenplan-Eintrag |
| Material | eine Datei aus der Ablage der Lehrkraft (z. B. Präsentation, Dokument, PDF, Bild), die einer Unterrichtsstunde zugeordnet ist | Ablage |
| Zuordnung | der Verweis einer Unterrichtsstunde auf ein Material in der Ablage — nie eine Kopie der Datei | Material |
| Ablage | der Cloud-Speicher, in dem die Lehrkraft ihr Material hält (z. B. iCloud Drive, OneDrive, Google Drive, Schul-Nextcloud) | Material |
| Vorbereiten | Material den Unterrichtsstunden kommender Tage zuordnen | Präsentieren |
| Tagesansicht | die Ansicht im Unterricht: alle Unterrichtsstunden eines Tages mit ihrem Material | Stundenplan |
| Präsentieren | Material über die Technik im Klassenraum zeigen (z. B. iPad per Apple TV auf Smartboard) | Öffnen |
| Wochenvariante | eine von zwei Fassungen des Stundenplans, die sich wöchentlich abwechseln (A-Woche / B-Woche) | Stundenplan-Quelle |
| unterrichtsfreier Tag | Ferientag oder Feiertag: an ihm gibt es keine Unterrichtsstunden | Ausfall |
| Ausfall | eine einzelne Unterrichtsstunde, die nicht stattfindet; der Stundenplan-Eintrag bleibt bestehen | unterrichtsfreier Tag |
| Vertretungsstunde | eine zusätzliche, einmalige Unterrichtsstunde, die nicht aus dem Stundenplan stammt (z. B. Vertretung in einer fremden Klasse) | Unterrichtsstunde aus dem Stundenplan |
| Stundenplan-Quelle | woher der Stundenplan kommt: von Hand angelegt oder aus einem Schulverwaltungssystem importiert | Ablage |

## Constraints

### CON-1 — Eigenständiges Produkt in eigenem Repository

Herkunft: Andreas, 2026-11-13 — als Produkt gedacht, nicht als Erweiterung von OneDrive Opener;
eigenes Repo.

### CON-2 — Funktioniert auch ohne Microsoft 365

Herkunft: Andreas, 2026-11-13 — die Zielgruppe ist breiter als Lehrkräfte mit Microsoft 365.

## Ablauf von Anfang bis Ende

1. Stundenplan einrichten (von Hand oder importieren)
2. Vorbereiten: Material den Unterrichtsstunden der Woche oder des nächsten Tages zuordnen
3. Im Unterricht: Tagesansicht öffnen, Unterrichtsstunde wählen
4. Material öffnen und präsentieren, darin schreiben und zeichnen
5. Änderungen am Material landen sofort in der Ablage

## Anforderungen

### FR-1 — Stundenplan von Hand anlegen [MVP]

Die Lehrkraft legt ihren festen Stundenplan selbst an: je Stundenplan-Eintrag Wochentag, Stunde,
Klasse und Fach.

### FR-1.1 — A/B-Wochen [MVP]

Der Stundenplan kann zwei Wochenvarianten haben, die sich wöchentlich abwechseln (Q-5).

### FR-2 — Stundenplan aus Schulmanager Online importieren [MVP]

Die Lehrkraft kann ihren Stundenplan alternativ aus Schulmanager Online übernehmen. Schulmanager
bietet keine offizielle Schnittstelle; die Anbindung ist inoffiziell (siehe RISK-1).

### FR-2.1 — Stundenplan aus WebUntis importieren [Later]

Als weitere Stundenplan-Quelle — vom Nutzer genannt („Untis könnte noch angebunden werden“).

### FR-3 — Material Unterrichtsstunden zuordnen [MVP]

Die Lehrkraft ordnet Material aus ihrer Ablage den Unterrichtsstunden der kommenden Tage zu — für
die Woche oder für morgen. Vom Nutzer genannt: „am Mac vorbereiten für die Woche oder morgen“.
Vorbereiten geht am Mac und am Tablet; ein Mac ist nicht Voraussetzung (Q-2).

### FR-3.1 — Mehrere Materialien in fester Reihenfolge [MVP]

Eine Unterrichtsstunde kann mehrere Materialien haben, in einer Reihenfolge, die die Lehrkraft
festlegt; die Tagesansicht zeigt sie in dieser Reihenfolge (Q-6).

### FR-3.2 — Zuordnung für Parallelklasse übernehmen [MVP]

„Für <Klasse> übernehmen“ kopiert die Zuordnung einer Unterrichtsstunde in die passende
Unterrichtsstunde einer anderen Klasse (Q-7).

### FR-3.3 — Material in die nächste Stunde der Klasse schieben [MVP]

Nicht behandeltes Material lässt sich mit einem Tipp in die nächste Unterrichtsstunde derselben
Klasse schieben (Q-7).

### FR-3.4 — Zuordnen kopiert nie Dateien [MVP]

Zuordnen, Übernehmen und Schieben verweisen auf die Datei in der Ablage; es entsteht nie eine Kopie
der Datei, damit es immer nur einen Stand des Materials gibt (Q-7, NFR-1).

### FR-4 — Tagesansicht mit Fokus auf den Tag [MVP]

Auf dem Tablet zeigt das Produkt die Unterrichtsstunden eines Tages mit ihrem Material, mit
einfacher Navigation.

### FR-5 — Material mit einem Tipp öffnen [MVP]

Aus der Tagesansicht öffnet ein Tipp das Material in der App, mit der die Lehrkraft es bearbeitet
und präsentiert (z. B. PowerPoint), sodass sie darin wie gewohnt schreiben und zeichnen kann.

### FR-5.1 — Bei Microsoft 365: öffnen mit AutoSpeichern [MVP]

Liegt das Material in OneDrive und hat die Lehrkraft Microsoft 365, öffnet es als Cloud-Dokument mit
AutoSpeichern, sodass Notizen und Zeichnungen sofort in der Ablage landen.

### FR-6 — PDFs und Bilder selbst zeigen, mit Stift [MVP]

PDFs und Bilder zeigt das Produkt selbst an; die Lehrkraft kann darauf mit dem Stift schreiben und
zeichnen. So können auch Lehrkräfte ohne PowerPoint präsentieren und notieren.

### FR-7 — Unterrichtsfreie Tage [MVP]

Die Lehrkraft trägt Ferien und Feiertage ein; an diesen Tagen gibt es keine Unterrichtsstunden.
Bereits zugeordnetes Material bleibt erhalten und lässt sich auf eine andere Unterrichtsstunde
verschieben (Q-5).

### FR-7.1 — Ferien und Feiertage aus einem Ferienkalender übernehmen [Later]

Statt von Hand: unterrichtsfreie Tage aus einem Ferienkalender übernehmen (Q-5).

### FR-8 — Ausfall markieren und Material weiterreichen [MVP]

Die Lehrkraft markiert eine Unterrichtsstunde als Ausfall. Ihr Material lässt sich mit einem Tipp in
die nächste Unterrichtsstunde derselben Klasse verschieben (Q-5).

### FR-9 — Vertretungsstunde anlegen [MVP]

Die Lehrkraft legt eine Vertretungsstunde frei an (Datum, Stunde, Klasse, Fach) und kann ihr Material
zuordnen wie jeder anderen Unterrichtsstunde (Q-5).

### NFR-1 — Material sofort und aktuell verfügbar [MVP]

Im Unterricht öffnet das Material ohne spürbares Warten und ist der aktuelle Stand aus der Ablage
— auch bei unzuverlässigem Schulnetz. Vom Nutzer: „sollen aber sofort und aktuell verfügbar sein“.

### NFR-2 — Keine Daten auf Servern des Produkts [MVP]

Stundenplan, Zuordnungen und Material liegen ausschließlich bei der Lehrkraft (Gerät, eigene Ablage,
eigenes Apple-Konto) — das Produkt betreibt keine eigenen Server für Nutzerdaten.

### NFR-3 — Unabhängig vom Ablage-Anbieter [MVP]

Das Produkt funktioniert mit jeder Ablage, die das Tablet einbindet, nicht nur mit OneDrive.

### NFR-4 — Zugangsdaten zu Schulsystemen nur auf dem Gerät [MVP]

Zugangsdaten für eine Stundenplan-Quelle (z. B. Schulmanager) werden nur im sicheren Speicher des
Geräts gehalten und nie an Dritte außer der Quelle selbst übertragen.

## Lieferstufen

- **MVP:** FR-1, FR-1.1, FR-2, FR-3, FR-3.1 bis FR-3.4, FR-4, FR-5, FR-5.1, FR-6, FR-7, FR-8, FR-9,
  NFR-1 bis NFR-4 (geprüfte Zahl: 19). Ob FR-2 und FR-5.1 wirklich in den MVP gehören, ist offen (Q-3, Q-4).
- **Later:** FR-2.1, FR-7.1.

## Out of Scope

- Ersatz für PowerPoint/Keynote beim Präsentieren — die Lehrkraft präsentiert und zeichnet darin weiter.
- Eigene Cloud-Ablage für Material — Material bleibt in der Ablage der Lehrkraft (NFR-2).
- Schüler-, Eltern- und Verwaltungsfunktionen.
- Geteilte Tablets mit mehreren Lehrkräften (An- und Abmelden je Person) — das Tablet ist persönlich (Q-13); spätere Aufnahme hieße Umbau der Datenhaltung, wird ADR.
- Android-Tablets und Windows, vorerst — teurer Ausschluss, wird ADR (siehe Q-11).

## Kennzahlen

- Q-12 (noch offen): Ohne eigene Server gibt es keine Nutzungsmessung; woran Erfolg gemessen wird, ist ungeklärt.

## Risiken

### RISK-1 — Inoffizielle Schulmanager-Anbindung bricht oder ist unzulässig

Schulmanager Online hat keine offizielle Schnittstelle; inoffizielle Bibliotheken warnen selbst vor
Risiken und vor häufigen Abfragen. Umgang: Import nur auf ausdrücklichen Wunsch der Lehrkraft und
selten (nicht dauernd), von Hand gepflegter Stundenplan bleibt immer möglich (FR-1), parallel den
Anbieter nach einer offiziellen Partnerschaft fragen.

### RISK-2 — Öffnen aus der Ablage ohne AutoSpeichern

Öffnet PowerPoint eine Datei, die über die Dateien-App eines Ablage-Anbieters kommt, möglicherweise
nicht als Cloud-Dokument, landen Notizen erst verzögert in der Ablage. Umgang: früh auf einem echten
iPad prüfen; für OneDrive greift FR-5.1.

### RISK-3 — Schulnetz unzuverlässig

Im Schulnetz brechen Verbindungen ab (beobachtet beim Ausgangsfall). Umgang: NFR-1; wie Material
vorab verfügbar gemacht wird, entscheidet eine tiefere Ebene.

### RISK-4 — Verteilung nur über Apple

Eine Tablet-App lässt sich dauerhaft nur über ein Apple-Entwicklerkonto (TestFlight/App Store)
verteilen. Umgang: Konto vor dem ersten Test mit Lehrkräften einrichten.

## Open Questions

- Q-1: Wie heißt das Produkt? „Tagesmappe“ ist Arbeitstitel.
- ~~Q-2~~: Wird nur am Mac vorbereitet, oder auch am Tablet? Hat jede Lehrkraft einen Mac? → answered 2026-11-13: beides — Vorbereiten geht am Mac und am Tablet; ein Mac ist nicht Voraussetzung (FR-3 angepasst).
- Q-3: Gehört der Schulmanager-Import (FR-2) in den MVP oder kommt er danach?
- Q-4: Gehört die OneDrive-Anbindung mit AutoSpeichern (FR-5.1) in den MVP?
- ~~Q-5~~: Wie werden A/B-Wochen, Ferien, Feiertage, Ausfall und Vertretungen behandelt? → answered 2026-11-13: Vorschlag angenommen — zwei Wochenvarianten im Wechsel (FR-1.1); unterrichtsfreie Tage von Hand, später aus Ferienkalender (FR-7, FR-7.1); Ausfall je Unterrichtsstunde mit Weiterreichen des Materials (FR-8); Vertretungsstunde frei anlegen (FR-9).
- ~~Q-6~~: Wie viel Material hat eine Unterrichtsstunde, und zählt die Reihenfolge? → answered 2026-11-13: mehrere, in festgelegter Reihenfolge (FR-3.1).
- ~~Q-7~~: Soll Material für Parallelklassen (z. B. 8a und 8b) oder für die Folgewoche einfach wiederverwendet werden können? → answered 2026-11-13: ja — Zuordnung für Parallelklasse übernehmen (FR-3.2), in die nächste Stunde schieben (FR-3.3), nie Dateien kopieren (FR-3.4).
- Q-8: Soll das Produkt Daten nach außen anbieten (z. B. Kalender-Abo, lesbare Plan-Datei), damit andere Apps sie nutzen?
- Q-9: Geschäftsmodell — kostenlos, Einmalkauf oder Abo? (bestimmt u. a. App-Store-Auftritt)
- Q-10: Zielmarkt — nur deutschsprachige Schulen, oder international?
- ~~Q-11~~: Gehören Android-Tablets und Windows dazu? → answered 2026-11-13: vorerst nein — Andreas stimmte einer nativen Apple-App für iPad und Mac zu, mit der Folge, dass Android-Tablets vorerst wegfallen (wird als ADR festgehalten).
- Q-12: Woran wird Erfolg gemessen, ohne eigene Server?
- ~~Q-13~~: Ist das Tablet persönlich, oder teilen sich Lehrkräfte Geräte? (Wer gilt dann als handelnde Person?) → answered 2026-11-13: persönlich — ein Tablet gehört einer Lehrkraft; handelnde Person ist immer die Besitzerin bzw. der Besitzer des Geräts. Keine Mehrbenutzer-Anmeldung auf einem Gerät.

## Abnahmekriterien

Folgen, sobald die MVP-Liste nach Q-3/Q-4 feststeht.

## Changes

- 2026-11-13: PRD new — Entwurf aus dem Gespräch vom 2026-11-13
- 2026-11-13: Nutzerschaft changed — Tablet ist persönlich (Q-13); Out of Scope um geteilte Tablets ergänzt
- 2026-11-13: FR-3 changed — Vorbereiten auch am Tablet, Mac nicht Voraussetzung (Q-2); Nutzerschaft entsprechend
- 2026-11-13: FR-1.1, FR-7, FR-7.1, FR-8, FR-9 new — Abweichungen vom Stundenplan (Q-5); Glossar um Wochenvariante, unterrichtsfreier Tag, Ausfall, Vertretungsstunde ergänzt
- 2026-11-13: FR-3.1 bis FR-3.4 new — Material je Stunde und Wiederverwenden (Q-6, Q-7); Glossar um Zuordnung ergänzt

## Anhang A — Abdeckung

| Phase | Anforderungen |
|---|---|
| 1 Stundenplan einrichten | FR-1, FR-1.1, FR-2, FR-2.1, FR-7, FR-7.1 |
| 2 Vorbereiten | FR-3, FR-3.1 bis FR-3.4, FR-8, FR-9 |
| 3 Tagesansicht | FR-4 |
| 4 Öffnen und präsentieren | FR-5, FR-5.1, FR-6 |
| 5 Änderungen in der Ablage | FR-5.1, NFR-1 |

Tabelle 2 (MVP-Anforderung → Abnahmekriterium) folgt mit den Abnahmekriterien.
