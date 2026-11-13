---
status: ready
ready-since: 2026-11-13
date: 2026-11-13
---

# Frontstage — Product Requirements

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
| Lehrkraft im Unterricht | den heutigen Tag auf einen Blick, Material mit einem Tipp öffnen und zeigen, an die Tafel schreiben | FR-4, FR-5, FR-6, FR-11, FR-12 |

Nicht Zielgruppe: Schülerinnen und Schüler, Eltern, Schulverwaltung.

Das Tablet ist persönlich: Es gehört einer Lehrkraft, und sie ist auf ihm immer die handelnde
Person (Q-13).

## Glossar — bindend

| Begriff | Bedeutung | Nicht zu verwechseln mit | Im Code |
|---|---|---|---|
| Stundenplan | die wiederkehrende Wochenstruktur einer Lehrkraft: welche Klasse in welchem Fach an welchem Wochentag in welcher Stunde | Tagesansicht | `Timetable` |
| Stundenplan-Eintrag | ein Feld im Stundenplan, z. B. „Dienstag, 2. Stunde, 8b, Englisch“ | Unterrichtsstunde | `TimetableEntry` |
| Unterrichtsstunde | ein konkreter Stundenplan-Eintrag an einem bestimmten Datum, z. B. „Di 17.11., 2. Stunde, 8b“ — Material wird Unterrichtsstunden zugeordnet | Stundenplan-Eintrag | `Lesson` |
| Material | eine Datei aus der Ablage der Lehrkraft (z. B. Präsentation, Dokument, PDF, Bild), die einer Unterrichtsstunde zugeordnet ist | Ablage | `Material` |
| Zuordnung | der Verweis einer Unterrichtsstunde auf ein Material in der Ablage — nie eine Kopie der Datei | Material | `MaterialLink` |
| Ablage | der Cloud-Speicher, in dem die Lehrkraft ihr Material hält (z. B. iCloud Drive, OneDrive, Google Drive, Schul-Nextcloud) | Material | `Storage` |
| Vorbereiten | Material den Unterrichtsstunden kommender Tage zuordnen | Präsentieren | `Preparation` |
| Tagesansicht | die Ansicht im Unterricht: alle Unterrichtsstunden eines Tages mit ihrem Material | Stundenplan | `DayView` |
| Präsentieren | Material über die Technik im Klassenraum zeigen (z. B. iPad per Apple TV auf Smartboard) | Öffnen | `present` |
| Zeitraster | Beginn und Ende jeder Stunde des Schultags (z. B. 2. Stunde 8:35–9:20); gilt für den ganzen Stundenplan | Stundenplan | `BellSchedule` |
| Wochenvariante | eine von zwei Fassungen des Stundenplans, die sich wöchentlich abwechseln (A-Woche / B-Woche) | Stundenplan-Quelle | `WeekVariant` |
| unterrichtsfreier Tag | Ferientag oder Feiertag: an ihm gibt es keine Unterrichtsstunden | Ausfall | `NonTeachingDay` (Zeitraum: `NonTeachingPeriod`) |
| Ausfall | eine einzelne Unterrichtsstunde, die nicht stattfindet; der Stundenplan-Eintrag bleibt bestehen | unterrichtsfreier Tag | `Cancellation` |
| Vertretungsstunde | eine zusätzliche, einmalige Unterrichtsstunde, die nicht aus dem Stundenplan stammt (z. B. Vertretung in einer fremden Klasse) | Unterrichtsstunde aus dem Stundenplan | `SubstituteLesson` |
| Stundenplan-Quelle | woher der Stundenplan kommt: von Hand angelegt oder aus einem Schulverwaltungssystem importiert | Ablage | `TimetableSource` |
| Zweitbildschirm | der Bildschirm im Klassenraum (z. B. Smartboard über Apple TV), wenn er vom Produkt einen eigenen Inhalt erhält statt des Tablet-Bilds | Bildschirmspiegelung (zeigt dasselbe wie das Tablet) | `SecondScreen` |
| Klassenbildschirm | was der Zweitbildschirm zeigt, solange weder Material noch Tafel gezeigt wird: ein für die Klasse bestimmter Bildschirm zur laufenden Unterrichtsstunde | Tagesansicht (nur für die Lehrkraft) | `ClassScreen` |
| Tafel | eine leere Seite im Produkt, auf die die Lehrkraft mit dem Stift schreibt und die der Zweitbildschirm zeigt | Material (eine Datei aus der Ablage) | `Board` |
| Tafelbild | was in einer Unterrichtsstunde auf die Tafel geschrieben wurde, alle Seiten zusammen; gehört zur Unterrichtsstunde und bleibt erhalten | Stiftnotiz (liegt auf einem Material) | `BoardDrawing` |
| Stiftnotiz | was die Lehrkraft in der Anzeige des Produkts mit dem Stift auf ein PDF oder Bild schreibt oder zeichnet; gehört zu einer Zuordnung, nicht zur Datei | Zeichnungen in einer Präsentation (die gehören zur Datei und landen in der Ablage) | `PenNote` |
| Stand | Zeitpunkt, zu dem der Stundenplan zuletzt aus der Stundenplan-Quelle geholt wurde; die Tagesansicht zeigt ihn | Datum einer Unterrichtsstunde | `sourceFetchedAt` |
| Arbeitsform | wie die Klasse gerade arbeitet: Einzelarbeit, Partnerarbeit oder Gruppenarbeit | Fach | `WorkMode` (`individual`, `pairs`, `groups`) |
| Vorlage | Seite oder Ausschnitt aus Material oder Ablage als Hintergrund einer Tafelseite | Material (bleibt unverändert in der Ablage) | `BoardTemplate` |
| Standbild | eingefrorenes Bild der Tablet-Kamera als Hintergrund einer Tafelseite | Material | `CameraStill` |
| Bereithalten | Material der kommenden Unterrichtsstunden vorab auf das Gerät laden | Kopieren (es entsteht keine zweite Datei) | `prefetch` |
| Neu verknüpfen | einen Verweis, der nicht mehr auflöst, auf die Datei in der Ablage zurückführen | Zuordnen | `relink` |

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

### FR-1.2 — Zeitraster der Stunden [MVP]

Die Lehrkraft legt einmal fest, wann jede Stunde beginnt und endet (z. B. 1. Stunde 7:45–8:30). Liefert
die Stundenplan-Quelle Zeiten, werden sie übernommen. Abgeleitet am 2026-11-13 aus FR-11 und FR-11.7,
die Stundenende, „Gleich:“ und die letzten fünf Minuten zeigen und dafür Uhrzeiten brauchen; vom Nutzer
noch nicht ausdrücklich bestätigt.

### FR-2 — Stundenplan aus Schulmanager Online importieren [MVP]

Die Lehrkraft kann ihren Stundenplan alternativ aus Schulmanager Online übernehmen. Schulmanager
bietet keine offizielle Schnittstelle; die Anbindung ist inoffiziell (siehe RISK-1).

### FR-2.1 — Stundenplan aus WebUntis importieren [Later]

Als weitere Stundenplan-Quelle — vom Nutzer genannt („Untis könnte noch angebunden werden“).

### FR-2.2 — Vertretungen aus Schulmanager morgens sichtbar [MVP]

Nutzt die Lehrkraft den Schulmanager-Import, zeigt die Tagesansicht Vertretungen und Änderungen des
Tages bereits am Morgen desselben Tages. Vom Nutzer: „müssen morgens da sein“ (Q-15).

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

Geändert 2026-11-13: Die Lehrkraft wählt die Zielstunde selbst aus einer Liste der kommenden
Unterrichtsstunden der gewählten Klasse (bis vier Wochen voraus, ohne Ausfälle); es gibt keine
automatische Zielwahl. Verworfen: automatisch die erste Stunde der Zielklasse im selben Fach – ein Tipp
weniger, aber die Gefahr, die falsche Stunde zu treffen.

