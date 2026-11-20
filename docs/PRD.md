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
| Lehrkraft beim Vorplanen des Schuljahrs | je Fach und Jahrgang festlegen, in welcher Woche welches Thema und welcher Leistungsnachweis dran ist; sehen, was frühere Jahre gemacht wurde | FR-15 |
| Lehrkraft vor dem Laden | auf der Startseite sehen, wie die App einen Schultag erleichtert | FR-19 |
| Betreiber (Entwickler) | Rückmeldungen lesen, bearbeiten und fristgerecht löschen | FR-18, FR-18.1, FR-18.2 |

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
| Notiz-Datei | der Ordner `<Name>.frontstage-notizen` neben einem Dokument; enthält je Unterrichtsstunde die Stiftnotizen in einer Form, die Frontstage weiter bearbeiten kann | Material | `PenNoteFile` |
| Notiz-PDF | lesbare Fassung eines Dokuments mit den Stiftnotizen einer Unterrichtsstunde, neben dem Dokument | Material (das Original bleibt unverändert) | `PenNotePDF` |
| Stand | Zeitpunkt, zu dem der Stundenplan zuletzt aus der Stundenplan-Quelle geholt wurde; die Tagesansicht zeigt ihn | Datum einer Unterrichtsstunde | `sourceFetchedAt` |
| Arbeitsform | wie die Klasse gerade arbeitet: Einzelarbeit, Partnerarbeit oder Gruppenarbeit | Fach | `WorkMode` (`individual`, `pairs`, `groups`) |
| Vorlage | Seite oder Ausschnitt aus Material oder Ablage als Hintergrund einer Tafelseite | Material (bleibt unverändert in der Ablage) | `BoardBackground.image`, erzeugt von `TemplateRenderer` |
| Standbild | eingefrorenes Bild der Tablet-Kamera als Hintergrund einer Tafelseite | Material | `BoardBackground.image`, erzeugt von `CameraFeed` |
| Bereithalten | Material der kommenden Unterrichtsstunden vorab auf das Gerät laden | Kopieren (es entsteht keine zweite Datei) | `prefetch` |
| Neu verknüpfen | einen Verweis, der nicht mehr auflöst, auf die Datei in der Ablage zurückführen | Zuordnen | `relink` |
| Timer | eine Zeitspanne für eine Arbeitsphase, die der Klassenbildschirm herunterzählt | Uhrzeit | `PhaseTimer` |
| Abdecken | einen Teil der Tafelseite für die Klasse verdecken und schrittweise freigeben | Löschen | `BoardCover` |
| Kaufangebot | was statt einer gekauften Funktion erscheint, solange der Einmalkauf fehlt | Abo | `PurchaseOffer` |
| Zustand des Materials | ob ein Material auf dem Gerät liegt, geladen wird oder nicht verfügbar ist | Ausfall | `MaterialAvailability` |
| Übergabe | Material zum Bearbeiten an die zuständige App geben, ohne Kopie | Präsentieren | `handOff` |
| Datenort | wo die App-Daten zwischen den Geräten einer Lehrkraft abgeglichen werden: iCloud oder OneDrive (direkt, nach Microsoft-Anmeldung) | Ablage (dort liegt das Material) | `DataLocation` (`iCloud`, `oneDrive`) |
| Datenordner | der Ordner der App in OneDrive (`Apps/Frontstage`), in dem die App-Daten liegen, wenn OneDrive der Datenort ist; die App schreibt dort hinein | Ordnerfreigabe für Material | `DataFolder` |
| Koppeln | ein zweites Gerät übernimmt per QR-Code den Datenort (und bei OneDrive den Datenordner) des ersten | Ordnerfreigabe (gibt einen Ordner für Material frei) | `pairing` |
| Schuljahr | Zeitraum vom ersten bis zum letzten Schultag eines Jahres, mit dem Tag, an dem das zweite Halbjahr beginnt; benannt nach seinen Kalenderjahren, z. B. „2026/27“ | Kalenderjahr | `SchoolYear` (Kennung: `startYear`, z. B. 2026) |
| Halbjahr | erste oder zweite Hälfte eines Schuljahrs; jede Unterrichtswoche gehört zu genau einem | Woche | `Term` (`first`, `second`) |
| Unterrichtswoche | eine Kalenderwoche (ISO-Woche) im Schuljahr mit mindestens einem Unterrichtstag; gezählt ab Beginn des Schuljahrs (Woche 1, 2, …) | Wochenvariante (A-/B-Woche) | `TeachingWeek` |
| Jahrgang | Klassenstufe, z. B. 8 für die Klassen 8a und 8b; aus dem Klassennamen abgeleitet oder von Hand gesetzt | Klasse | `GradeLevel` |
| Jahresplan | Vorplanung eines Schuljahrs für ein Fach und einen Jahrgang (z. B. Englisch, Jahrgang 8, 2026/27): je Unterrichtswoche Thema, Leistungsnachweise und Notizen; alle Klassen dieses Jahrgangs folgen ihm | Stundenplan (wann welche Klasse Unterricht hat) | `CoursePlan` |
| Planwoche | der Eintrag eines Jahresplans für eine Unterrichtswoche: Thema und Notizen; ohne Woche „nicht zugeordnet“ | Unterrichtsstunde | `PlanWeek` |
| Leistungsnachweis | im Jahresplan vorgemerkte Prüfung: Test oder Klassenarbeit, mit Titel, in einer Unterrichtswoche, wahlweise an einem Tag | Ausfall | `Assessment` (`kind`: `test`, `classTest`) |
| Erscheinungsbild | wie die App für die Lehrkraft aussieht: Grundton, Akzentfarbe und Hell/Dunkel; ein Standard ist voreingestellt | Gestaltungsbeschluss (DESIGN.md, gilt für alle) | `Theme` |
| Grundton | Färbung aller neutralen Flächen, Linien und Texte: warm (Standard), System, kühl oder Petrol | Akzentfarbe | `BaseTone` (`warm`, `system`, `cool`, `petrol`) |
| Akzentfarbe | die eine Farbe für Bedienbares (Material-Ziele, Knöpfe, Auswahl); frei wählbar, mit Kontrastschutz | Signalfarbe (Ausfall, Warnung) | `ThemeAccent` |
| Hell/Dunkel | ob die App hell, dunkel oder wie das System erscheint | Dunkel auf dem Zweitbildschirm (FR-11.4) | `AppearanceMode` (`system`, `light`, `dark`) |
| Hilfethema | der Bildschirm oder Bereich, zu dem es einen Hilfeartikel gibt, z. B. „Datenort“ oder „Tafel“ | Thema der Stunde (FR-11.1) | `HelpTopic` |
| Hilfeartikel | der Erklärtext zu einem Hilfethema – kurz, mit Schritten und verwandten Themen; liegt in der App und ist ohne Netz lesbar | Rückmeldung | `HelpArticle` |
| Hilfeknopf | das Fragezeichen an einem Bildschirm oder Bereich; öffnet den Hilfeartikel genau dazu | Kurz-Tipp | `HelpButton` |
| Hilfecenter | alle Hilfeartikel mit Suche, in Einrichten und am Mac im Menü „Hilfe“; von dort geht es auch zur Rückmeldung | Hilfeknopf (führt zu einem Artikel) | `HelpCenter` |
| Rückmeldung | eine Idee oder ein Hinweis der Lehrkraft an die Entwickler, nach Zustimmung zum Rückmeldedienst hochgeladen; ist er nicht erreichbar oder nicht eingerichtet, als E-Mail aus ihrem eigenen Mail-Konto oder über Teilen (ADR-0015) | Bewertung im App Store (öffentlich); Hinweis der Stunde (FR-11.1) | `Feedback` (`kind`: `idea`, `issue`) |
| Bildschirmfoto | Bild in einer Rückmeldung: Aufnahme des App-Fensters oder Foto aus der Mediathek, wahlweise mit Zeichnung und geschwärzten Stellen | Standbild (Tafel), Stiftnotiz | `FeedbackAttachment` (Zeichnung `markup`, Schwärzung `redactions`) |
| Rückmeldedienst | der Dienst der Entwickler, der Rückmeldungen aus der App entgegennimmt und aufbewahrt; läuft als Container beim Betreiber | Datenort (dort liegen die App-Daten der Lehrkraft) | `FeedbackService` (Paket `frontstage_service`, Ordner `server/`) |
| Verwaltungsseite | die passwortgeschützte Webseite des Rückmeldedienstes, auf der die Entwickler Rückmeldungen lesen, bearbeiten, ausführen und löschen | Einrichten (in der App) | `admin` |
| Bearbeitungsstand | wie weit eine Rückmeldung in der Verwaltung ist: neu, in Arbeit, erledigt oder verworfen | Art der Rückmeldung (Idee, Hinweis) | `FeedbackStatus` (`new`, `inProgress`, `done`, `rejected`) |
| Startseite | die öffentliche Webseite des Produkts, die an einem Schultag zeigt, wie die App im Unterricht hilft, mit Impressum und Datenschutz | Tagesansicht (in der App) | `landing` |
| Kurz-Tipp | kurzer Hinweis beim ersten Gebrauch eines Bildschirms, der nach dem Schließen nicht wiederkommt | Hilfeartikel | `HelpTips` (einzelne Tipps als TipKit-`Tip`, z. B. `DaySelectionTip`) |

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
6. Vorplanen (vor Schuljahresbeginn und nebenher): je Fach und Jahrgang das Schuljahr in Wochen planen;
   das Wochenthema und die Leistungsnachweise erscheinen in 2 und 3

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
bestätigt am 2026-11-13.

### FR-2 — Stundenplan aus Schulmanager Online importieren [Later]

Die Lehrkraft kann ihren Stundenplan alternativ aus Schulmanager Online übernehmen. Schulmanager
bietet keine offizielle Schnittstelle; die Anbindung ist inoffiziell (siehe RISK-1).

Geändert 2026-11-20: von [MVP] auf [Later] – die Anbindung ist abgeschaltet, bis ihre Zulässigkeit
(Recht, Datenschutz) geklärt ist; der Baustein bleibt im Code (ADR-0016). Der Kern (FR-13) umfasst
FR-2 und FR-2.2 erst wieder, wenn sie eingeschaltet sind.

