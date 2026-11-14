---
status: draft
date: 2026-11-15
---

# Frontstage — Gestaltung

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

### UI-1 — Das App-Icon zeigt die heutige Stunde, die zur großen Fläche wird

- category: app-icon
- Constrained by: ADR-0001

**Entscheidung:** Das App-Icon ist der Entwurf „Heute“: auf Petrol eine Spalte aus Stundenblöcken;
die aktuelle Stunde leuchtet gelb und geht als ein Balken in eine große gelbe Fläche über – das
Smartboard. Quelle: `design/icon/frontstage-app-icon.svg`, für den eingefärbten Darstellungsmodus
`design/icon/frontstage-app-icon-mono.svg`. Farben: Grund Petrol `#0E4B57`, übrige Stunden Blassgrünblau
`#8FC3C9`, aktive Stunde und Fläche Signalgelb `#FFC94A`. Gewählt von Andreas am 2026-11-13.

**Kontext:** Auswahl zwischen sechs gerenderten Entwürfen aus drei Blickwinkeln (Apples
Icon-Richtlinien, Markenidentität, Formsprache), je groß, auf hellem und dunklem Home-Bildschirm, in
29 pt und eingefärbt (`mockup/logo/index.html`). Das Icon erzählt den Kernablauf des Produkts – die
heutige Stunde antippen, die Klasse sieht das Material groß – statt den Gegenstand Pult abzubilden.
Eine Farbe trägt genau eine Bedeutung: Gelb heißt „jetzt, gezeigt“.

**Verworfen, jeweils mit Vorzug:**
- „Stehpult“ (Pult im Profil, Material in Safran) — erzählt am wörtlichsten „alles liegt bereit“.
- „Übertragung“ (Lichtkegel vom Pult auf eine Fläche) — zeigt das Steuern des Smartboards am direktesten.
- „Pult“ (schräge Pultfläche mit einem Blatt) — warm, ruhig, gegenständlich.
- „Lichtpult“ (P-Form mit leuchtendem Bildschirm) — trug Anfangsbuchstabe und Bedeutung zugleich und war
  in 29 pt am klarsten; Empfehlung im Gespräch.
- „Pultkante“ (Stehpult auf Ocker) — stärkste Silhouette, fällt auf dem Home-Bildschirm am meisten auf.

**Konsequenzen mit Kosten:**
- Kein Bezug zum Wort „Pult“ im Zeichen; Name und Icon müssen sich gegenseitig erklären.
- Abstrakt: ohne Erklärung auch als Flussdiagramm oder Stecker lesbar.
- In 29–40 pt verschmelzen die schmalen Stundenblöcke fast zu Strichen; erkennbar bleibt das Muster
  „Spalte plus großes gelbes Feld“.
- Die Icon-Farben sind **keine** Palette der Oberfläche. Sie binden die Oberfläche nicht; die Kategorie
  Farbe bleibt offen. Übernimmt die Oberfläche später Gelb, dann nur mit derselben Bedeutung
  („jetzt, gezeigt“).
- Für den Bau ist das Icon in Apples Icon-Werkzeug als Ebenen anzulegen (Hintergrund, Stundenblöcke,
  gelbe Form), damit das System Glas-Effekte und den dunklen und eingefärbten Modus erzeugen kann –
  beim ersten Bau zu belegen.

**Revisit if:** Testerinnen erkennen das Icon auf dem Home-Bildschirm nicht als „Pult“ wieder, oder
die Markenprüfung (Q-29) erzwingt einen anderen Namen, zu dem ein gegenständliches Zeichen besser passt.

*Ergänzt 2026-11-13:* Das Produkt heißt jetzt „Frontstage“ (PRD, Q-1). Das Icon bleibt: Die Stunde, die
nach vorn auf die große Fläche tritt, ist genau „front stage“. Der erste Kostenpunkt (kein Bezug zum
Namen) entfällt damit. Revisit if gilt jetzt sinngemäß: Testerinnen erkennen das Icon nicht als
„Frontstage“ wieder.

---

### UI-2 — Referenz ist die Tagesansicht am iPad quer, im Stehen bedient

- category: 0
- Constrained by: ADR-0001