### FR-3.3 — Material in die nächste Stunde der Klasse schieben [MVP]

Nicht behandeltes Material lässt sich mit einem Tipp in die nächste Unterrichtsstunde derselben
Klasse schieben (Q-7).

Präzisiert 2026-11-13: „Nächste Unterrichtsstunde“ heißt gleiche Klasse und gleiches Fach, Ausfälle
übersprungen – Englisch-Material der 8b wandert nicht in deren Mathestunde. Gilt ebenso für FR-8.

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

### FR-6.1 — Stiftnotizen gelten je Unterrichtsstunde [MVP]

Eine Stiftnotiz gehört zur Zuordnung, nicht zur Datei: Wird dasselbe Material in einer anderen
Unterrichtsstunde gezeigt, beginnt es dort ohne Notizen. „In die nächste Stunde schieben“ (FR-3.3) und
das Weiterreichen bei Ausfall (FR-8) nehmen die Stiftnotizen mit; „Für <Klasse> übernehmen“ (FR-3.2)
nicht. Die Datei in der Ablage bleibt unverändert (Q-17, Q-20).

### FR-6.2 — Zweitbildschirm zeigt nur das Material [MVP]

Ist das Tablet mit dem Bildschirm im Klassenraum verbunden (z. B. per AirPlay mit einem Apple TV) und
das Produkt im Vordergrund, erhält dieser als Zweitbildschirm einen eigenen Inhalt: das in der Anzeige
des Produkts geöffnete PDF oder Bild samt Stiftnotizen, im Vollbild. Die Tagesansicht und alle
Bedienelemente bleiben auf dem Tablet und erscheinen nie auf dem Zweitbildschirm. Ohne verbundenen
Bildschirm ist das Produkt uneingeschränkt nutzbar. Vom Nutzer: „wichtig ist, dass die AirPlay-Funktion
funktioniert“, „die App zeigt was anderes wie das Smartboard“. Für Material, das in einer anderen App
öffnet (FR-5, z. B. PowerPoint), bestimmt diese App, was der Bildschirm zeigt (RISK-5).

Ergänzt 2026-11-13: Neben dem Material kann der Zweitbildschirm die Tafel (FR-12) zeigen; ist beides
nicht offen, zeigt er den Klassenbildschirm (FR-11).

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

### FR-10 — Unterrichtsstunden als Kalender-Abo [Later]

Die Lehrkraft kann ihre Unterrichtsstunden samt Material über einen Kalender-Link in einer
Kalender-App (z. B. iPhone, Outlook) sehen (Q-8). Die erste Version bietet keine Daten nach außen an.

### FR-11 — Klassenbildschirm als Ruhezustand des Zweitbildschirms [MVP]

Zeigt der Zweitbildschirm weder Material noch die Tafel, zeigt er immer den Klassenbildschirm: Klasse
und Fach der laufenden Unterrichtsstunde, die Uhrzeit und das Ende der Stunde. Er zeigt nichts, was
nicht für diese Klasse bestimmt ist – keine anderen Klassen, keine Dateinamen. Vom Nutzer: „wenn nichts
auf dem Smartboard angezeigt wird, zeigt unsere App immer einen für die Klasse bestimmten
Default-Screen“ (Q-21).

### FR-11.1 — Thema und Hinweis der Stunde [MVP]

Die Lehrkraft kann je Unterrichtsstunde ein Thema und einen Hinweis (z. B. „Bitte bereitlegen: Buch,
Heft“ oder die Hausaufgabe) eintragen – beim Vorbereiten oder im Unterricht. Der Klassenbildschirm
zeigt beides; leere Felder zeigt er nicht.

Geändert 2026-11-13 (Q-25): Der Hinweis besteht aus zwei Feldern, „Bereitlegen“ und „Hausaufgabe“;
wann der Klassenbildschirm welches zeigt, regelt FR-11.7.

### FR-11.2 — Timer für Arbeitsphasen [MVP]

Die Lehrkraft stellt am Tablet eine Dauer ein und startet, hält an oder beendet den Timer; der
Klassenbildschirm zeigt die Restzeit groß.

Ergänzt 2026-11-13 (Q-26): Der Timer läuft sichtbar weiter, auch während der Zweitbildschirm Material
oder die Tafel zeigt, und gibt am Ende ein sichtbares und hörbares Signal.

### FR-11.3 — Arbeitsform anzeigen [MVP]

Die Lehrkraft wählt am Tablet die Arbeitsform – Einzelarbeit, Partnerarbeit oder Gruppenarbeit –, und
der Klassenbildschirm zeigt sie als Symbol mit Wort. Ohne Auswahl zeigt er keine.

### FR-11.4 — Zweitbildschirm dunkel schalten [MVP]

Die Lehrkraft kann den Zweitbildschirm mit einem Tipp dunkel schalten und wieder zurück; dunkel zeigt
er nichts.

### FR-11.5 — Am Tablet sehen und umschalten, was die Klasse sieht [MVP]

Das Tablet zeigt jederzeit ein Vorschaubild dessen, was der Zweitbildschirm gerade zeigt, und lässt
zwischen Klassenbildschirm, Material, Tafel und Dunkel umschalten. Der Bildschirm im Klassenraum nimmt
selbst keine Eingaben entgegen; bedient wird nur am Tablet.

### FR-11.6 — Verbindung erkennen und zum Verbinden hinführen [MVP]

Das Produkt erkennt sofort, wenn ein Bildschirm verbunden oder getrennt wird – per AirPlay oder per
Kabel –, und zeigt den Stand am Tablet an. Mit dem Verbinden erscheint der Klassenbildschirm ohne
weiteren Handgriff. Ist kein Bildschirm verbunden, führt „So verbinden“ in wenigen Schritten zur
Bildschirmsynchronisierung des Systems und nennt die Kabelverbindung als Weg, der ohne Handgriff und
ohne Schulnetz steht. Das Produkt startet die Verbindung nicht selbst – das lässt das System nicht zu
(Q-28).

### FR-11.7 — Klassenbildschirm folgt dem Verlauf der Stunde [MVP]

Der Klassenbildschirm zeigt je nach Zeitpunkt Verschiedenes. Vor Beginn einer Unterrichtsstunde:
„Gleich:“ mit Klasse und Fach der nächsten Unterrichtsstunde des Tages und dem, was bereitzulegen ist
– ohne Countdown bis zum Beginn. Während der Stunde: wie FR-11, mit Thema und „Bereitlegen“. In den
letzten fünf Minuten: die Hausaufgabe groß. Kommt an diesem Tag keine Unterrichtsstunde mehr: nur
Uhrzeit und Datum. Ein Ausfall zählt dabei nicht als Unterrichtsstunde (Q-25).

### FR-12 — Tafel [MVP]

Aus der Tagesansicht öffnet ein Tipp die Tafel: eine leere Seite, auf die die Lehrkraft mit dem Stift
schreibt und zeichnet, mit Radierer und einigen Farben. Der Zweitbildschirm zeigt die Tafel ohne
Bedienelemente. Vom Nutzer: „dass man in der App was auf die Tafel schreiben kann ohne großen Aufwand“.
Die Tafel funktioniert auch ohne verbundenen Bildschirm.

### FR-12.1 — Seiten und Hintergründe [MVP]

Die Tafel hat mehrere Seiten, zwischen denen die Lehrkraft blättert und die sie hinzufügt. Jede Seite
hat einen Hintergrund: leer, liniert oder kariert.

### FR-12.2 — Das Tafelbild gehört zur Unterrichtsstunde und bleibt [MVP]