### FR-2.1 — Stundenplan aus WebUntis importieren [Later]

Als weitere Stundenplan-Quelle — vom Nutzer genannt („Untis könnte noch angebunden werden“).

### FR-2.2 — Vertretungen aus Schulmanager morgens sichtbar [Later]

Nutzt die Lehrkraft den Schulmanager-Import, zeigt die Tagesansicht Vertretungen und Änderungen des
Tages bereits am Morgen desselben Tages. Vom Nutzer: „müssen morgens da sein“ (Q-15).

Geändert 2026-11-20: von [MVP] auf [Later], folgt FR-2 (ADR-0016). Vertretungen und Ausfälle trägt
die Lehrkraft bis dahin als Abweichung von Hand ein.

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

Präzisiert 2026-11-14: Das lesbare Notiz-PDF neben dem Dokument (FR-6.1, ADR-0011) und das als PDF
gesicherte Tafelbild (FR-12.4) sind abgeleitete Dateien, keine Kopien des Materials; Zuordnungen
verweisen immer auf das Original.

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

Geändert 2026-11-14 (ADR-0011): Die Stiftnotizen einer Unterrichtsstunde liegen neben dem Dokument in
der Ablage – als Notiz-Datei für Frontstage und als lesbares PDF „<Name> – Notizen <Klasse> <Datum>.pdf“,
damit sie auch außerhalb von Frontstage auffindbar sind. Das Original bleibt unverändert. Vom Nutzer:
„Notizen zu Dokumenten müssen neben dem eigentlichen Dokument liegen, sonst findet man es nie wieder.“

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

Geändert 2026-11-15: Zum Kauf gehören zusätzlich die Anpassung des Erscheinungsbilds außerhalb des Standards
(FR-16): andere Grundtöne, eine eigene Akzentfarbe (FR-16.1) und Hell/Dunkel unabhängig vom iPad (FR-16.2).
Kostenlos bleibt der Standard; Hell/Dunkel wie das System gilt immer.

Geändert 2026-11-16: Hilfe, Hilfecenter, Kurz-Tipps und Rückmeldung (FR-17 bis FR-17.5) gehören immer zum
kostenlosen Teil – auch die Hilfeartikel zu bezahlten Funktionen sind ohne Kauf lesbar.

### FR-13.1 — Schulmanager-Import ohne Bezahlung und ohne Gewähr [Later]

Der Import aus Schulmanager Online (FR-2, FR-2.2) gehört immer zum kostenlosen Teil und wird in der
App als inoffizielle Anbindung ohne Gewähr bezeichnet, solange es keine Vereinbarung mit dem Anbieter
gibt (RISK-1).

Geändert 2026-11-20: von [MVP] auf [Later], folgt FR-2 (ADR-0016).

### FR-13.2 — Schulversion für den Sammelkauf [Later]

Für Schulen, die für ihr Kollegium kaufen, eine eigene, bezahlte Fassung mit allen Funktionen ohne
In-App-Kauf, die über Apple School Manager verteilt werden kann (RISK-7). Erst, wenn Schulen danach
fragen.

### FR-14 — Datenort wählbar: iCloud oder OneDrive [MVP]

**Geändert 2026-11-14 (ADR-0012 löst ADR-0010 ab):** Datenort ist iCloud oder OneDrive – direkt über
Microsoft Graph nach der Microsoft-Anmeldung, im Ordner der App in OneDrive (Datenordner). Ein
beliebiger Ordner der Ablage (Nextcloud, Google Drive, iCloud Drive über die Dateien-App) wird aktuell
nicht angeboten. Vom Nutzer: „Nextcloud will ich aktuell nicht anbieten, sondern OneDrive nativ.“ Der
übrige Inhalt gilt weiter. Ursprünglicher Wortlaut (überholt, bleibt stehen):

Die Lehrkraft wählt beim Einrichten, wo die App-Daten (Stundenplan, Abweichungen, Zuordnungen,
Stiftnotizen, Stundenangaben, Tafelbilder) zwischen ihren Geräten abgeglichen werden: in iCloud oder
in einem Ordner ihrer Ablage (z. B. OneDrive, Google Drive, Schul-Nextcloud, iCloud Drive). Mit beiden
Datenorten funktionieren Vorbereiten am Mac und Unterrichten am iPad gleich. Ein späterer Wechsel des
Datenorts nimmt alle Daten mit. Die App schreibt dabei nur in diesen Datenordner, nie in Material
(FR-3.4). Vom Nutzer: „Nicht jeder nutzt iCloud, daher soll es auswählbar sein“ (ADR-0010).

### FR-14.1 — Geräte per QR-Code koppeln [MVP]

Auf dem ersten Gerät (Mac oder iPad) zeigt Einrichten einen QR-Code. Das zweite Gerät scannt ihn mit der
Kamera und übernimmt Datenort und Datenordner, sodass beide Geräte denselben Datenort nutzen, ohne ihn
von Hand zu wählen. Bei OneDrive meldet sich die Lehrkraft am zweiten Gerät mit demselben
Microsoft-Konto an; die App prüft, dass sie denselben Datenordner erreicht. Funktioniert ohne jeden
Server. Hat ein Gerät keine Kamera, zeigt es den QR-Code, und das andere scannt; von Hand wählen bleibt
immer möglich. Vom Nutzer: „ohne Server und QR-Code zum Koppeln“. Verworfen: eigener Server mit
Konto – widerspricht NFR-2.

### FR-15 — Jahresplanung je Fach und Jahrgang [MVP]

Die Lehrkraft plant ein Schuljahr oder Halbjahr vor: in welcher Unterrichtswoche welches Thema behandelt
wird und wann Tests und Klassenarbeiten geschrieben werden, mit Notizen. Ein Jahresplan gilt für ein Fach,
einen Jahrgang und ein Schuljahr (z. B. Englisch, Jahrgang 8, 2026/27) und wird so gespeichert; alle
Klassen dieses Jahrgangs (8a, 8b) folgen ihm, Abweichungen einzelner Klassen stehen als Notiz darin
(ADR-0013). Den Jahrgang einer Klasse leitet das Produkt aus den Ziffern ihres Namens ab („8b“ → 8,
„Q11“ → 11); hat der Name keine Ziffern („EF“), setzt ihn die Lehrkraft von Hand. Jahrespläne werden wie
alle App-Daten über den Datenort abgeglichen (FR-14). Vom Nutzer (2026-11-14): „dass der Lehrer das
Schuljahr/Halbjahr für eine Klasse vorplanen kann. Vorplanen heißt, in welcher Woche welches Thema
behandelt wird, wo Tests und Klassenarbeiten geschrieben werden. Das kann der Lehrer pro Fach und
Jahrgang abspeichern. Notizen machen usw.“ Verworfen: ein Jahresplan je Klasse – feiner, aber doppelte
Arbeit für Parallelklassen und kein Vergleich über die Jahre, weil Klassennamen jedes Jahr wechseln.

### FR-15.1 — Schuljahr und Halbjahre [MVP]

Die Lehrkraft legt in Einrichten je Schuljahr den ersten Schultag, den ersten Tag des zweiten Halbjahrs und
den letzten Schultag fest. Ferien und Feiertage kommen aus den unterrichtsfreien Tagen (FR-7). Der
Jahresplan zeigt nur Unterrichtswochen – Kalenderwochen mit mindestens einem Unterrichtstag (Montag bis
Freitag, nicht unterrichtsfrei) –, gezählt ab Beginn des Schuljahrs und je dem ersten oder zweiten
Halbjahr zugeordnet; eine Woche gehört zum Halbjahr ihres ersten Unterrichtstags.

### FR-15.2 — Planwochen mit Thema, Leistungsnachweisen und Notizen [MVP]

Je Unterrichtswoche trägt die Lehrkraft ein Thema, beliebig viele Leistungsnachweise (Art Test oder
Klassenarbeit, Titel, wahlweise ein Tag dieser Woche) und freie Notizen ein; dazu eine Notiz zum ganzen
Jahresplan. Die Wochen erscheinen nach Halbjahren getrennt. Ändern sich die Daten des Schuljahrs oder die
unterrichtsfreien Tage so, dass eine Woche mit Einträgen keine Unterrichtswoche mehr ist, gehen die
Einträge nicht verloren, sondern stehen am Ende unter „nicht zugeordnet“ und lassen sich einer Woche
zuweisen.

### FR-15.3 — Rückblick auf frühere Schuljahre [MVP]

Zu einem Jahresplan zeigt das Produkt die Jahrespläne früherer Schuljahre für dasselbe Fach und denselben
Jahrgang – auf einen Blick als Liste und nebeneinander, Woche für Woche ab Beginn des Schuljahrs, nur zum
Lesen. Vom Nutzer: „schnellen Überblick darüber haben, was er für das Fach und die Klassenstufe in den
letzten Jahren gemacht hat“.

### FR-15.4 — Vorjahresplan übernehmen [MVP]

„Vorjahresplan übernehmen“ kopiert Themen, Leistungsnachweise und Notizen eines früheren Jahresplans in
den Jahresplan des neuen Schuljahrs: Woche 1 in Woche 1, Woche 2 in Woche 2 usw., gezählt ab Beginn des
Schuljahrs. Ein Leistungsnachweis mit Tag landet am selben Wochentag der Zielwoche; ist der dort
unterrichtsfrei, bleibt er ohne Tag in der Woche. Was keine Zielwoche findet (das neue Schuljahr hat
weniger Unterrichtswochen) oder auf eine Woche mit eigenem Thema bzw. eigenen Notizen träfe, steht am Ende
unter „nicht zugeordnet“. Vorhandene Einträge werden nie überschrieben; der frühere Jahresplan bleibt
unverändert.

### FR-15.5 — Wochenthema in Vorbereiten als Stundenthema vorschlagen [MVP]