**Entscheidung:** Alle Gestaltungsrunden werden an der Tagesansicht („Heute“) auf einem iPad im Querformat
gerendert, Fenstergröße etwa 1180 × 820 pt (iPad Air 11"). Modus: **Operate** – ein Werkzeug, das bedient wird,
nicht überzeugt. Nutzungsszene: Die Lehrkraft steht vor der Klasse, schaut kurz auf das iPad auf dem Pult oder in
der Hand, tippt einmal und ist wieder bei der Klasse; das Smartboard ist die zweite Fläche. Bestätigt von Andreas
am 2026-11-14.

**Kontext:** Feststellung, keine Auswahl. Heute baut die App auf Reitern auf (Heute, Vorbereiten, Jahresplan,
Einrichten), am iPad als Leiste oder Seitenleiste wählbar (`Frontstage/App/RootView.swift:41`, `.sidebarAdaptable`);
die Tagesansicht ist eine Liste von Stundenzeilen mit Stunde, Klasse · Fach, Aussage, Materialknöpfen und
„Tafel“ (`Frontstage/UI/DayView/DayRowView.swift`), Zeilenhöhe füllt den Schirm, solange alles passt
(`DayViewLayout`). Gerendert wird per **HTML-Nachbau** der echten Oberfläche mit Beispieldaten, weil die App
unter Windows nicht läuft und jeder Simulator-Lauf macOS-Minuten kostet.

**Verworfen, jeweils mit Vorzug:**
- Vorbereiten am Mac als Referenz — dort verbringt man die meiste Zeit, und die Oberfläche ist am dichtesten.
- Klassenbildschirm als Referenz — wirkt nach außen; wird aber kaum bedient, Operate-Entscheidungen ließen sich
  dort nicht prüfen.
- Rendern im Simulator per CI — originalgetreu, aber ein macOS-Lauf je Runde.
- Rendern am eigenen Mac — originalgetreu und ohne CI, aber derzeit nicht verfügbar.

**Konsequenzen mit Kosten:**
- Vorbereiten und Jahresplan erben Beschlüsse, die an der Tagesansicht getroffen wurden; wo der Mac mit Maus und
  hoher Dichte etwas anderes braucht, kann eine spätere Runde das ausdrücklich wieder aufmachen.
- Der HTML-Nachbau zeigt Abstände, Schrift, Farbe und Formen verlässlich (Kategorien 2–7). Bedienkonzept,
  Zustände und Bewegung (1, 8, 9) zeigt er nur angenähert; diese Beschlüsse sind beim ersten Bau am Gerät zu
  bestätigen.

**Revisit if:** Ein Mac steht zum Rendern bereit, oder die Prüfung am Gerät widerspricht einem Beschluss, der am
Nachbau gefallen ist.

---

### UI-3 — Die Tagesansicht ist Liste und Detail: links der Tag, rechts die gewählte Stunde

- category: 1
- Constrained by: UI-2

**Entscheidung:** Die Tagesansicht teilt sich in eine schmale Liste der Stunden des Tages (Stunde, Uhrzeit,
Klasse · Fach, eine Aussagezeile) und einen Detailbereich mit der gewählten Unterrichtsstunde: Thema,
Hinweise, das Material in Reihenfolge als große Ziele, die Tafel und die Aktionen der Stunde. Gewählt von
Andreas am 2026-11-14 an vier gerenderten Varianten (HTML-Nachbau, UI-2).

**Kontext:** Ist-Zustand war eine Liste über die ganze Breite mit Materialknöpfen in jeder Zeile
(`Frontstage/UI/DayView/DayView.swift`, `DayRowView.swift`); Aktionen wie „Entfällt“ und „Weiterreichen“
stecken im Kontextmenü. Vorbereiten und Jahresplan nutzen bereits Liste und Detail (`NavigationSplitView` in
`PreparationView.swift`, `CoursePlanView.swift`) – die Tagesansicht schließt sich dieser Form an.

**Verworfen, jeweils mit Vorzug:**
- A, Ist-Zustand (Liste über die ganze Breite, Material in der Zeile) — der ganze Tag und jedes Material mit
  einem Tipp erreichbar, ohne Auswahlschritt.
- C, Fokus auf „Jetzt“ (laufende Stunde füllt den Schirm, Tag als Leiste) — größte Ziele, kürzester Blick im
  Stehen.
- D, Seitenpanel über der Liste — volle Liste bleibt sichtbar, Detail nur bei Bedarf.

**Konsequenzen mit Kosten:**
- Ein Material einer **anderen** als der gewählten Stunde braucht zwei Tipps (Stunde wählen, Material). Damit der
  Unterricht beim einen Tipp bleibt (FR-5), muss beim Öffnen der Tagesansicht und beim Stundenwechsel die
  laufende oder nächste Unterrichtsstunde automatisch gewählt sein; eine von Hand gewählte Stunde bleibt, bis
  die Lehrkraft wechselt. Das ist Verhalten, im Bau festzulegen und am Gerät zu prüfen.
- Die Liste zeigt je Stunde nur eine Aussagezeile; alle vier Aussagen (keine Stunde, ohne Material, nicht
  verfügbar, Ausfall) müssen dort unterscheidbar bleiben (siehe „Wiederkehrende Fallen“).
- Im Hochformat und in Split View wird die Liste schmal; dort darf sie als einklappbare Seitenleiste
  erscheinen (Systemverhalten von `NavigationSplitView`).
- Größe, Form und Farbe der Ziele im Detailbereich sind **nicht** mitentschieden (Runden 2–8); die Kacheln im
  Nachbau waren nur Platzhalter.
- Beschluss am HTML-Nachbau; beim ersten Bau am Gerät bestätigen (UI-2).

**Revisit if:** Am Gerät zeigt sich, dass im Unterricht häufig Material außerhalb der gewählten Stunde geöffnet
wird, oder die automatische Wahl der laufenden Stunde stört beim Vorausschauen.

---

### UI-4 — Die Zeilen füllen die Höhe: der ganze Tag ohne Scrollen

- category: 2
- Constrained by: UI-2, UI-3

**Entscheidung:** Die Liste der Tagesansicht bleibt bei der heutigen Dichte: Die Zeilen teilen sich die verfügbare
Höhe, höchstens 96 pt, mindestens 44 pt, 8 pt Abstand (`Frontstage/UI/DayView/DayViewLayout.swift`); bei 6 Stunden
96 pt, bei 8 Stunden etwa 78 pt. Erst wenn selbst 44 pt nicht mehr passen, scrollt die Liste. Für den neuen
Detailbereich (UI-3) gilt die Skala, die mit dieser Dichte gerendert wurde: 32 pt Rand, 24 pt zwischen
Abschnitten, 16 pt zwischen Material-Zielen, Material-Ziele etwa 200 pt hoch. Gewählt von Andreas am 2026-11-15.

**Kontext:** Drei Varianten derselben Liste-und-Detail-Ansicht, je mit 6 und 8 Stunden gerendert (HTML-Nachbau).
Der Nachbau aus Runde 1 hatte 6 statt 8 pt Zeilenabstand; maßgeblich ist der Wert im Code. Die Werte des
Detailbereichs stammen aus dem Nachbau, weil es ihn im Code noch nicht gibt.

**Verworfen, jeweils mit Vorzug:**
- Kompakt (Zeilen 44 pt fest, Skala 4/8, Material-Ziele 120 pt) — Systemdichte von iPadOS, auch lange Tage
  belegen nur die halbe Höhe.
- Großzügig (Zeilen 112 pt fest, Skala 16/24/32, Material-Ziele 280 pt) — größte Ziele für die Bedienung im
  Stehen auf Armlänge; dafür scrollt die Liste schon bei 6 Stunden.

**Konsequenzen mit Kosten:**
- Die Zeilenhöhe ändert sich mit der Zahl der Stunden; ein langer Tag sieht dichter aus als ein kurzer. Die
  Schriftskala (Runde 4) muss in die kleinste übliche Höhe (etwa 78 pt bei 8 Stunden) passen.
- Bei großer Dynamic-Type-Stufe oder vielen Stunden fällt die Liste auf Scrollen zurück; der Detailbereich
  scrollt eigenständig.
- Beschluss am HTML-Nachbau; beim ersten Bau am Gerät bestätigen (UI-2).

**Revisit if:** Am Gerät sind die Ziele bei 8 Stunden im Stehen zu klein, oder Runde 4 findet keine
Schriftskala, die in 78 pt drei Zeilen trägt.

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

- Q-19: Die Tagesansicht ist während des Unterrichts per Bildschirmspiegelung für die Klasse sichtbar. Was darf dort stehen, was nicht (z. B. Material anderer Klassen, Lösungen, Namen von Dateien wie „KA 1 9b“)? — eingegrenzt 2026-11-13 durch FR-6.2: Mit Zweitbildschirm sieht die Klasse die Tagesansicht nicht. Offen bleibt die Frage für reine Bildschirmspiegelung (z. B. beim Wechsel zu einer anderen App, RISK-5).
- ~~Q-21~~: Was zeigt der Zweitbildschirm, solange kein Material geöffnet ist (FR-6.2) – eine leere Fläche, Klasse und Fach der laufenden Unterrichtsstunde, die Uhrzeit, etwas anderes? → answered 2026-11-13: den Klassenbildschirm mit Klasse, Fach, Uhrzeit, Stundenende, Thema, Hinweis, Timer und Arbeitsform (FR-11, FR-11.1 bis FR-11.3). Wie er aussieht, ist wie jede Kategorie hier offen.
- Q-37: Wie zeigt sich der Klassenbildschirm auf Distanz (FR-11 bis FR-11.3)? Offen seit Teilplan 07, gebaut mit Systemvorgaben: Schriftgrößen (Systemstile, aus dem Klassenraum vermutlich zu klein), Farben, Symbole der Arbeitsform (`person`, `person.2`, `person.3`), Material der Timer-Karte, Timer-Signal (Platzhalter Sinus 880 Hz, dreimal), Wortlaut.
- Q-38: Wie sieht die Tafel aus (FR-12 bis FR-12.7)? Offen seit Teilplan 07, gebaut mit Systemvorgaben: Breite (220 pt) und Reihenfolge der Seitenleiste, Seitenvorschauen statt Nummern, Farbe und Abstand der Linien und Karos, Farbe der Abdeckung (Platzhalter Schwarz; die Systemhintergrundfarbe wäre auf der weißen Seite am Tablet unsichtbar), Farbe der Streifen neben der Seite am Zweitbildschirm (Platzhalter Schwarz), Wortlaut „Letztes Tafelbild“.
- Q-39: Wie sieht das Kaufangebot aus (FR-13)? Offen seit Teilplan 07: Wortlaut (Platzhalter) und Anordnung von Titel, Hinweis, Produktansicht und „Käufe wiederherstellen“.

## Changes

- 2026-11-13: DESIGN.md new — leer angelegt, alle Kategorien offen
- 2026-11-13: Q-19 changed, Q-21 new — Zweitbildschirm (FR-6.2) grenzt Q-19 ein und wirft die Frage nach seinem Ruhezustand auf
- 2026-11-13: Q-21 removed — beantwortet durch FR-11 (Klassenbildschirm)
- 2026-11-13: UI-1 new — App-Icon „Heute“, gewählt aus sechs Entwürfen
- 2026-11-13: UI-1 changed — Produktname „Frontstage“ statt „Pult“; Icon bleibt, Quelldateien umbenannt nach `design/icon/frontstage-app-icon*.svg`
- 2026-11-14: Q-37, Q-38, Q-39 new — Gestaltungslücken aus Teilplan 07 (Klassenbildschirm, Tafel, Kaufangebot), gebaut mit Systemvorgaben; die Prüfung nach `apple-design` steht noch aus
- 2026-11-14: UI-2 new — Runde 0: Referenz Tagesansicht am iPad quer, Modus Operate, gerendert per HTML-Nachbau
- 2026-11-14: UI-3 new — Runde 1: Tagesansicht als Liste und Detail, gewählt aus vier Varianten
- 2026-11-15: UI-4 new — Runde 2: Dichte bleibt beim Ist-Zustand (Zeilen füllen die Höhe), Skala des Detailbereichs festgelegt