Was auf die Tafel geschrieben wird, gehört als Tafelbild zur Unterrichtsstunde, in der es entstand,
und bleibt nach der Stunde erhalten, bis die Lehrkraft es löscht (Q-23).

### FR-12.3 — Letztes Tafelbild der Klasse aufrufen [MVP]

In einer Unterrichtsstunde lässt sich das Tafelbild der vorigen Unterrichtsstunde derselben Klasse im
selben Fach aufrufen und zeigen.

### FR-12.4 — Tafelbild als PDF sichern [MVP]

Die Lehrkraft kann ein Tafelbild als PDF sichern oder weitergeben; wohin, wählt sie dabei selbst. Das
Tafelbild im Produkt bleibt davon unberührt.

### FR-12.5 — Kamera des Tablets als Dokumentenkamera [MVP]

Die Tafel kann das Livebild der Tablet-Kamera zeigen – ein Heft, eine Buchseite, einen Versuch –, auch
auf dem Zweitbildschirm. „Standbild“ friert das Bild als Hintergrund einer neuen Tafelseite ein, auf
die die Lehrkraft schreiben kann (Q-24).

### FR-12.6 — Tafelhintergrund aus der Ablage oder dem Material [MVP]

Als Hintergrund einer neuen Tafelseite lässt sich eine Seite aus dem Material der Unterrichtsstunde
oder eine Datei aus der Ablage wählen – ganz oder als vergrößerter Ausschnitt. Die Datei in der Ablage
bleibt unverändert (Q-24).

### FR-12.7 — Abdecken und Aufdecken [MVP]

Die Lehrkraft kann einen Teil der Tafelseite für die Klasse verdecken und schrittweise freigeben. Am
Tablet sieht sie das Verdeckte weiterhin (Q-24).

### FR-13 — Kern kostenlos, Smartboard und Tafel per Einmalkauf [MVP]

Das Produkt ist kostenlos zu laden. Kostenlos und unbefristet nutzbar ist der Kern: Stundenplan (FR-1,
FR-1.1, FR-2, FR-2.2, FR-7 bis FR-9), Vorbereiten (FR-3 bis FR-3.4), Tagesansicht (FR-4), Öffnen und
Anzeigen von Material (FR-5, FR-5.1, FR-6, FR-6.1) sowie der Zweitbildschirm mit Material (FR-6.2) und
das Erkennen der Verbindung (FR-11.6). Ein einmaliger Kauf schaltet auf allen Geräten derselben
Apple-ID dauerhaft frei: Klassenbildschirm mit seinen Unterpunkten (FR-11, FR-11.1 bis FR-11.5,
FR-11.7) und Tafel mit ihren Unterpunkten (FR-12 bis FR-12.7). Es gibt kein Abo. Vom Nutzer:
Vorschlag am 2026-11-13 angenommen (Q-9).

Geändert 2026-11-13: Kostenlos sind zusätzlich das Eintragen und Anzeigen von Thema, Bereitlegen und
Hausaufgabe in Tagesansicht und Vorbereiten (FR-11.1) sowie „Dunkel“ (FR-11.4). Zum Kauf gehören die
Anzeige des Klassenbildschirms auf dem Zweitbildschirm (FR-11, FR-11.7, samt Thema und Hinweisen dort),
Timer (FR-11.2), Arbeitsform (FR-11.3) und die Tafel (FR-12 bis FR-12.7). Ohne Kauf zeigt der
Zweitbildschirm im Ruhezustand eine neutrale Fläche.

### FR-13.1 — Schulmanager-Import ohne Bezahlung und ohne Gewähr [MVP]

Der Import aus Schulmanager Online (FR-2, FR-2.2) gehört immer zum kostenlosen Teil und wird in der
App als inoffizielle Anbindung ohne Gewähr bezeichnet, solange es keine Vereinbarung mit dem Anbieter
gibt (RISK-1).

### FR-13.2 — Schulversion für den Sammelkauf [Later]

Für Schulen, die für ihr Kollegium kaufen, eine eigene, bezahlte Fassung mit allen Funktionen ohne
In-App-Kauf, die über Apple School Manager verteilt werden kann (RISK-7). Erst, wenn Schulen danach
fragen.

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

- **MVP:** FR-1, FR-1.1, FR-2, FR-2.2, FR-3, FR-3.1 bis FR-3.4, FR-4, FR-5, FR-5.1, FR-6, FR-6.1, FR-6.2, FR-7, FR-8,
  FR-9, FR-11, FR-11.1 bis FR-11.7, FR-12, FR-12.1 bis FR-12.7, FR-13, FR-13.1, NFR-1 bis NFR-4, FR-1.2 (geprüfte Zahl: 41). FR-2 und FR-5.1 bestätigt (Q-3, Q-4).
- **Later:** FR-2.1, FR-7.1, FR-10, FR-13.2.

## Out of Scope

- Ersatz für PowerPoint/Keynote beim Präsentieren — die Lehrkraft präsentiert und zeichnet darin weiter.
- Die Tafel als Notiz-App: Textfelder, Formen und frei eingefügte Bilder gibt es nicht — die Tafel bleibt Stift auf Seite, ergänzt um Kamera, Vorlage und Abdecken (Q-24).
- Eigene Cloud-Ablage für Material — Material bleibt in der Ablage der Lehrkraft (NFR-2).
- Schüler-, Eltern- und Verwaltungsfunktionen.
- Geteilte Tablets mit mehreren Lehrkräften (An- und Abmelden je Person) — das Tablet ist persönlich (Q-13); siehe ADR-0002.
- Android-Tablets und Windows, vorerst — siehe ADR-0001.

## Kennzahlen

- Q-12 (noch offen): Ohne eigene Server gibt es keine Nutzungsmessung; woran Erfolg gemessen wird, ist ungeklärt.

## Risiken

### RISK-1 — Inoffizielle Schulmanager-Anbindung bricht oder ist unzulässig

Schulmanager Online hat keine offizielle Schnittstelle; inoffizielle Bibliotheken warnen selbst vor
Risiken und vor häufigen Abfragen. Umgang: Import nur auf ausdrücklichen Wunsch der Lehrkraft und
selten — einmal je Morgen und auf Knopfdruck, nicht dauernd (ADR-0004) —, von Hand gepflegter
Stundenplan bleibt immer möglich (FR-1), parallel den Anbieter nach einer offiziellen Partnerschaft
fragen. Ob die inoffizielle Schnittstelle für Lehrerkonten Stundenplan und Vertretungen liefert, ist
ungeprüft (Q-16). Ergänzt 2026-11-13: Für den Import wird kein Geld verlangt (FR-13.1), damit ein
Ausfall keine bezahlte Funktion trifft.

### RISK-7 — Schulen können den Einmalkauf nicht sammelweise kaufen

In-App-Käufe lassen sich laut Apple nicht über den Sammelkauf in Apple School Manager erwerben und
verteilen. Kauft eine Schule für ihr Kollegium, erreicht sie die Freischaltung aus FR-13 so nicht.
Umgang: Zielgruppe sind zunächst Lehrkräfte mit eigenem Tablet (Q-13), die selbst kaufen; fragen
Schulen, folgt die Schulversion (FR-13.2).

### RISK-8 — Der Name „Pult“ ist als Software-Marke bereits in Gebrauch