Vorbereiten zeigt zu einer Unterrichtsstunde das Thema der Planwoche aus dem Jahresplan ihres Fachs und
des Jahrgangs ihrer Klasse und bietet es mit einem Tipp als Thema der Stunde an (FR-11.1). Übernommen
wird nur auf Tipp; ein schon eingetragenes Thema bleibt, bis die Lehrkraft es ersetzt.

### FR-15.6 — Leistungsnachweise in Tagesansicht und Vorbereiten [MVP]

Ein Leistungsnachweis erscheint als Hinweis an den Unterrichtsstunden der Klassen seines Jahrgangs im
Fach des Jahresplans – mit Tag an diesem Tag, ohne Tag an jeder dieser Unterrichtsstunden der Woche
(„diese Woche“). Vorbereiten zeigt die Leistungsnachweise zusätzlich bei der Woche. Ausfälle tragen keinen
Hinweis.

### FR-16 — Erscheinungsbild anpassbar [MVP]

Die Lehrkraft stellt in Einrichten das Erscheinungsbild der App ein: den Grundton (warm, System, kühl, Petrol),
die Akzentfarbe und Hell/Dunkel. Voreingestellt ist der Standard aus DESIGN.md (warmer Grundton, Standardakzent,
Hell/Dunkel wie das System). Die Einstellung gilt auf allen Geräten der Lehrkraft (Datenort, FR-14). Der
Zweitbildschirm mit Material und Klassenbildschirm folgt ihr nicht; was die Klasse sieht, bleibt eine eigene
Gestaltungsfrage (Q-37). Vom Nutzer am 2026-11-15: „Theme sollte anpassbar sein“; Umfang Grundton, Akzentfarbe,
Hell/Dunkel in der App; freie Farbwahl; Standard frei, Rest im Kauf.

### FR-16.1 — Freie Akzentfarbe mit Kontrastschutz [MVP]

Die Akzentfarbe ist mit dem Farbwähler des Systems frei wählbar. Die App prüft sie gegen den gewählten Grundton,
hell und dunkel: Text in Akzentfarbe auf seiner Tönung braucht mindestens 4,5:1, Symbole mindestens 3:1. Reicht
eine Farbe nicht, verschiebt die App ihre Helligkeit je Modus, bis der Kontrast reicht, und zeigt die so
angepasste Farbe in der Vorschau; die Lehrkraft sieht also immer, was tatsächlich erscheint. Signalfarben
(Ausfall, Warnung, „jetzt, gezeigt“) sind nicht wählbar und bleiben fest.

### FR-16.2 — Hell/Dunkel unabhängig vom iPad [MVP]

Die App kann hell, dunkel oder wie das System erscheinen, unabhängig von der Einstellung des Geräts.

### FR-17 — In-App-Hilfe und Rückmeldung [MVP]

Die App erklärt sich selbst: Zu jedem Bildschirm und jedem schwierigen Bereich gibt es einen Hilfeartikel auf
Deutsch, der in der App liegt und ohne Netz lesbar ist. Aus der Hilfe heraus kann die Lehrkraft den Entwicklern
eine Idee oder einen Hinweis schicken, mit Bildschirmfotos, auf die sie zeichnen kann. Hilfe und Rückmeldung
sind kostenlos, auch für bezahlte Funktionen (FR-13), und brauchen keinen Server des Produkts (NFR-2,
ADR-0014). Geändert 2026-11-16 (ADR-0015): Rückmeldungen gehen bevorzugt an den Rückmeldedienst der Entwickler
(FR-18); die Hilfe bleibt vollständig in der App. Vom Nutzer am 2026-11-16: „implementiere eine in app hilfe. viele hilfe buttons und eine
rückmeldungsmöglichkeit mit idee und hinweise. möglichkeit screenshots mit zeichnung“.

### FR-17.1 — Hilfeknöpfe an jedem Hauptbildschirm und jedem schwierigen Bereich [MVP]

Heute, Vorbereiten, Jahresplan und Einrichten tragen je einen Hilfeknopf (Fragezeichen); dazu jeder Bereich,
der erfahrungsgemäß Fragen aufwirft: Datenort, Koppeln, Ablage und Ordner freigeben, Stundenplan-Quelle
(Schulmanager), Stundenplan, Zeitraster, Ferien und Feiertage, Schuljahr, Erscheinungsbild, Tafel, Anzeige von
PDF und Bild mit Stift, Smartboard verbinden, Klassenbildschirm und Kauf. Ein Hilfeknopf öffnet den Artikel
genau zu diesem Bereich, mit verwandten Themen und „Rückmeldung geben“. VoiceOver nennt ihn „Hilfe zu
<Thema>“; die Artikel folgen der Textgröße des Systems.

### FR-17.2 — Hilfecenter: alle Artikel, durchsuchbar, ohne Netz [MVP]

In Einrichten › Hilfe und Rückmeldung stehen alle Hilfeartikel nach Bereichen geordnet, mit einer Suche über
Titel, Stichwörter und Text; die Suche findet auch ohne Umlaute („ubernehmen“ findet „übernehmen“) und
ohne Groß-/Kleinschreibung. Am Mac öffnet das Menü „Hilfe“ das Hilfecenter (⌘?) und bietet „Rückmeldung
geben …“; am iPad gilt dasselbe mit Tastatur.

### FR-17.3 — Rückmeldung: Idee oder Hinweis, per E-Mail [MVP]

Die Lehrkraft wählt „Idee“ oder „Hinweis“ (etwas klappt nicht oder ist unklar), schreibt einen Text und
schickt ihn über das Mail-Programm des Systems an die Adresse der Entwickler; sie sieht die Mail vor dem
Senden vollständig. Wahlweise hängt sie Geräteangaben an (App-Version, System, Gerätemodell, Art des
Datenorts, Erscheinungsbild, Kaufstand) – voreingestellt aus, nie mit Gerätenamen, Klassen, Dateinamen oder
anderen Inhalten. Ein angefangener Entwurf bleibt auf dem Gerät, bis er gesendet oder verworfen ist; er
wird nicht abgeglichen. Ist kein Mail-Konto eingerichtet, teilt sie die Rückmeldung über den Teilen-Dialog
oder kopiert den Text. Die Mail geht vom Mail-Konto der Lehrkraft aus, nicht über einen Server des Produkts
(NFR-2, ADR-0014).

Geändert 2026-11-16 (ADR-0015 ergänzt ADR-0014): Ist ein Rückmeldedienst hinterlegt (Build-Einstellung
`FEEDBACK_URL`), lädt die App Art, Text, Hilfethema, Bildschirmfotos und – nur wenn eingeschaltet – Geräteangaben
dorthin hoch, mit Fortschritt und erneutem Versuch. Vor dem ersten Senden zeigt sie einmal, was gesendet wird, wohin
und wie lange es aufbewahrt wird (FR-18.2), und verlinkt die Datenschutzseite (FR-19.1); erst nach Zustimmung wird
gesendet. Ist kein Dienst hinterlegt oder ist er nicht erreichbar, bleibt der Weg über Mail, Teilen und Kopieren wie
oben. Der Entwurf bleibt bis zum erfolgreichen Senden auf dem Gerät. Vom Nutzer: „ist es möglich diese funktion in
einen container auszulagern?“

### FR-17.4 — Bildschirmfotos mit Zeichnung [MVP]

Beim Start einer Rückmeldung nimmt die App das aktuelle Fenster auf – ohne das Hilfe- oder
Rückmeldungsfenster – und legt es als erstes Bildschirmfoto bei; die Lehrkraft kann es entfernen. Weitere
Bilder kommen aus der Mediathek, höchstens fünf insgesamt. Auf jedes Bild kann sie zeichnen (Stift, Marker,
Radierer) und Stellen schwärzen; Geschwärztes ist im gesendeten Bild vollständig verdeckt. Ein Hinweis
erinnert daran, dass Bildschirmfotos Klassen-, Datei- und Personennamen zeigen können (RISK-11). Der
Zweitbildschirm wird nie aufgenommen.

### FR-17.5 — Kurz-Tipps beim ersten Gebrauch [MVP]

Wenige Kurz-Tipps erklären beim ersten Öffnen eines Bildschirms das Wichtigste (z. B. dass die laufende
Stunde schon gewählt ist) und erscheinen nach dem Schließen nicht wieder. Im Hilfecenter lassen sie sich
abschalten und zurücksetzen; zurückgesetzte Tipps erscheinen ab dem nächsten Start der App erneut.

### FR-18 — Rückmeldedienst [MVP]

Ein Dienst der Entwickler nimmt Rückmeldungen aus der App entgegen und bewahrt sie auf (ADR-0015). Er prüft jede
Rückmeldung: Art, Text bis 10 000 Zeichen, höchstens fünf Bilder (PNG oder JPEG, je bis 8 MB, zusammen bis 25 MB),
ein gemeinsamer App-Schlüssel als einfache Sperre gegen Fremdeinsendungen und eine Begrenzung je Absenderadresse gegen
Überflutung. IP-Adressen speichert er nicht dauerhaft. Er läuft als ein Container beim Betreiber, hinter dessen
Reverse-Proxy mit TLS. Vom Nutzer am 2026-11-16: „ist es möglich diese funktion in einen container auszulagern? dann
eine admin page und landing page dazu zu bauen“.

### FR-18.1 — Verwaltungsseite [MVP]

Die Entwickler melden sich mit einem Passwort an und sehen alle Rückmeldungen als Liste, filterbar nach Art,
Bearbeitungsstand und Zeitraum, neueste zuerst. Eine Rückmeldung zeigt Text, Hilfethema, Geräteangaben und die
Bildschirmfotos mit Zeichnung und Schwärzung, so wie sie gesendet wurden. Sie setzen den Bearbeitungsstand (neu, in
Arbeit, erledigt, verworfen), schreiben eine interne Notiz, führen die gefilterte Liste als CSV oder JSON aus und
löschen einzelne Rückmeldungen samt Bildern.

### FR-18.2 — Aufbewahrung und Löschen [MVP]

Rückmeldungen werden zwölf Monate nach Eingang automatisch gelöscht, samt Bildern; die Frist ist einstellbar (Q-45).
Bittet eine Lehrkraft um Löschung, löschen die Entwickler ihre Rückmeldung auf der Verwaltungsseite; dafür zeigt die
App nach dem Senden eine kurze Kennung der Rückmeldung.