Die Pult GmbH vertreibt unter „PULT“ Software für Arbeitsplatz- und Besuchermanagement, mit Apps im App
Store (u. a. „PULT Visitors Kiosk“, iPad) und rund 180 Bewertungen auf einem Vergleichsportal (Stand
2026-11-13). Software gehört zu derselben Markenklasse (9, ggf. 42) wie dieses Produkt; ob die Pult GmbH
eine eingetragene Marke hält, ist nicht geprüft – die Register DPMA und EUIPO ließen sich nicht
automatisch abfragen. Folge bei einer Kollision: Umbenennen nach dem Start, mit Verlust von
App-Store-Auftritt und Bekanntheit. Umgang: vor jedem öffentlichen Auftritt (TestFlight-Einladungen
außerhalb des eigenen Kreises, App-Store-Eintrag) Register prüfen; bis dahin bleibt „Pult“
Arbeitsname (Q-29).

Ergänzt 2026-11-13: Umgang gewählt – der Name ist gewechselt auf „Frontstage“ (Q-1). Für den neuen
Namen gilt dasselbe Risiko in anderer Form: „Frontstage“ ist ein allgemeines englisches Wort, das
Firmen außerhalb der Schule nutzen; eine Lehrer-App dieses Namens fand die Websuche nicht. Ob es als
Marke in Klasse 9 oder 42 eingetragen ist, ist ungeprüft (Q-31).

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

### RISK-5 — Präsentieren in fremden Apps liegt außerhalb des Produkts

Öffnet Material in einer anderen App (PowerPoint, Word), bestimmt allein diese, was der Bildschirm im
Klassenraum zeigt – das Produkt ist dann im Hintergrund. Ob PowerPoint auf dem Tablet über AirPlay
Folie und Referentenansicht trennt und Zeichnungen dabei auf dem Bildschirm erscheinen, ist ungeprüft
(Q-22). Beim Wechsel zwischen dem Produkt und der anderen App kann der Bildschirm kurz das Tablet-Bild
zeigen. Umgang: früh mit echtem Tablet und Apple TV prüfen; FR-6.2 sagt nur zu, was das Produkt selbst
anzeigt.

### RISK-6 — Die erste Version wächst über den Kern hinaus

Mit Klassenbildschirm und Tafel (FR-11, FR-12 samt Unterpunkten) kamen am 2026-11-13 elf Anforderungen
in den MVP, auf ausdrücklichen Wunsch („später gleich mit aufnehmen“). Der Kern – Material ohne Suchen
öffnen – wird dadurch später fertig, und die Tafel kann zur Notiz-App auswachsen, die das Produkt nicht
sein will (Q-24). Umgang: Der Umsetzungsplan baut den Kern zuerst (Stundenplan, Zuordnen, Tagesansicht,
Öffnen) und Klassenbildschirm und Tafel danach, sodass ein Test mit Lehrkräften nicht auf sie warten
muss.

## Open Questions

- ~~Q-1~~: Wie heißt das Produkt? „Tagesmappe“ ist Arbeitstitel. → answered 2026-11-13: „Pult“ – das Lehrerpult, an dem alles für die Stunde bereitliegt und von dem aus gesteuert wird, was die Klasse sieht. „Tagesmappe“ bleibt Name des Repositorys. Markenrecherche (DPMA, App Store) steht aus (Q-29). → changed 2026-11-13: „Frontstage“ – was vorne vor der Klasse passiert. „Pult“ verworfen, weil „PULT“ als Software-Marke in Gebrauch ist (RISK-8); dazwischen geprüft und verworfen: Stundenlicht, Klassenlicht, Katheder, Doppelstunde, Stundenbühne, Stundenregie, Klassenregie, Klassenblick, Tafelrand, Taktgeber, Lessonstage, Lectern, Teachdeck (Classcue und Classcast vergeben).
- ~~Q-2~~: Wird nur am Mac vorbereitet, oder auch am Tablet? Hat jede Lehrkraft einen Mac? → answered 2026-11-13: beides — Vorbereiten geht am Mac und am Tablet; ein Mac ist nicht Voraussetzung (FR-3 angepasst).
- ~~Q-3~~: Gehört der Schulmanager-Import (FR-2) in den MVP oder kommt er danach? → answered 2026-11-13: in den MVP („alles gleich hinein“), trotz RISK-1.
- ~~Q-4~~: Gehört die OneDrive-Anbindung mit AutoSpeichern (FR-5.1) in den MVP? → answered 2026-11-13: ja, MVP.
- ~~Q-5~~: Wie werden A/B-Wochen, Ferien, Feiertage, Ausfall und Vertretungen behandelt? → answered 2026-11-13: Vorschlag angenommen — zwei Wochenvarianten im Wechsel (FR-1.1); unterrichtsfreie Tage von Hand, später aus Ferienkalender (FR-7, FR-7.1); Ausfall je Unterrichtsstunde mit Weiterreichen des Materials (FR-8); Vertretungsstunde frei anlegen (FR-9).
- ~~Q-6~~: Wie viel Material hat eine Unterrichtsstunde, und zählt die Reihenfolge? → answered 2026-11-13: mehrere, in festgelegter Reihenfolge (FR-3.1).
- ~~Q-7~~: Soll Material für Parallelklassen (z. B. 8a und 8b) oder für die Folgewoche einfach wiederverwendet werden können? → answered 2026-11-13: ja — Zuordnung für Parallelklasse übernehmen (FR-3.2), in die nächste Stunde schieben (FR-3.3), nie Dateien kopieren (FR-3.4).
- ~~Q-8~~: Soll das Produkt Daten nach außen anbieten (z. B. Kalender-Abo, lesbare Plan-Datei), damit andere Apps sie nutzen? → answered 2026-11-13: später als Kalender-Abo (FR-10, Later); in der ersten Version nichts nach außen.
- ~~Q-9~~: Geschäftsmodell — kostenlos, Einmalkauf oder Abo? (bestimmt u. a. App-Store-Auftritt) → answered 2026-11-13: Kern kostenlos, Klassenbildschirm und Tafel per Einmalkauf, kein Abo; Schulmanager-Import immer kostenlos; Schulversion später (FR-13 bis FR-13.2). Verworfen: Abo (keine laufenden Kosten zu decken, Lehrkräfte zahlen privat), Testzeit mit Kauf für alles (keine dauerhafte Gratisfassung, die sich im Kollegium herumspricht). Andreas antwortete „Modelle finde ich gut“; die Wahl zwischen den beiden Einmalkauf-Varianten ist damit als Zustimmung zur empfohlenen gelesen.
- ~~Q-29~~: Ist „Pult“ als Name frei – Markenregister (DPMA, EUIPO) in Klasse 9 (Software) und App-Store-Suche? Bis zur Prüfung ist der Name nur intern festgelegt. Stand 2026-11-13 nach Websuche: App Store und Web zeigen eine etablierte Software-Marke „PULT“ der Pult GmbH (Arbeitsplatz- und Besuchermanagement, eigene iPad-App) sowie zwei weitere Apps mit „Pult“ im Namen (TV-Fernbedienung, Mac-Fernsteuerung); siehe RISK-8. Nicht geprüft: die Register selbst – DPMAregister und EUIPO eSearch lassen sich nur von Hand abfragen (Suchbegriff „PULT“, Klassen 9 und 42, auch ähnliche Schreibweisen). Offen bleibt: Registerprüfung von Hand, und ob ein unterscheidungskräftiger Zusatz („Pult für den Unterricht“) oder ein anderer Name nötig ist. → answered 2026-11-13: nicht verwendet – Name gewechselt auf „Frontstage“ (Q-1); Prüfung für den neuen Namen: Q-31.
- Q-31: Ist „Frontstage“ als Marke frei – DPMAregister, EUIPO eSearch und WIPO Global Brand Database, Klassen 9 und 42, auch ähnliche Schreibweisen („Front Stage“, „FrontStage“)? Websuche 2026-11-13: keine Lehrer-App dieses Namens, aber allgemeines Wort, das Firmen außerhalb der Schule nutzen. Bis zur Registerprüfung ist der Name nur intern festgelegt.
- ~~Q-30~~: Was kostet der Einmalkauf? Vorschlag: 14,99–19,99 €; zum Vergleich ein Lehrer-Planer im App Store für 9,99 € einmalig. → answered 2026-11-13: Spanne 14,99–19,99 € bestätigt; der genaue Preis wird beim Anlegen des App-Store-Eintrags gewählt.
- Q-10: Zielmarkt — nur deutschsprachige Schulen, oder international?
- ~~Q-11~~: Gehören Android-Tablets und Windows dazu? → answered 2026-11-13: vorerst nein — Andreas stimmte einer nativen Apple-App für iPad und Mac zu, mit der Folge, dass Android-Tablets vorerst wegfallen (wird als ADR festgehalten).
- Q-12: Woran wird Erfolg gemessen, ohne eigene Server?
- Q-16: Liefert die inoffizielle Schulmanager-Schnittstelle für Lehrerkonten den Stundenplan und die Vertretungen? (Bisher nur für Eltern-/Schülerkonten belegt; Prüfung mit einem echten Lehrerkonto nötig.) → referred to docs/adr/0004-schulmanager-als-austauschbarer-importbaustein.md Stand 2026-11-13: Andreas stellt sein eigenes Lehrerkonto für die Prüfung bereit (erste Aufgabe von Teilplan 05; Zugangsdaten nur lokal).
- ~~Q-13~~: Ist das Tablet persönlich, oder teilen sich Lehrkräfte Geräte? (Wer gilt dann als handelnde Person?) → answered 2026-11-13: persönlich — ein Tablet gehört einer Lehrkraft; handelnde Person ist immer die Besitzerin bzw. der Besitzer des Geräts. Keine Mehrbenutzer-Anmeldung auf einem Gerät.
- ~~Q-20~~: Woran hängt eine Stiftnotiz – an der Datei (jede Unterrichtsstunde sieht dieselben Notizen) oder an der Zuordnung (jede Unterrichtsstunde hat eigene)? → answered 2026-11-13: an der Zuordnung, je Unterrichtsstunde (FR-6.1).
- Q-22: Wie verhält sich PowerPoint auf dem Tablet über AirPlay – zeigt es die Folie auf dem Bildschirm im Klassenraum und eine Referentenansicht auf dem Tablet, erscheinen Zeichnungen auf der Folie dort sofort, und was sieht die Klasse beim Wechsel zwischen dem Produkt und PowerPoint? (Prüfung mit echtem Tablet und Apple TV nötig; siehe RISK-5.)
- ~~Q-23~~: Ist die Tafel flüchtig, oder gehört das Tafelbild zur Unterrichtsstunde und bleibt erhalten? → answered 2026-11-13: gehört zur Unterrichtsstunde und bleibt (FR-12.2).
- ~~Q-24~~: Bleibt die Tafel bei „Stift auf Seite“ (Vorschlag, um keine Notiz-App zu bauen), oder gehören Textfelder, Formen oder eingefügte Bilder dazu? Bis zur Antwort enthält FR-12 nur Stift, Radierer und Farben. Andreas am 2026-11-13: „think out of the box“ – Vorschlag daraufhin, in den Mockups gezeigt und noch nicht bestätigt: keine Textfelder und Formen, stattdessen drei Dinge, die nur dieses Produkt kann: (a) Kamera des Tablets als Dokumentenkamera – Heft, Buchseite oder Versuch live zeigen, Standbild einfrieren und darauf schreiben; (b) Tafelhintergrund aus der Ablage oder aus dem Material der Stunde – eigene Vorlagen oder ein vergrößerter Ausschnitt einer Seite; (c) Abdecken und Aufdecken – einen Teil der Tafel verdecken und schrittweise freigeben. → answered 2026-11-13: „super Idee“ – alle drei, ohne Textfelder und Formen (FR-12.5 bis FR-12.7, Out of Scope).
- ~~Q-25~~: Was zeigt der Klassenbildschirm, wenn gerade keine Unterrichtsstunde läuft (Pause, vor der ersten Stunde, Ausfall)? Andreas am 2026-11-13: „think out of the box“ – Vorschlag daraufhin, in den Mockups gezeigt und noch nicht bestätigt: Der Klassenbildschirm folgt dem Verlauf der Stunde. Vor Beginn: „Gleich: <Klasse> <Fach>“ mit Countdown bis zum Beginn und dem, was bereitzulegen ist. Während der Stunde: wie FR-11. In den letzten Minuten: die Hausaufgabe groß. Kommt heute keine Unterrichtsstunde mehr: nur Uhrzeit und Datum. Dafür würde der Hinweis aus FR-11.1 in „Bereitlegen“ und „Hausaufgabe“ geteilt. → answered 2026-11-13: ja, aber ohne Countdown bis zum Beginn („finde ich unnötig“) (FR-11.7, FR-11.1 geändert).
- ~~Q-26~~: Ist der Timer (FR-11.2) nur auf dem Klassenbildschirm zu sehen, oder läuft er sichtbar weiter, während Material oder Tafel gezeigt wird? Gibt er am Ende ein Signal? → answered 2026-11-13: ja zu beidem – läuft sichtbar weiter und gibt am Ende ein Signal (FR-11.2 ergänzt).
- ~~Q-27~~: Heißt der Ruhezustand des Zweitbildschirms „Klassenbildschirm“? („Tafel“ ist bestätigt; dieser Name ist Arbeitsbegriff.) → answered 2026-11-13: ja, „Klassenbildschirm“ (Glossar angepasst).
- ~~Q-28~~: Andreas am 2026-11-13: „In der App muss man die AirPlay-Verbindung starten können.“ Befund aus Apples Doku und Entwicklerforen (gelesen 2026-11-13): Eine App kann die Bildschirmverbindung zu einem Apple TV nicht selbst starten; das geht nur über das Kontrollzentrum des Systems („Bildschirmsynchronisierung“). Die AirPlay-Auswahl, die Apps einbauen dürfen (`AVRoutePickerView`), leitet nur Ton und Video weiter und liefert keinen Zweitbildschirm. Was soll stattdessen gelten – (a) die App erkennt die Verbindung sofort und führt bei fehlender Verbindung mit einer kurzen Anleitung dorthin (zwei Handgriffe im Kontrollzentrum), (b) zusätzlich Kabelverbindung empfehlen, die ohne Handgriff steht, (c) technisch untersuchen, ob sich der Zweitbildschirm-Inhalt als Videostrom über die einbaubare AirPlay-Auswahl senden lässt (unbelegt, mit Verzögerung beim Schreiben zu rechnen)? Bis zur Antwort entsteht keine Anforderung. → answered 2026-11-13: (a) und (b) – erkennen, hinführen und Kabel empfehlen (FR-11.6); (c) wird nicht verfolgt.

## Abnahmekriterien