### FR-19 — Startseite [MVP]

Eine öffentliche Webseite zeigt an einem realistischen Schultag, wie die App im Unterricht hilft: der Blick am
Morgen auf den Tag, ein Tipp und das Material steht am Smartboard, die Tafel mit Stift, der Jahresplan beim
Vorplanen, das eigene Erscheinungsbild. Beispiele nur mit erfundenen Klassen (8b, 9c) und Materialien, ohne
Personennamen. Sie nennt, was kostenlos ist und was der Einmalkauf freischaltet, und führt zum Laden (bis zum
App-Store-Eintrag ein Platzhalter für TestFlight). Sie lädt nichts von fremden Servern – auch Schriften liegen auf
dem eigenen Server – und setzt keine Cookies. Vom Nutzer: „landing page muss eine richtig gute, praxisnahe anwendung mit der app darstellen“.

### FR-19.1 — Impressum und Datenschutz [MVP]

Die Startseite hat ein Impressum und eine Datenschutzerklärung, die den Rückmeldedienst (FR-18) beschreibt: was
gesendet wird, wozu, wie lange es bleibt, wer es liest, wie man Löschung verlangt. Die App verlinkt diese Seite vor dem
ersten Senden (FR-17.3). Die Texte sind bis zur Prüfung erkennbare Platzhalter (Q-44).

### NFR-1 — Material sofort und aktuell verfügbar [MVP]

Im Unterricht öffnet das Material ohne spürbares Warten und ist der aktuelle Stand aus der Ablage
— auch bei unzuverlässigem Schulnetz. Vom Nutzer: „sollen aber sofort und aktuell verfügbar sein“.

### NFR-2 — Keine Daten auf Servern des Produkts [MVP]

**Geändert 2026-11-16 (ADR-0015):** Nutzerdaten – Stundenplan, Abweichungen, Zuordnungen, Material, Stiftnotizen,
Tafelbilder, Jahrespläne, Erscheinungsbild und Zugangsdaten – liegen weiterhin nie auf Servern des Produkts. Einzige
Ausnahme ist eine Rückmeldung (FR-17.3, FR-17.4), die die Lehrkraft ausdrücklich absendet: Sie geht an den
Rückmeldedienst des Betreibers (FR-18). Die App überträgt nie etwas von selbst dorthin. Verworfen: Rückmeldungen über
einen fremden Dienst (z. B. Sentry, UserVoice) – Daten bei einem Auftragsverarbeiter außerhalb der Kontrolle des
Betreibers; nur E-Mail – keine Übersicht, Anhänge verstreut. Ursprünglicher Wortlaut (bleibt stehen):


Stundenplan, Zuordnungen und Material liegen ausschließlich bei der Lehrkraft (Gerät, eigene Ablage,
eigenes Apple-Konto) — das Produkt betreibt keine eigenen Server für Nutzerdaten.

### NFR-3 — Unabhängig vom Ablage-Anbieter [MVP]

Das Produkt funktioniert mit jeder Ablage, die das Tablet einbindet, nicht nur mit OneDrive.

### NFR-4 — Zugangsdaten zu Schulsystemen nur auf dem Gerät [MVP]

Zugangsdaten für eine Stundenplan-Quelle (z. B. Schulmanager) werden nur im sicheren Speicher des
Geräts gehalten und nie an Dritte außer der Quelle selbst übertragen.

## Lieferstufen

- **MVP:** FR-1, FR-1.1, FR-3, FR-3.1 bis FR-3.4, FR-4, FR-5, FR-5.1, FR-6, FR-6.1, FR-6.2, FR-7, FR-8,
  FR-9, FR-11, FR-11.1 bis FR-11.7, FR-12, FR-12.1 bis FR-12.7, FR-13, NFR-1 bis NFR-4, FR-1.2, FR-14, FR-14.1, FR-15, FR-15.1 bis FR-15.6, FR-16, FR-16.1, FR-16.2, FR-17, FR-17.1 bis FR-17.5, FR-18, FR-18.1, FR-18.2, FR-19, FR-19.1 (geprüfte Zahl: 61). FR-2 und FR-5.1 bestätigt (Q-3, Q-4); FR-2 am 2026-11-20 zurückgestellt (ADR-0016).
- **Later:** FR-2, FR-2.1, FR-2.2, FR-7.1, FR-10, FR-13.1, FR-13.2.

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
Ausfall keine bezahlte Funktion trifft. Ergänzt 2026-11-20: Weil die Zulässigkeit (Recht, Datenschutz)
ungeklärt ist, ist die Anbindung abgeschaltet und nicht mehr erreichbar; der Baustein bleibt im Code,
Zugangsdaten werden vom Gerät gelöscht (ADR-0016). Das Risiko ruht, bis die Anbindung wieder eingeschaltet wird.

### RISK-7 — Schulen können den Einmalkauf nicht sammelweise kaufen

In-App-Käufe lassen sich laut Apple nicht über den Sammelkauf in Apple School Manager erwerben und
verteilen. Kauft eine Schule für ihr Kollegium, erreicht sie die Freischaltung aus FR-13 so nicht.
Umgang: Zielgruppe sind zunächst Lehrkräfte mit eigenem Tablet (Q-13), die selbst kaufen; fragen
Schulen, folgt die Schulversion (FR-13.2).

### RISK-9 — Abgleich über einen Ordner in der Ablage ist langsamer und anbieterabhängig

**Geändert 2026-11-14 (ADR-0012):** Statt vom Verhalten einzelner Ablage-Anbieter hängt der zweite
Datenort jetzt an Microsoft: Abgleich nur mit Netz und gültiger Microsoft-Anmeldung auf jedem Gerät;
die Berechtigung `Files.ReadWrite` kann ein Schulträger für Nutzerzustimmung sperren (Q-34); ob die
Änderungsabfrage (Delta) auf dem App-Ordner bei Schulkonten geht, ist am Gerät zu prüfen (Q-33, Rückfall:
Ordner auflisten). Umgang: Stand des Abgleichs sichtbar machen, offline lokal weiterarbeiten, früh mit
einem privaten und einem Schulkonto am Gerät prüfen. Ursprünglicher Wortlaut (überholt):

Mit dem Datenort „Ordner in der Ablage“ (FR-14, ADR-0010) bestimmt der Ablage-Anbieter, wann eine am
Mac vorbereitete Zuordnung auf dem iPad ankommt; manche Anbieter laden Dateien erst beim Öffnen und
erzeugen bei gleichzeitigem Schreiben Konfliktkopien. Umgang: eine Datei je Datensatz, Konfliktkopien
erkennen und zusammenführen, Stand des Abgleichs sichtbar machen; früh mit OneDrive, Google Drive und
iCloud Drive am Gerät prüfen.

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

### RISK-10 — Jahrespläne wachsen über die Jahre und belasten den Abgleich

Jahrespläne werden nie gelöscht, damit der Rückblick (FR-15.3) funktioniert. Bei vier Fach-Jahrgang-
Kombinationen mit je rund 40 Unterrichtswochen kommen jährlich etwa 160 Planwochen und einige Dutzend
Leistungsnachweise dazu, nach zehn Jahren rund 2 000 Datensätze. Beim Datenort OneDrive ist jeder davon
eine eigene Datei; ein neu gekoppeltes Gerät lädt sie alle beim ersten Abgleich (RISK-9), und das
Zusammenführen nach dem Abgleich lädt bisher alle Datensätze vollständig. Dazu kommt, dass ein zweites
Gerät mit einer älteren App-Version die neuen Datensatzarten nicht kennt und sie nicht anzeigt. Umgang:
nur leere Planwochen gar nicht speichern; Zusammenführen der Jahrespläne getrennt vom übrigen Bestand;
beim ersten Abgleich den Fortschritt zeigen; vor dem Start beide Geräte auf dieselbe App-Version bringen.
Ab etwa 5 000 Datensätzen messen, wie lange ein erster Abgleich dauert.

### RISK-11 — Rückmeldungen tragen Schul- und Personendaten zu den Entwicklern

Ein Bildschirmfoto der Tagesansicht zeigt Klassen, Fächer und Dateinamen, ein Foto aus der Mediathek kann
Schülerinnen und Schüler zeigen, und der Text kann Namen enthalten. Mit der Rückmeldung (FR-17.3, FR-17.4)
landen diese Daten im Postfach der Entwickler – außerhalb des Geräts der Lehrkraft. Umgang: Die App
verschickt nichts von selbst; die Lehrkraft sieht die vollständige Mail vor dem Senden; das erste
Bildschirmfoto ist entfernbar, Schwärzen deckt vollständig ab, ein Hinweis erinnert daran; Geräteangaben
sind voreingestellt aus und enthalten nie Namen oder Inhalte. Eingehende Rückmeldungen sind
personenbezogene Daten: Die Datenschutzerklärung muss den Weg nennen, das Postfach wird nur dafür genutzt
und regelmäßig geleert (Q-42).

Geändert 2026-11-16 (ADR-0015): Rückmeldungen landen bevorzugt im Rückmeldedienst (FR-18) statt im Postfach; der
Umgang gilt dort entsprechend, mit Zustimmung vor dem ersten Senden (FR-17.3), automatischer Löschung nach zwölf
Monaten und Löschung auf Anfrage (FR-18.2).

### RISK-12 — Betrieb eines eigenen Dienstes