- AK-1 (FR-1): Aufbau: leerer Stundenplan. Handlung: Eintrag „Di, 2. Stunde, 8b, Englisch“ anlegen. Ergebnis: Die Tagesansicht jedes Dienstags zeigt in der 2. Stunde „8b Englisch“.
- AK-2 (FR-1.1): Aufbau: A-Woche Mo 1. Stunde 7a, B-Woche Mo 1. Stunde 9c; Woche vom 16.11. ist A-Woche. Handlung: Tagesansichten Mo 16.11. und Mo 23.11. öffnen. Ergebnis: 16.11. zeigt 7a, 23.11. zeigt 9c.
- AK-42 (FR-1.2): Aufbau: Stundenplan mit Di 2. Stunde 8b, Zeitraster leer. Handlung: 2. Stunde auf 8:35–9:20 setzen; Klassenbildschirm am Di um 8:40 ansehen. Ergebnis: Er zeigt „bis 9:20“; die Tagesansicht zeigt die Zeit an der 2. Stunde.
- AK-3 (FR-2): Aufbau: Schulmanager-Testkonto mit Stundenplan (3 Einträge). Handlung: Import auslösen. Ergebnis: Die 3 Einträge stehen im Stundenplan; ein vorher von Hand angelegter Eintrag geht dabei nicht stillschweigend verloren.
- AK-21 (FR-2.2): Aufbau: Schulmanager-Testkonto; für heute ist dort seit gestern Abend eine Vertretung „3. Stunde 6c“ eingetragen; Tablet war über Nacht gesperrt. Handlung: Tablet um 7:30 Uhr entsperren und Tagesansicht öffnen. Ergebnis: Die Vertretung steht in der 3. Stunde, spätestens wenige Sekunden nach dem Öffnen; die Ansicht zeigt, von wann der Stand ist.
- AK-4 (FR-3): Aufbau: Stundenplan mit „Di 2. Stunde 8b“, eine Präsentation in der Ablage. Handlung: am Mac die Präsentation der Unterrichtsstunde am kommenden Dienstag zuordnen. Ergebnis: Am Tablet zeigt die Tagesansicht dieses Dienstags die Präsentation in der 2. Stunde.
- AK-5 (FR-3, Tablet): wie AK-4, Zuordnung aber am Tablet. Ergebnis: am Mac sichtbar.
- AK-6 (FR-3.1): Aufbau: Unterrichtsstunde mit Präsentation, Arbeitsblatt, Lösung. Handlung: Lösung an Position 1 ziehen. Ergebnis: Tagesansicht zeigt Lösung, Präsentation, Arbeitsblatt.
- AK-7 (FR-3.2): Aufbau: Di 2. Stunde 8a mit 2 Materialien, Mi 3. Stunde 8b ohne. Handlung: „Für 8b übernehmen“. Ergebnis: Mi 3. Stunde 8b hat dieselben 2 Materialien; in der Ablage liegen keine neuen Dateien.
- AK-8 (FR-3.3): Aufbau: Di 8b mit Material X, nächste 8b-Stunde Do. Handlung: X „in die nächste Stunde“. Ergebnis: X steht am Do, nicht mehr am Di.
- AK-9 (FR-3.4): Aufbau: Material zugeordnet, übernommen und geschoben. Handlung: Datei in der Ablage am Mac ändern. Ergebnis: Jede Unterrichtsstunde mit dieser Zuordnung öffnet den geänderten Stand; Dateianzahl in der Ablage unverändert.
- AK-10 (FR-4): Aufbau: Dienstag mit 5 Unterrichtsstunden, davon 3 mit Material. Handlung: Tagesansicht öffnen. Ergebnis: alle 5 Unterrichtsstunden in zeitlicher Reihenfolge, mit Klasse, Fach und Material, ohne Scrollen auf einem 11"-Tablet.
- AK-11 (FR-5): Aufbau: PowerPoint-Datei in iCloud Drive zugeordnet, PowerPoint installiert. Handlung: in der Tagesansicht antippen. Ergebnis: Die Datei öffnet in PowerPoint und lässt sich dort bearbeiten; die Änderung steht danach in der Ablage.
- AK-12 (FR-5.1): Aufbau: PowerPoint-Datei in OneDrive, Lehrkraft mit Microsoft 365 angemeldet. Handlung: antippen, auf einer Folie zeichnen. Ergebnis: PowerPoint zeigt AutoSpeichern an; die Zeichnung ist binnen einer Minute am Mac in derselben Datei sichtbar.
- AK-13 (FR-6): Aufbau: PDF zugeordnet. Handlung: antippen, mit dem Stift auf Seite 1 schreiben, schließen, erneut öffnen. Ergebnis: Die Notiz ist noch da.
- AK-22 (FR-6.1): Aufbau: ein PDF ist Di 8a zugeordnet und per „Für 8b übernehmen“ auch Mi 8b; nächste 8a-Stunde ist Do. Handlung: am Di in der 8a auf Seite 1 schreiben; am Mi in der 8b öffnen; dann das Material von Di 8a „in die nächste Stunde“ schieben und am Do öffnen. Ergebnis: Mi 8b zeigt das PDF ohne Notiz; Do 8a zeigt die Notiz vom Di; die Datei in der Ablage ist unverändert.
- AK-23 (FR-6.2): Aufbau: Tablet per AirPlay mit einem Apple TV verbunden, ein PDF zugeordnet. Handlung: Tagesansicht öffnen; PDF antippen; mit dem Stift auf Seite 1 schreiben; PDF schließen. Ergebnis: Solange die Tagesansicht zu sehen ist, zeigt der Bildschirm am Apple TV sie nicht; nach dem Antippen zeigt er die PDF-Seite im Vollbild ohne Bedienelemente; die Stiftnotiz erscheint dort; nach dem Schließen ist die Tagesansicht weiterhin nur auf dem Tablet. Ohne Apple TV lässt sich derselbe Ablauf auf dem Tablet allein ausführen.
- AK-24 (FR-11): Aufbau: Tablet mit Apple TV verbunden, Di 2. Stunde 8b Englisch läuft (8:35–9:20), kein Material und keine Tafel offen. Handlung: Tagesansicht öffnen. Ergebnis: Der Zweitbildschirm zeigt „8b“, „Englisch“, die Uhrzeit und das Stundenende 9:20 – und weder andere Klassen noch Dateinamen.
- AK-25 (FR-11.1): Aufbau: wie AK-24. Handlung: für die Unterrichtsstunde Thema „Unit 4 – Wortschatz“ und Bereitlegen „Buch, Heft“ eintragen; danach Bereitlegen leeren. Ergebnis: Der Klassenbildschirm zeigt erst beides, danach nur das Thema und keine leere Zeile.
- AK-36 (FR-11.7): Aufbau: Di 2. Stunde 8b Englisch 8:35–9:20 mit Bereitlegen „Buch, Heft“ und Hausaufgabe „Workbook S. 34“; danach an diesem Tag nur noch ein Ausfall; Tablet verbunden. Handlung: Klassenbildschirm um 8:31, 8:40, 9:16 und 9:30 ansehen. Ergebnis: 8:31 „Gleich: 8b Englisch“ und „Buch, Heft“, ohne Countdown; 8:40 Klasse, Fach, Thema, Bereitlegen; 9:16 die Hausaufgabe groß; 9:30 nur Uhrzeit und Datum.
- AK-37 (FR-12.5): Aufbau: Tafel offen, Tablet verbunden. Handlung: Kamera wählen, ein Heft unter das Tablet halten, „Standbild“ tippen, auf das Bild schreiben. Ergebnis: Der Zweitbildschirm zeigt erst das Livebild, dann das Standbild mit dem Geschriebenen; das Standbild ist eine neue Seite des Tafelbilds und nach einem Neustart noch da.
- AK-38 (FR-12.6): Aufbau: Unterrichtsstunde mit einem zugeordneten PDF. Handlung: in der Tafel „Vorlage“ wählen, Seite 1 des PDFs nehmen und einen Ausschnitt um Aufgabe 2 ziehen. Ergebnis: Eine neue Tafelseite zeigt den Ausschnitt vergrößert als Hintergrund und lässt sich beschreiben; das PDF in der Ablage ist unverändert.
- AK-39 (FR-12.7): Aufbau: Tafelseite mit drei Zeilen, Tablet verbunden. Handlung: Abdecken wählen, die Abdeckung bis unter Zeile 1 ziehen, dann bis unter Zeile 2. Ergebnis: Der Zweitbildschirm zeigt erst nur Zeile 1, dann Zeile 1 und 2; am Tablet sind alle drei Zeilen durch die Abdeckung hindurch erkennbar.
- AK-40 (FR-13): Aufbau: frisch geladene App, kein Kauf. Handlung: Stundenplan anlegen, Material zuordnen, öffnen, mit Apple TV verbunden ein PDF zeigen; dann Tafel und Klassenbildschirm antippen; Einmalkauf ausführen; App auf einem zweiten Gerät mit derselben Apple-ID öffnen. Ergebnis: Ohne Kauf funktioniert alles bis einschließlich PDF am Zweitbildschirm; Tafel und Klassenbildschirm zeigen ein Kaufangebot statt der Funktion; nach dem Kauf sind beide auf beiden Geräten frei, ohne erneute Zahlung und ohne Ablaufdatum.
- AK-41 (FR-13.1): Aufbau: kein Kauf. Handlung: Stundenplan-Quelle Schulmanager Online einrichten und importieren. Ergebnis: Der Import funktioniert ohne Kauf; die App bezeichnet die Anbindung als inoffiziell und ohne Gewähr.
- AK-26 (FR-11.2): Aufbau: wie AK-24. Handlung: Timer auf 5 Minuten stellen und starten; nach 1 Minute anhalten; beenden. Ergebnis: Der Klassenbildschirm zählt von 5:00 herunter, bleibt beim Anhalten bei 4:00 stehen und zeigt nach dem Beenden keinen Timer mehr. Wird währenddessen ein PDF oder die Tafel gezeigt, bleibt die Restzeit auf dem Zweitbildschirm sichtbar; läuft der Timer ab, gibt es ein sichtbares und hörbares Signal.
- AK-27 (FR-11.3): Aufbau: wie AK-24. Handlung: „Partnerarbeit“ wählen; Auswahl aufheben. Ergebnis: Der Klassenbildschirm zeigt Symbol und Wort „Partnerarbeit“, danach keine Arbeitsform.
- AK-28 (FR-11.4): Aufbau: Zweitbildschirm zeigt ein PDF. Handlung: „Dunkel“ tippen; erneut tippen. Ergebnis: Der Zweitbildschirm ist schwarz, danach zeigt er wieder dieselbe PDF-Seite; das Tablet zeigt die ganze Zeit das PDF.
- AK-29 (FR-11.5): Aufbau: Tablet mit Apple TV verbunden, ein PDF zugeordnet. Handlung: nacheinander Klassenbildschirm, Material, Tafel und Dunkel wählen. Ergebnis: Der Zweitbildschirm wechselt jeweils; das Vorschaubild am Tablet zeigt jedes Mal dasselbe wie der Zweitbildschirm.
- AK-35 (FR-11.6): Aufbau: Tablet nicht verbunden, Tagesansicht offen. Handlung: „So verbinden“ antippen, den Schritten folgen und im Kontrollzentrum das Apple TV wählen; später die Verbindung trennen; danach ein Kabel zum Bildschirm anstecken. Ergebnis: Die Anleitung nennt die Schritte zur Bildschirmsynchronisierung und die Kabelverbindung; wenige Sekunden nach dem Verbinden zeigt das Tablet den verbundenen Bildschirm an und der Zweitbildschirm den Klassenbildschirm, ohne weiteren Handgriff in der App; nach dem Trennen zeigt das Tablet „nicht verbunden“; mit dem Kabel gilt dasselbe wie mit AirPlay.
- AK-30 (FR-12): Aufbau: Tagesansicht, Unterrichtsstunde läuft. Handlung: Tafel mit einem Tipp öffnen, mit dem Stift ein Wort schreiben, einen Strich radieren. Ergebnis: Der Zweitbildschirm zeigt die Seite mit dem Geschriebenen ohne Bedienelemente; ohne Apple TV geht dasselbe am Tablet allein.
- AK-31 (FR-12.1): Aufbau: Tafel offen, Seite 1 beschrieben. Handlung: Seite hinzufügen, Hintergrund „kariert“ wählen, zurückblättern. Ergebnis: Seite 2 ist kariert und leer, Seite 1 zeigt unverändert das Geschriebene.
- AK-32 (FR-12.2): Aufbau: Di 2. Stunde 8b, Tafel mit zwei beschriebenen Seiten. Handlung: App beenden, am nächsten Tag die Unterrichtsstunde vom Dienstag aufrufen und die Tafel öffnen; danach das Tafelbild löschen. Ergebnis: Beide Seiten sind noch da; nach dem Löschen ist die Tafel dieser Unterrichtsstunde leer.
- AK-33 (FR-12.3): Aufbau: Di 8b Englisch mit Tafelbild; nächste 8b-Englisch-Stunde ist Mi; dazwischen Di 6. Stunde 8a Englisch mit eigenem Tafelbild. Handlung: am Mi in der 8b „letztes Tafelbild“ aufrufen. Ergebnis: Es erscheint das Tafelbild der 8b vom Dienstag, nicht das der 8a.
- AK-34 (FR-12.4): Aufbau: Tafelbild mit zwei Seiten. Handlung: als PDF sichern und einen Ordner wählen. Ergebnis: Dort liegt ein PDF mit zwei Seiten samt Hintergrund; das Tafelbild im Produkt ist unverändert.
- AK-14 (FR-7): Aufbau: Herbstferien 2.–6.11. eingetragen, Material am 3.11. zugeordnet. Handlung: Tagesansicht 3.11. öffnen. Ergebnis: keine Unterrichtsstunden; das Material ist nicht verloren und lässt sich einer anderen Unterrichtsstunde zuordnen.
- AK-15 (FR-8): Aufbau: Di 8b mit Material, nächste 8b-Stunde Do. Handlung: Di als Ausfall markieren, Material weiterreichen. Ergebnis: Di als Ausfall erkennbar, Material am Do.
- AK-16 (FR-9): Handlung: Vertretungsstunde „Mi 4. Stunde 6c Mathe“ anlegen, Material zuordnen. Ergebnis: erscheint in der Tagesansicht am Mittwoch, nur an diesem Datum.
- AK-17 (NFR-1): Aufbau: Material des Tages wurde morgens im WLAN geöffnet bzw. bereitgehalten; danach WLAN aus. Handlung: Material antippen. Ergebnis: es öffnet in unter 3 Sekunden.
- AK-18 (NFR-2): Aufbau: Netzwerkmitschnitt während Einrichten, Vorbereiten und Unterricht. Ergebnis: keine Verbindung zu Servern des Produkts; nur Ablage-Anbieter, Apple, Microsoft (bei FR-5.1) und Schulmanager (bei FR-2).
- AK-19 (NFR-3): Aufbau: je ein Material aus iCloud Drive, OneDrive und Google Drive. Handlung: zuordnen und öffnen. Ergebnis: alle drei öffnen.
- AK-20 (NFR-4): Aufbau: Schulmanager-Import eingerichtet. Handlung: Gerätespeicher und Ablage nach dem Passwort durchsuchen. Ergebnis: nur im sicheren Speicher des Geräts (Schlüsselbund) gefunden.