Mit dem Rückmeldedienst (FR-18) betreibt das Produkt erstmals einen Server: Er kann ausfallen, braucht
Sicherheitsupdates (Basis-Image, Python-Pakete), ist aus dem Netz erreichbar (Spam, Überflutung, Angriffe auf die
Verwaltungsseite) und macht den Betreiber zum Verantwortlichen nach DSGVO (Verzeichnis der Verarbeitung, Auskunft,
Löschung, Datenschutzerklärung, Auftragsverarbeitung mit dem Hoster). Der App-Schlüssel ist aus der App auslesbar und
schützt nur schwach. Umgang: Ein Ausfall bricht nichts – die App fällt auf Mail und Teilen zurück und behält den
Entwurf; ein Container, keine weiteren Dienste; Begrenzung je Adresse und Größenlimits; Verwaltungsseite nur mit
Passwort, sicheren Cookies, CSRF-Schutz und begrenzten Anmeldeversuchen; Image regelmäßig neu bauen; tägliche Sicherung
des Volumes; App Attest als spätere Stufe (ADR-0015). Domain `teach.grathwohl.dev`, eigener Server mit Cloudflare Tunnel (Q-43).

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
- Q-31: Ist „Frontstage“ als Marke frei – DPMAregister, EUIPO eSearch und WIPO Global Brand Database, Klassen 9 und 42, auch ähnliche Schreibweisen („Front Stage“, „FrontStage“)? Websuche 2026-11-13: keine Lehrer-App dieses Namens, aber allgemeines Wort, das Firmen außerhalb der Schule nutzen. Bis zur Registerprüfung ist der Name nur intern festgelegt. Stand 2026-11-14: Register (DPMA, EUIPO/TMview, WIPO, USPTO) ließen sich nicht automatisch abfragen; im App Store gibt es mindestens drei Apps „Frontstage“/„FrontStage“ (Festival, Tickets, Telefonie); Risiko mittel bis hoch bis zur amtlichen Recherche — `docs/research/2026-11-14-markenpruefung-frontstage.md`.
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
- ~~Q-35~~: Gehört die Jahresplanung (FR-15 bis FR-15.6) zum kostenlosen Kern oder zum Einmalkauf (FR-13)? Bis zur Antwort ist sie kostenlos und hinter keiner Freischaltung gebaut; eine spätere Freischaltung braucht nur eine Abfrage an der Stelle „Freischaltung“. → answered 2026-11-14: kostenlos, Teil des Kerns; verkauft werden weiter Klassenbildschirm, Timer, Arbeitsform und Tafel (Andreas).
- ~~Q-36~~: Reichen Notizen für Klassen, die vom Jahresplan abweichen (z. B. 8b eine Woche hinter 8a), oder soll eine Klasse ihren Stand im Jahresplan versetzen können, sodass ihr in Vorbereiten das Thema einer anderen Planwoche vorgeschlagen wird? Bis zur Antwort: nur Notizen (ADR-0013), vorgeschlagen wird immer das Thema der Kalenderwoche. → answered 2026-11-14: Notizen reichen; kein Versatz je Klasse (Andreas). Vorgeschlagen wird weiter das Thema der Kalenderwoche.
- Q-40: Was passiert, wenn eine Lehrkraft eine Akzentfarbe wählt, die einer Signalfarbe gleicht (Rot wie „Entfällt“, Orange wie „nicht verfügbar“, Gelb wie „jetzt, gezeigt“)? Bis zur Antwort: zulässig, Signale bleiben über Symbol und Wort unterscheidbar (DESIGN.md, „Zustände nicht allein am Farbton“); ein Hinweis in der Vorschau wäre möglich.
- Q-42: An welche E-Mail-Adresse gehen Rückmeldungen (FR-17.3), wer liest sie, und wie lange werden sie aufbewahrt (Datenschutzerklärung, RISK-11)? Bis zur Antwort: Die Adresse kommt aus der Build-Einstellung `FEEDBACK_EMAIL` (in CI aus einem Secret); im Repo steht nur der Platzhalter `feedback@example.com`, und ohne echte Adresse bietet die App nur Teilen und „Text kopieren“ (ADR-0014).
- ~~Q-43~~: Unter welcher Domain und bei welchem Hoster laufen Rückmeldedienst und Startseite (FR-18, FR-19), und wer betreibt den Reverse-Proxy mit TLS? Bis zur Antwort: Platzhalter `frontstage.example.com`; die App bekommt die Adresse über `FEEDBACK_URL` aus einem CI-Secret. → answered 2026-11-16: `teach.grathwohl.dev` auf dem eigenen Server des Betreibers, als git-verwalteter Dockhand-Stack (Compose `server/deploy/docker-compose.yml`, Branch main), öffentlich nur über einen Cloudflare Tunnel (TLS bei Cloudflare, keine offenen Ports); `NOINDEX` bis Q-44.
- Q-44: Wie lauten Impressum und Datenschutzerklärung (FR-19.1) – Anbieter, Anschrift, Verantwortlicher, Hoster als Auftragsverarbeiter? Bis zur Antwort: als Platzhalter erkennbare Texte, vor dem ersten öffentlichen Aufruf von einem Menschen zu ersetzen.
- Q-45: Reichen zwölf Monate Aufbewahrung für Rückmeldungen (FR-18.2), oder kürzer (z. B. sechs Monate nach „erledigt“)? Bis zur Antwort: zwölf Monate ab Eingang, einstellbar über `RETENTION_DAYS` (Vorgabe 365).

## Abnahmekriterien

- AK-1 (FR-1): Aufbau: leerer Stundenplan. Handlung: Eintrag „Di, 2. Stunde, 8b, Englisch“ anlegen. Ergebnis: Die Tagesansicht jedes Dienstags zeigt in der 2. Stunde „8b Englisch“.
- AK-2 (FR-1.1): Aufbau: A-Woche Mo 1. Stunde 7a, B-Woche Mo 1. Stunde 9c; Woche vom 16.11. ist A-Woche. Handlung: Tagesansichten Mo 16.11. und Mo 23.11. öffnen. Ergebnis: 16.11. zeigt 7a, 23.11. zeigt 9c.
- AK-42 (FR-1.2): Aufbau: Stundenplan mit Di 2. Stunde 8b, Zeitraster leer. Handlung: 2. Stunde auf 8:35–9:20 setzen; Klassenbildschirm am Di um 8:40 ansehen. Ergebnis: Er zeigt „bis 9:20“; die Tagesansicht zeigt die Zeit an der 2. Stunde.
- AK-3 (FR-2): Aufbau: Schulmanager-Testkonto mit Stundenplan (3 Einträge). Handlung: Import auslösen. Ergebnis: Die 3 Einträge stehen im Stundenplan; ein vorher von Hand angelegter Eintrag geht dabei nicht stillschweigend verloren.
- AK-21 (FR-2.2): Aufbau: Schulmanager-Testkonto; für heute ist dort seit gestern Abend eine Vertretung „3. Stunde 6c“ eingetragen; Tablet war über Nacht gesperrt. Handlung: Tablet um 7:30 Uhr entsperren und Tagesansicht öffnen. Ergebnis: Die Vertretung steht in der 3. Stunde, spätestens wenige Sekunden nach dem Öffnen; die Ansicht zeigt, von wann der Stand ist.
- AK-4 (FR-3): Aufbau: Stundenplan mit „Di 2. Stunde 8b“, eine Präsentation in der Ablage. Handlung: am Mac die Präsentation der Unterrichtsstunde am kommenden Dienstag zuordnen. Ergebnis: Am Tablet zeigt die Tagesansicht dieses Dienstags die Präsentation in der 2. Stunde.
- AK-5 (FR-3, Tablet): wie AK-4, Zuordnung aber am Tablet. Ergebnis: am Mac sichtbar.
- AK-6 (FR-3.1): Aufbau: Unterrichtsstunde mit Präsentation, Arbeitsblatt, Lösung. Handlung: Lösung an Position 1 ziehen. Ergebnis: Tagesansicht zeigt Lösung, Präsentation, Arbeitsblatt.
- AK-7 (FR-3.2): Aufbau: Di 2. Stunde 8a mit 2 Materialien, Mi 3. Stunde 8b ohne. Handlung: „Für 8b übernehmen“, in der Liste der kommenden 8b-Stunden Mi 3. Stunde wählen. Ergebnis: Mi 3. Stunde 8b hat dieselben 2 Materialien; in der Ablage liegen keine neuen Dateien.
- AK-8 (FR-3.3): Aufbau: Di 8b mit Material X, nächste 8b-Stunde Do. Handlung: X „in die nächste Stunde“. Ergebnis: X steht am Do, nicht mehr am Di.
- AK-9 (FR-3.4): Aufbau: Material zugeordnet, übernommen und geschoben. Handlung: Datei in der Ablage am Mac ändern. Ergebnis: Jede Unterrichtsstunde mit dieser Zuordnung öffnet den geänderten Stand; Dateianzahl in der Ablage unverändert.
- AK-10 (FR-4): Aufbau: Dienstag mit 5 Unterrichtsstunden, davon 3 mit Material. Handlung: Tagesansicht öffnen. Ergebnis: alle 5 Unterrichtsstunden in zeitlicher Reihenfolge, mit Klasse, Fach und Material, ohne Scrollen auf einem 11"-Tablet.
- AK-11 (FR-5): Aufbau: PowerPoint-Datei in iCloud Drive zugeordnet, PowerPoint installiert. Handlung: in der Tagesansicht antippen. Ergebnis: Die Datei öffnet in PowerPoint und lässt sich dort bearbeiten; die Änderung steht danach in der Ablage.
- AK-12 (FR-5.1): Aufbau: PowerPoint-Datei in OneDrive, Lehrkraft mit Microsoft 365 angemeldet. Handlung: antippen, auf einer Folie zeichnen. Ergebnis: PowerPoint zeigt AutoSpeichern an; die Zeichnung ist binnen einer Minute am Mac in derselben Datei sichtbar.
- AK-13 (FR-6): Aufbau: PDF zugeordnet. Handlung: antippen, mit dem Stift auf Seite 1 schreiben, schließen, erneut öffnen. Ergebnis: Die Notiz ist noch da. Neben dem PDF liegen der Ordner `<Name>.frontstage-notizen` und `<Name> – Notizen <Klasse> <Datum>.pdf` mit der Notiz; das Original ist unverändert (ADR-0011).
- AK-22 (FR-6.1): Aufbau: ein PDF ist Di 8a zugeordnet und per „Für 8b übernehmen“ auch Mi 8b; nächste 8a-Stunde ist Do. Handlung: am Di in der 8a auf Seite 1 schreiben; am Mi in der 8b öffnen; dann das Material von Di 8a „in die nächste Stunde“ schieben und am Do öffnen. Ergebnis: Mi 8b zeigt das PDF ohne Notiz; Do 8a zeigt die Notiz vom Di; die Datei in der Ablage ist unverändert.
- AK-23 (FR-6.2): Aufbau: Tablet per AirPlay mit einem Apple TV verbunden, ein PDF zugeordnet. Handlung: Tagesansicht öffnen; PDF antippen; mit dem Stift auf Seite 1 schreiben; PDF schließen. Ergebnis: Solange die Tagesansicht zu sehen ist, zeigt der Bildschirm am Apple TV sie nicht; nach dem Antippen zeigt er die PDF-Seite im Vollbild ohne Bedienelemente; die Stiftnotiz erscheint dort; nach dem Schließen ist die Tagesansicht weiterhin nur auf dem Tablet. Ohne Apple TV lässt sich derselbe Ablauf auf dem Tablet allein ausführen.
- AK-24 (FR-11): Aufbau: Tablet mit Apple TV verbunden, Di 2. Stunde 8b Englisch läuft (8:35–9:20), kein Material und keine Tafel offen. Handlung: Tagesansicht öffnen. Ergebnis: Der Zweitbildschirm zeigt „8b“, „Englisch“, die Uhrzeit und das Stundenende 9:20 – und weder andere Klassen noch Dateinamen.
- AK-25 (FR-11.1): Aufbau: wie AK-24. Handlung: für die Unterrichtsstunde Thema „Unit 4 – Wortschatz“ und Bereitlegen „Buch, Heft“ eintragen; danach Bereitlegen leeren. Ergebnis: Der Klassenbildschirm zeigt erst beides, danach nur das Thema und keine leere Zeile.
- AK-36 (FR-11.7): Aufbau: Di 2. Stunde 8b Englisch 8:35–9:20 mit Bereitlegen „Buch, Heft“ und Hausaufgabe „Workbook S. 34“; danach an diesem Tag nur noch ein Ausfall; Tablet verbunden. Handlung: Klassenbildschirm um 8:31, 8:40, 9:16 und 9:30 ansehen. Ergebnis: 8:31 „Gleich: 8b Englisch“ und „Buch, Heft“, ohne Countdown; 8:40 Klasse, Fach, Thema, Bereitlegen; 9:16 die Hausaufgabe groß; 9:30 nur Uhrzeit und Datum.
- AK-37 (FR-12.5): Aufbau: Tafel offen, Tablet verbunden. Handlung: Kamera wählen, ein Heft unter das Tablet halten, „Standbild“ tippen, auf das Bild schreiben. Ergebnis: Der Zweitbildschirm zeigt erst das Livebild, dann das Standbild mit dem Geschriebenen; das Standbild ist eine neue Seite des Tafelbilds und nach einem Neustart noch da.
- AK-38 (FR-12.6): Aufbau: Unterrichtsstunde mit einem zugeordneten PDF. Handlung: in der Tafel „Vorlage“ wählen, Seite 1 des PDFs nehmen und einen Ausschnitt um Aufgabe 2 ziehen. Ergebnis: Eine neue Tafelseite zeigt den Ausschnitt vergrößert als Hintergrund und lässt sich beschreiben; das PDF in der Ablage ist unverändert.
- AK-39 (FR-12.7): Aufbau: Tafelseite mit drei Zeilen, Tablet verbunden. Handlung: Abdecken wählen, die Abdeckung bis unter Zeile 1 ziehen, dann bis unter Zeile 2. Ergebnis: Der Zweitbildschirm zeigt erst nur Zeile 1, dann Zeile 1 und 2; am Tablet sind alle drei Zeilen durch die Abdeckung hindurch erkennbar.
- AK-40 (FR-13): Aufbau: frisch geladene App, kein Kauf. Handlung: Stundenplan anlegen, Material zuordnen, öffnen, mit Apple TV verbunden ein PDF zeigen; dann Tafel und Klassenbildschirm antippen; Einmalkauf ausführen; App auf einem zweiten Gerät mit derselben Apple-ID öffnen. Ergebnis: Ohne Kauf funktioniert alles bis einschließlich PDF am Zweitbildschirm; Tafel und Klassenbildschirm zeigen ein Kaufangebot statt der Funktion; nach dem Kauf sind beide auf beiden Geräten frei, ohne erneute Zahlung und ohne Ablaufdatum.
- AK-43 (FR-14): Aufbau: iPad und Mac ohne iCloud-Anmeldung, auf beiden dasselbe Microsoft-Konto verfügbar. Handlung: auf beiden Geräten beim Einrichten Datenort „OneDrive“ wählen und mit diesem Konto anmelden (am zweiten Gerät auch per Koppeln, FR-14.1); am Mac einen Stundenplan-Eintrag anlegen und Material zuordnen; am iPad mit dem Stift eine Notiz auf ein PDF schreiben. Ergebnis: Eintrag und Zuordnung erscheinen am iPad, die Stiftnotiz am Mac, sobald beide Geräte online abgeglichen haben; das Material selbst ist unverändert; im Datenordner (`Apps/Frontstage` in OneDrive) liegen nur Dateien der App. (Geändert 2026-11-14, ADR-0012; vorher: gemeinsamer OneDrive-Ordner über die Dateien-App, Datenort „Ordner in der Ablage“.)
- AK-44 (FR-14.1): Aufbau: Mac mit Datenort OneDrive und Daten (Stundenplan, Zuordnungen); iPad frisch installiert. Handlung: am Mac in Einrichten „Gerät koppeln“ öffnen; am iPad in Einrichten „Mit anderem Gerät koppeln“ wählen, den QR-Code scannen, mit demselben Microsoft-Konto anmelden und bestätigen. Ergebnis: Das iPad nutzt denselben Datenordner, die Daten vom Mac erscheinen dort; ist am Mac iCloud gewählt, stellt das iPad nach dem Scannen auf iCloud um. Ein QR-Code eines anderen Microsoft-Kontos wird mit einem Hinweis abgelehnt, ohne Daten zu ändern.
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
- AK-18 (NFR-2): Aufbau: Netzwerkmitschnitt während Einrichten, Vorbereiten und Unterricht. Ergebnis: keine Verbindung zu Servern des Produkts; nur Ablage-Anbieter, Apple, Microsoft (bei FR-5.1) und Schulmanager (bei FR-2). Geändert 2026-11-16 (ADR-0015): außer beim ausdrücklichen Senden einer Rückmeldung (FR-17.3) – dann genau eine Verbindung zum Rückmeldedienst.
- AK-19 (NFR-3): Aufbau: je ein Material aus iCloud Drive, OneDrive und Google Drive. Handlung: zuordnen und öffnen. Ergebnis: alle drei öffnen.
- AK-20 (NFR-4): Aufbau: Schulmanager-Import eingerichtet. Handlung: Gerätespeicher und Ablage nach dem Passwort durchsuchen. Ergebnis: nur im sicheren Speicher des Geräts (Schlüsselbund) gefunden.
- AK-45 (FR-15): Aufbau: Stundenplan mit „Di 2. Stunde 8a Englisch“ und „Do 3. Stunde 8b Englisch“; Schuljahr 2026/27 eingerichtet. Handlung: Jahresplan „Englisch, Jahrgang 8, 2026/27“ anlegen und in Woche 1 das Thema „Unit 1 – Back to school“ eintragen; App beenden und neu öffnen; am zweiten Gerät öffnen. Ergebnis: Es gibt genau einen Jahresplan für Englisch 8 – er gilt für 8a und 8b; das Thema steht nach dem Neustart und nach dem Abgleich auf dem zweiten Gerät in Woche 1. Eine Klasse „EF“ im Stundenplan erscheint in Einrichten ohne Jahrgang und lässt sich auf 11 setzen.
- AK-46 (FR-15.1): Aufbau: unterrichtsfreie Zeiträume Herbstferien 2.–6.11.2026 und Weihnachtsferien 23.12.2026–9.1.2027. Handlung: Schuljahr 2026/27 mit erstem Schultag Mo 14.9.2026, Beginn des zweiten Halbjahrs Mo 1.2.2027 und letztem Schultag Mi 28.7.2027 anlegen; Jahresplan öffnen. Ergebnis: 43 Unterrichtswochen, 17 im ersten und 26 im zweiten Halbjahr; Woche 1 ist die KW 38 (14.9.2026); KW 45, KW 53 und KW 1 fehlen; KW 52 (Unterricht am 21. und 22.12.) ist Woche 14; Woche 18 ist die erste des zweiten Halbjahrs (KW 5, 1.2.2027).
- AK-47 (FR-15.2): Aufbau: Jahresplan Englisch 8, 2026/27 wie AK-46. Handlung: in Woche 8 (KW 46) Thema „Unit 2 – Past tense“, Klassenarbeit „KA 1“ am Di 10.11.2026, Test „Vokabeltest Unit 2“ ohne Tag und die Notiz „8b: Hörverstehen nachholen“ eintragen; Jahresnotiz „Lektüre im 2. Halbjahr“; danach den Herbstferien den 9.–13.11.2026 hinzufügen. Ergebnis: Alle Einträge stehen erst in Woche 8; nach der Ferienänderung ist KW 46 keine Unterrichtswoche mehr, Thema, Notiz und beide Leistungsnachweise stehen unter „nicht zugeordnet“ und lassen sich der neuen Woche 8 zuweisen; die Jahresnotiz bleibt.
- AK-48 (FR-15.3): Aufbau: Jahrespläne Englisch 8 für 2024/25 und 2025/26 und Englisch 7 für 2025/26, je mit Themen. Handlung: Jahresplan Englisch 8, 2026/27 öffnen und „Frühere Jahre“ wählen; dann beide früheren nebeneinander zeigen. Ergebnis: Die Liste zeigt 2025/26 und 2024/25 (neuestes zuerst), nicht Englisch 7; nebeneinander stehen die Themen Woche für Woche auf gleicher Zeile; dort lässt sich nichts bearbeiten.
- AK-49 (FR-15.4): Aufbau: Jahresplan Englisch 8, 2025/26 (erster Schultag Mo 15.9.2025, zweites Halbjahr ab 2.2.2026, letzter Schultag Mi 29.7.2026, Herbstferien 27.–31.10.2025; 45 Unterrichtswochen) mit Thema in jeder Woche, Klassenarbeit „KA 1“ am Di 11.11.2025 (Woche 8); Jahresplan 2026/27 wie AK-46, in Woche 2 schon das Thema „Projekt Schulfest“. Handlung: im Jahresplan 2026/27 „Vorjahresplan übernehmen“ mit 2025/26. Ergebnis: Woche 1 hat das Thema der Vorjahreswoche 1; „KA 1“ steht am Di 10.11.2026 in Woche 8; Woche 2 behält „Projekt Schulfest“; unter „nicht zugeordnet“ stehen das Thema der Vorjahreswoche 2 und die Einträge der Vorjahreswochen 44 und 45; der Jahresplan 2025/26 ist unverändert.
- AK-50 (FR-15.5): Aufbau: Jahresplan Englisch 8, 2026/27 mit Thema „Unit 2 – Past tense“ in Woche 8 (KW 46); Unterrichtsstunden Di 10.11.2026 8a Englisch (ohne Thema) und Di 10.11.2026 7a Englisch. Handlung: Vorbereiten öffnen, die Stunde der 8a wählen, den Vorschlag antippen; dann die Stunde der 7a wählen. Ergebnis: Bei 8a erscheint „Unit 2 – Past tense“ als Vorschlag und steht nach dem Tipp als Thema der Stunde (auch auf dem Klassenbildschirm); ohne Tipp bleibt das Thema leer; bei 7a erscheint kein Vorschlag.
- AK-51 (FR-15.6): Aufbau: wie AK-47 (Klassenarbeit „KA 1“ am Di 10.11.2026, Test „Vokabeltest Unit 2“ ohne Tag in KW 46); Stunden Di 10.11. 8a Englisch, Do 12.11. 8b Englisch, Di 10.11. 8a Mathe. Handlung: Tagesansicht Di 10.11. und Do 12.11. öffnen; Vorbereiten für die Woche ab 9.11. öffnen. Ergebnis: Di 8a Englisch zeigt „Klassenarbeit: KA 1“ und „diese Woche: Test Vokabeltest Unit 2“; Do 8b Englisch zeigt nur den Test-Hinweis; 8a Mathe zeigt nichts; Vorbereiten zeigt beide Leistungsnachweise bei der Woche.
- AK-52 (FR-16): Aufbau: frische Installation, iPad im hellen Modus. Handlung: Einrichten › Erscheinungsbild öffnen, ohne Kauf „kühl“ wählen; nach dem Kauf „kühl“ wählen. Ergebnis: Voreingestellt ist warm mit Standardakzent; ohne Kauf erscheint statt der Auswahl das Kaufangebot und die App bleibt warm; nach dem Kauf ist die App kühl, auch auf dem zweiten Gerät nach dem Abgleich.
- AK-53 (FR-16.1): Aufbau: Kauf vorhanden, Grundton warm. Handlung: als Akzentfarbe ein helles Gelb (#FFF3A0) wählen. Ergebnis: Die Vorschau zeigt eine abgedunkelte Fassung; Material-Namen auf ihrer Tönung haben hell und dunkel mindestens 4,5:1; „Entfällt“ und „Material nicht verfügbar“ behalten ihre Farbe.
- AK-54 (FR-16.2): Aufbau: Kauf vorhanden, iPad im hellen Modus. Handlung: in der App „Dunkel“ wählen. Ergebnis: Die App erscheint dunkel, andere Apps bleiben hell; mit „Wie das System“ folgt sie wieder dem iPad.
- AK-55 (FR-17): Aufbau: kein Kauf, iPad im Flugmodus. Handlung: in der Tagesansicht das Fragezeichen antippen; im Hilfecenter den Artikel „Tafel“ öffnen; „Rückmeldung geben“ antippen. Ergebnis: Beide Artikel erscheinen ohne Netz und ohne Kaufangebot; die Rückmeldung lässt sich ohne Kauf schreiben.
- AK-56 (FR-17.1): Aufbau: frische Installation, VoiceOver an. Handlung: auf Heute, Vorbereiten, Jahresplan und Einrichten sowie in Einrichten › Datenort, Ablage und Stundenplan-Quelle jeweils das Fragezeichen ansteuern und antippen. Ergebnis: VoiceOver sagt jeweils „Hilfe zu <Thema>“; jeder Knopf öffnet den Artikel zu genau diesem Bereich, mit verwandten Themen und „Rückmeldung geben“.
- AK-57 (FR-17.2): Aufbau: Mac. Handlung: Menü Hilfe › Frontstage-Hilfe (⌘?); nacheinander „AirPlay“, „ferien“, „ubernehmen“ und „xyz“ suchen. Ergebnis: Das Hilfecenter öffnet sich; „AirPlay“ zeigt „Smartboard verbinden“ als ersten Treffer, „ferien“ zeigt „Ferien und Feiertage“ als ersten Treffer, „ubernehmen“ findet „Vorbereiten“ (Für Klasse übernehmen) und „Jahresplan“ (Vorjahresplan übernehmen); „xyz“ zeigt „Keine Treffer“.
- AK-58 (FR-17.3): Aufbau: Mail-Konto eingerichtet, Empfangsadresse hinterlegt. Handlung: Rückmeldung öffnen, „Hinweis“ wählen, „Tafel speichert nicht“ schreiben; App beenden und neu öffnen; Rückmeldung erneut öffnen, Geräteangaben einschalten, Senden. Ergebnis: Nach dem Neustart steht der Entwurf noch da; das Mail-Fenster zeigt die Empfangsadresse, den Betreff „Frontstage – Hinweis: Tafel speichert nicht“, den Text und Geräteangaben ohne Gerätenamen; nach dem Senden ist der Entwurf leer. Ohne Mail-Konto stehen „Teilen“ und „Text kopieren“ statt „Senden“ zur Wahl. Geändert 2026-11-16 (ADR-0015): Mit hinterlegtem Rückmeldedienst wird hochgeladen statt gemailt – vor dem ersten Senden erscheint einmal der Hinweis mit Link zur Datenschutzseite; nach „Zustimmen und senden“ zeigt die App den Fortschritt und danach eine Kennung; die Rückmeldung erscheint auf der Verwaltungsseite mit Text und Geräteangaben; ist der Dienst nicht erreichbar, bleibt der Entwurf, und die App bietet „Erneut versuchen“ sowie Mail bzw. Teilen an.
- AK-59 (FR-17.4): Aufbau: Tagesansicht mit der Stunde „8b Englisch“. Handlung: Fragezeichen › „Rückmeldung geben“; das erste Bild öffnen, „8b“ schwärzen und einen Pfeil zeichnen; aus der Mediathek Fotos hinzufügen, bis es nicht mehr geht; eines entfernen. Ergebnis: Das erste Bild zeigt die Tagesansicht ohne Hilfefenster; im gesendeten Bild ist „8b“ vollständig schwarz und der Pfeil sichtbar; mehr als fünf Bilder lassen sich nicht hinzufügen; das entfernte Bild fehlt in der Mail.
- AK-61 (FR-18): Aufbau: laufender Container mit leerem Volume. Handlung: per Skript eine gültige Rückmeldung mit zwei Bildern senden; eine ohne App-Schlüssel; eine mit sechs Bildern; eine mit einem 9-MB-Bild; elf Rückmeldungen in einer Minute von derselben Adresse; den Container neu starten. Ergebnis: Die gültige wird mit Kennung bestätigt und ist nach dem Neustart samt Bildern noch da; ohne Schlüssel 401, sechs Bilder und 9 MB 413; die elfte Einsendung 429 mit Angabe, wann es wieder geht; in der Datenbank steht keine IP-Adresse.
- AK-62 (FR-18.1): Aufbau: Dienst mit fünf Rückmeldungen (drei Hinweise, zwei Ideen, eine mit Bild). Handlung: Verwaltungsseite ohne Anmeldung öffnen; mit falschem, dann richtigem Passwort anmelden; nach „Hinweis“ filtern; die mit Bild öffnen, Stand „in Arbeit“ und eine Notiz setzen; als CSV ausführen; eine Rückmeldung löschen; abmelden. Ergebnis: Ohne Anmeldung nur die Anmeldeseite; falsches Passwort abgelehnt; der Filter zeigt drei; das Bild erscheint mit Zeichnung und Schwärzung; Stand und Notiz bleiben nach Neuladen; die CSV hat eine Kopfzeile und fünf Zeilen; nach dem Löschen fehlt die Rückmeldung samt Bilddatei im Volume; nach dem Abmelden führt die Liste zur Anmeldung.
- AK-63 (FR-18.2): Aufbau: Dienst mit `RETENTION_DAYS=365`, eine Rückmeldung vom 2025-11-15 und eine vom 2026-11-15. Handlung: Aufräumlauf am 2026-11-16 auslösen. Ergebnis: Die ältere ist samt Bildern gelöscht, die jüngere bleibt.
- AK-64 (FR-19): Aufbau: Startseite im Browser bei 390 px und 1440 px Breite. Handlung: von oben nach unten scrollen. Ergebnis: Ein Schultag ist in mindestens fünf Stationen erkennbar (Morgen, Smartboard, Tafel, Vorplanen, Erscheinungsbild), jeweils mit einer Darstellung der App; Kostenlos und Einmalkauf sind benannt; der Ladeknopf ist da; nirgends steht ein Personenname; die Seite lädt nichts von fremden Servern (auch keine Schriften) und setzt kein Cookie; keine waagerechte Scrollleiste.
- AK-65 (FR-19.1): Aufbau: Startseite und App mit hinterlegtem Rückmeldedienst. Handlung: Impressum und Datenschutz öffnen; in der App vor dem ersten Senden den Link „Datenschutz“ antippen. Ergebnis: Beide Seiten sind erreichbar; die Datenschutzseite nennt Zweck, Inhalt, die Frist von zwölf Monaten und den Weg zur Löschung; der Link aus der App führt dorthin.
- AK-60 (FR-17.5): Aufbau: frische Installation. Handlung: Tagesansicht öffnen, den Kurz-Tipp schließen, App neu starten; im Hilfecenter „Kurz-Tipps erneut zeigen“, App neu starten; danach „Kurz-Tipps zeigen“ ausschalten und die Tagesansicht erneut öffnen. Ergebnis: Der Tipp erscheint beim ersten Öffnen, nach dem Schließen nicht wieder; nach dem Zurücksetzen und Neustart erscheint er erneut; ausgeschaltet erscheint kein Tipp.

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
- 2026-11-13: AK-7 changed (Zielstunde wählen); Glossar: Vorlage und Standbild auf `BoardBackground.image` korrigiert, Timer, Abdecken, Kaufangebot, Zustand des Materials, Übergabe ergänzt
- 2026-11-13: FR-1.2 new — Zeitraster, abgeleitet aus FR-11 und FR-11.7 (Lücke beim Plan-Cold-Start-Check gefunden); Glossar um Zeitraster ergänzt; AK-42, Lieferstufen (41) und Abdeckung angepasst
- 2026-11-13: FR-1.2 bestätigt von Andreas
- 2026-11-14: FR-14 new — Datenort wählbar, iCloud oder Ordner in der Ablage (ADR-0010 löst ADR-0002 ab); AK-43, RISK-9, Glossar Datenort und Datenordner; Lieferstufen (42)
- 2026-11-14: FR-14 changed — Datenort iCloud oder OneDrive direkt über Microsoft Graph (ADR-0012 löst ADR-0010 ab); Nextcloud und Google Drive aktuell nicht; AK-43, RISK-9, Glossar Datenort (`oneDrive` statt `folder`) und Datenordner (Ordner der App in OneDrive) angepasst
- 2026-11-14: FR-14.1 new — Geräte per QR-Code koppeln; AK-44, Glossar Koppeln (`pairing`); Lieferstufen (43)
- 2026-11-14: Verworfen (FR-14.1): eigener Server mit Website und Konto zum Koppeln oder Abgleichen – von Andreas abgelehnt, NFR-2 bleibt
- 2026-11-14: FR-6.1 changed — Stiftnotizen neben dem Dokument als Notiz-Datei und lesbares PDF (ADR-0011 löst ADR-0006 ab); FR-3.4 präzisiert (abgeleitete Dateien); AK-13 ergänzt; Glossar Notiz-Datei, Notiz-PDF
- 2026-11-14: FR-15, FR-15.1 bis FR-15.6 new — Jahresplanung je Fach, Jahrgang und Schuljahr (Wunsch von Andreas, ADR-0013); Glossar um Schuljahr, Halbjahr, Unterrichtswoche, Jahrgang, Jahresplan, Planwoche, Leistungsnachweis ergänzt; Nutzerschaft, Ablauf (Schritt 6), AK-45 bis AK-51, RISK-10, Q-35, Q-36, Lieferstufen (50) und Abdeckung angepasst
- 2026-11-14: Verworfen (FR-15): ein Jahresplan je Klasse – feiner, aber doppelte Arbeit für Parallelklassen und kein Vergleich über die Jahre, weil Klassennamen jährlich wechseln
- 2026-11-14: Q-35, Q-36 answered — Jahresplanung bleibt kostenlos, abweichende Klassen nur über Notizen (Andreas); Q-31 changed — Stand der Websuche, Prüfnotiz in docs/research/
- 2026-11-15: FR-16, FR-16.1, FR-16.2 new — Erscheinungsbild anpassbar (Wunsch von Andreas): Grundton, freie Akzentfarbe mit Kontrastschutz, Hell/Dunkel in der App; FR-13 changed (Anpassung außerhalb des Standards im Kauf); Glossar um Erscheinungsbild, Grundton, Akzentfarbe, Hell/Dunkel ergänzt; AK-52 bis AK-54, Q-40, Lieferstufen (53) und Abdeckung angepasst
- 2026-11-16: FR-17, FR-17.1 bis FR-17.5 new — In-App-Hilfe mit Hilfeknöpfen, Hilfecenter, Rückmeldung per E-Mail mit Bildschirmfotos und Zeichnung, Kurz-Tipps (Wunsch von Andreas, ADR-0014); FR-13 changed (Hilfe und Rückmeldung immer kostenlos); Glossar um Hilfethema, Hilfeartikel, Hilfeknopf, Hilfecenter, Rückmeldung, Bildschirmfoto, Kurz-Tipp ergänzt; AK-55 bis AK-60, RISK-11, Q-42, Lieferstufen (59) und Abdeckung angepasst
- 2026-11-16: NFR-2 changed — Ausnahme für ausdrücklich gesendete Rückmeldungen (ADR-0015); FR-17, FR-17.3 changed — Hochladen zum Rückmeldedienst mit Zustimmung, Mail/Teilen als Rückfall; AK-58 changed; FR-18, FR-18.1, FR-18.2, FR-19, FR-19.1 new — Rückmeldedienst im Container, Verwaltungsseite, Aufbewahrung, Startseite, Impressum und Datenschutz (Wunsch von Andreas); Glossar um Rückmeldedienst, Verwaltungsseite, Bearbeitungsstand, Startseite ergänzt; AK-61 bis AK-65, RISK-11 changed, RISK-12 new, Q-43 bis Q-45 new, Lieferstufen (64) und Abdeckung angepasst
- 2026-11-16: Verworfen (FR-19): Schriften von Google Fonts laden – überträgt die IP-Adresse jedes Besuchers an Google ohne Einwilligung (LG München I, 20.01.2022, 3 O 17493/20); stattdessen Schriften mit freier Lizenz auf dem eigenen Server
- 2026-11-16: Verworfen (NFR-2, FR-18): fremder Dienst für Rückmeldungen (Sentry, UserVoice – Auftragsverarbeiter außerhalb der Kontrolle), nur E-Mail (keine Übersicht); Node/TypeScript statt Python, je Teil ein eigener Container, Postgres statt SQLite – siehe ADR-0015
- 2026-11-16: Verworfen (FR-17.3): eigenes Web-Formular bzw. eigener Endpunkt (Server, widerspricht NFR-2), GitHub-Issues (Zugangsschlüssel in der App), nur TestFlight-Feedback (gibt es im App Store nicht), App-Store-Bewertungen (öffentlich, ohne Bildschirmfotos) – siehe ADR-0014
- 2026-11-16: Q-43 answered — teach.grathwohl.dev, Dockhand-Git-Stack, Cloudflare Tunnel
- 2026-11-16: Glossar „Rückmeldung“ changed — Hochladen zum Rückmeldedienst zuerst, Mail/Teilen als Rückfall (ADR-0015)
- 2026-11-20: FR-2, FR-2.2, FR-13.1 changed — [MVP] → [Later]: Schulmanager-Anbindung abgeschaltet wegen ungeklärter Zulässigkeit (Recht, Datenschutz), Baustein bleibt im Code (ADR-0016); RISK-1 ergänzt; Lieferstufen (61) angepasst
- 2026-11-20: Verworfen (FR-2): Code löschen (Andreas: „nicht löschen“), Ausschluss per `#if` (verrottet unbemerkt), Schalter in den Einstellungen oder per Fernkonfiguration (Funktion bliebe erreichbar, Fernkonfiguration bräuchte einen Server) – siehe ADR-0016

## Anhang A — Abdeckung

| Phase | Anforderungen |
|---|---|
| 1 Stundenplan einrichten | FR-1, FR-1.1, FR-1.2, FR-2, FR-2.1, FR-7, FR-7.1 |
| 2 Vorbereiten | FR-3, FR-3.1 bis FR-3.4, FR-8, FR-9 |
| 3 Tagesansicht | FR-4, FR-2.2 |
| 2 Vorbereiten (Thema und Hinweis) | FR-11.1 |
| 4 Öffnen und präsentieren | FR-5, FR-5.1, FR-6, FR-6.1, FR-6.2, FR-11, FR-11.1 bis FR-11.7, FR-12, FR-12.1 bis FR-12.7 |
| 5 Änderungen in der Ablage | FR-5.1, NFR-1 |
| 6 Vorplanen | FR-15, FR-15.1 bis FR-15.4 |
| 2 Vorbereiten (Wochenthema, Leistungsnachweise) | FR-15.5, FR-15.6 |
| 3 Tagesansicht (Leistungsnachweise) | FR-15.6 |

FR-10 gehört zu keiner Ablaufphase (Ausgabe nach außen, neben dem Ablauf). FR-13 bis FR-13.2 ebenfalls
nicht (Geschäftsmodell, quer zu allen Phasen), ebenso FR-17 bis FR-17.5 (Hilfe und Rückmeldung, in jeder
Phase erreichbar) und FR-18 bis FR-19.1 (Rückmeldedienst, Verwaltung und Startseite liegen außerhalb der App).

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
| FR-14 | AK-43 |
| FR-14.1 | AK-44 |
| FR-15 | AK-45 |
| FR-15.1 | AK-46 |
| FR-15.2 | AK-47 |
| FR-15.3 | AK-48 |
| FR-15.4 | AK-49 |
| FR-15.5 | AK-50 |
| FR-15.6 | AK-51 |
| FR-16 | AK-52 |
| FR-16.1 | AK-53 |
| FR-16.2 | AK-54 |
| FR-17 | AK-55 |
| FR-17.1 | AK-56 |
| FR-17.2 | AK-57 |
| FR-17.3 | AK-58 |
| FR-17.4 | AK-59 |
| FR-17.5 | AK-60 |
| FR-18 | AK-61 |
| FR-18.1 | AK-62 |
| FR-18.2 | AK-63 |
| FR-19 | AK-64 |
| FR-19.1 | AK-65 |
| FR-7 | AK-14 |
| FR-8 | AK-15 |
| FR-9 | AK-16 |
| NFR-1 | AK-17 |
| NFR-2 | AK-18 |
| NFR-3 | AK-19 |
| NFR-4 | AK-20 |