## Changes

- 2026-11-13: PRD new — Entwurf aus dem Gespräch vom 2026-11-13
- 2026-11-13: Nutzerschaft changed — Tablet ist persönlich (Q-13); Out of Scope um geteilte Tablets ergänzt
- 2026-11-13: FR-3 changed — Vorbereiten auch am Tablet, Mac nicht Voraussetzung (Q-2); Nutzerschaft entsprechend
- 2026-11-13: FR-1.1, FR-7, FR-7.1, FR-8, FR-9 new — Abweichungen vom Stundenplan (Q-5); Glossar um Wochenvariante, unterrichtsfreier Tag, Ausfall, Vertretungsstunde ergänzt
- 2026-11-13: Lieferstufen changed — FR-2 und FR-5.1 als MVP bestätigt (Q-3, Q-4)
- 2026-11-13: FR-2.2 new — Vertretungen aus Schulmanager müssen morgens da sein (Q-15); AK-21, RISK-1 und Lieferstufen (20) angepasst; Q-16 neu
- 2026-11-13: Out of Scope changed — Verweise auf ADR-0001 (Android/Windows) und ADR-0002 (geteilte Tablets) statt „wird ADR“
- 2026-11-13: PRD status ready — freigegeben von Andreas; offen bleiben Q-1, Q-9, Q-10, Q-12 (blockieren die ADR-Ebene nicht)
- 2026-11-13: Abnahmekriterien new — AK-1 bis AK-20 für alle 19 MVP-Anforderungen
- 2026-11-13: FR-10 new — Kalender-Abo als spätere Schnittstelle nach außen (Q-8)
- 2026-11-13: FR-3.1 bis FR-3.4 new — Material je Stunde und Wiederverwenden (Q-6, Q-7); Glossar um Zuordnung ergänzt
- 2026-11-13: FR-6.1 new — Stiftnotizen gehören zur Zuordnung, je Unterrichtsstunde (Q-20, ADR-0006); Glossar um Stiftnotiz ergänzt; AK-22, Lieferstufen (21) und Abdeckung angepasst
- 2026-11-13: FR-6.2 new — Zweitbildschirm zeigt nur das Material, nie die Tagesansicht (Wunsch von Andreas zu AirPlay); Glossar um Zweitbildschirm ergänzt; AK-23, RISK-5, Q-22, Lieferstufen (22) und Abdeckung angepasst
- 2026-11-13: FR-11, FR-11.1 bis FR-11.5, FR-12, FR-12.1 bis FR-12.4 new — Klassenbildschirm und Tafel, alles im MVP auf Wunsch von Andreas (Q-21, Q-23); Glossar um Klassenbildschirm, Tafel, Tafelbild ergänzt; AK-24 bis AK-34, RISK-6, Q-24 bis Q-27, Lieferstufen (33), Nutzerschaft und Abdeckung angepasst
- 2026-11-13: FR-6.2 changed — Zweitbildschirm zeigt neben Material auch Tafel und Klassenbildschirm (FR-11, FR-12)
- 2026-11-13: FR-11.2 changed — Timer läuft über Material und Tafel sichtbar weiter und gibt ein Signal (Q-26); Glossar: Klassenbildschirm als Name bestätigt (Q-27); Q-24 und Q-25 um Vorschläge ergänzt, weiter offen
- 2026-11-13: Q-28 new — Wunsch, die AirPlay-Verbindung in der App zu starten; so nicht möglich, Alternativen zur Entscheidung
- 2026-11-13: FR-11.6 new — Verbindung erkennen, zum Verbinden hinführen, Kabel empfehlen (Q-28); AK-35, Lieferstufen (34) und Abdeckung angepasst
- 2026-11-13: FR-11.7, FR-12.5 bis FR-12.7 new — Klassenbildschirm im Verlauf der Stunde ohne Countdown (Q-25); Dokumentenkamera, Vorlage, Abdecken (Q-24); FR-11.1 changed — Hinweis geteilt in Bereitlegen und Hausaufgabe; AK-25 changed, AK-36 bis AK-39 new; Out of Scope um Notiz-App-Funktionen ergänzt; Lieferstufen (38) und Abdeckung angepasst
- 2026-11-13: Produktname „Pult“ (Q-1), Titel angepasst; Q-29 new (Markenprüfung)
- 2026-11-13: FR-13, FR-13.1 new, FR-13.2 new [Later] — Geschäftsmodell (Q-9); RISK-1 ergänzt, RISK-7 new; AK-40, AK-41, Q-30 new; Lieferstufen (40) und Abdeckung angepasst
- 2026-11-13: Q-30 answered (14,99–19,99 €); Q-29 um Rechercheergebnis ergänzt, weiter offen; RISK-8 new — „PULT“ als Software-Marke der Pult GmbH in Gebrauch
- 2026-11-13: Produktname „Frontstage“ statt „Pult“ (Q-1 changed, Q-29 answered); RISK-8 ergänzt; Q-31 new (Markenprüfung Frontstage)
- 2026-11-13: Glossar changed — Spalte „Im Code“ mit dem englischen Bezeichner je Begriff (ADR-0009)
- 2026-11-13: Glossar changed — Stand, Arbeitsform, Vorlage, Standbild, Bereithalten, Neu verknüpfen ergänzt (beim Planen gefunden)
- 2026-11-13: FR-3.2 changed — Zielstunde wählt die Lehrkraft; FR-3.3 präzisiert — gleiche Klasse und gleiches Fach (gilt für FR-8); FR-13 changed — Thema/Bereitlegen/Hausaufgabe eintragen und Dunkel kostenlos
- 2026-11-13: FR-1.2 new — Zeitraster, abgeleitet aus FR-11 und FR-11.7 (Lücke beim Plan-Cold-Start-Check gefunden); Glossar um Zeitraster ergänzt; AK-42, Lieferstufen (41) und Abdeckung angepasst

## Anhang A — Abdeckung

| Phase | Anforderungen |
|---|---|
| 1 Stundenplan einrichten | FR-1, FR-1.1, FR-1.2, FR-2, FR-2.1, FR-7, FR-7.1 |
| 2 Vorbereiten | FR-3, FR-3.1 bis FR-3.4, FR-8, FR-9 |
| 3 Tagesansicht | FR-4, FR-2.2 |
| 2 Vorbereiten (Thema und Hinweis) | FR-11.1 |
| 4 Öffnen und präsentieren | FR-5, FR-5.1, FR-6, FR-6.1, FR-6.2, FR-11, FR-11.1 bis FR-11.7, FR-12, FR-12.1 bis FR-12.7 |
| 5 Änderungen in der Ablage | FR-5.1, NFR-1 |

FR-10 gehört zu keiner Ablaufphase (Ausgabe nach außen, neben dem Ablauf). FR-13 bis FR-13.2 ebenfalls
nicht (Geschäftsmodell, quer zu allen Phasen).

| Anforderung | Abnahmekriterium |
|---|---|
| FR-1 | AK-1 |
| FR-1.1 | AK-2 |
| FR-1.2 | AK-42 |
| FR-2 | AK-3 |
| FR-2.2 | AK-21 |
| FR-3 | AK-4, AK-5 |
| FR-3.1 | AK-6 |
| FR-3.2 | AK-7 |
| FR-3.3 | AK-8 |
| FR-3.4 | AK-9 |
| FR-4 | AK-10 |
| FR-5 | AK-11 |
| FR-5.1 | AK-12 |
| FR-6 | AK-13 |
| FR-6.1 | AK-22 |
| FR-6.2 | AK-23 |
| FR-11 | AK-24 |
| FR-11.1 | AK-25 |
| FR-11.2 | AK-26 |
| FR-11.3 | AK-27 |
| FR-11.4 | AK-28 |
| FR-11.5 | AK-29 |
| FR-11.6 | AK-35 |
| FR-12 | AK-30 |
| FR-12.1 | AK-31 |
| FR-12.2 | AK-32 |
| FR-12.3 | AK-33 |
| FR-12.4 | AK-34 |
| FR-11.7 | AK-36 |
| FR-12.5 | AK-37 |
| FR-12.6 | AK-38 |
| FR-12.7 | AK-39 |
| FR-13 | AK-40 |
| FR-13.1 | AK-41 |
| FR-7 | AK-14 |
| FR-8 | AK-15 |
| FR-9 | AK-16 |
| NFR-1 | AK-17 |
| NFR-2 | AK-18 |
| NFR-3 | AK-19 |
| NFR-4 | AK-20 |
