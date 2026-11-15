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

### UI-4 — Die Tagesansicht ist kompakt: Systemdichte mit festen Zeilen

- category: 2
- Constrained by: UI-2, UI-3

**Entscheidung:** Die Liste der Tagesansicht hat feste Zeilen von 44 pt mit 4 pt Abstand; Abstandsskala 4/8 pt.
Je Zeile oben Klasse · Fach mit Stunde und Uhrzeit rechtsbündig daneben, darunter eine Aussage- oder Themenzeile.
Der Detailbereich (UI-3): 16 pt Rand, 16 pt zwischen Abschnitten, 8 pt zwischen Material-Zielen, Material-Ziele
etwa 120 pt hoch. Auch ein Tag mit 8 Stunden belegt nur etwa die halbe Höhe; die Liste scrollt erst bei sehr
vielen Einträgen oder großer Dynamic-Type-Stufe. Gewählt von Andreas am 2026-11-15 (zunächst A, dann geändert
auf B).

**Kontext:** Drei Varianten derselben Liste-und-Detail-Ansicht, je mit 6 und 8 Stunden gerendert (HTML-Nachbau).
Ist-Zustand im Code: Zeilen teilen sich die Höhe, 44–96 pt, 8 pt Abstand (`Frontstage/UI/DayView/DayViewLayout.swift`).

**Verworfen, jeweils mit Vorzug:**
- Ist-Zustand (Zeilen füllen die Höhe, 96 pt bei 6 und etwa 78 pt bei 8 Stunden, Material-Ziele 200 pt) — der Tag
  füllt immer den Schirm, große Zeilen ohne Scrollen.
- Großzügig (Zeilen 112 pt fest, Skala 16/24/32, Material-Ziele 280 pt) — größte Ziele für die Bedienung im
  Stehen; dafür scrollt die Liste schon bei 6 Stunden.

**Konsequenzen mit Kosten:**
- 44 pt ist Apples Mindestgröße für Tippziele; im Stehen auf Armlänge knapp. Die Stundenwahl in der Liste ist
  dadurch das kleinste Ziel; das Material selbst liegt groß im Detailbereich.
- Unter der Liste bleibt an kurzen Tagen viel freie Fläche; was dort steht (nichts, „Material ohne Stunde“ o. a.),
  ist eine Frage der Zustände (Runde 8).
- `DayViewLayout` (Zeilen füllen die Höhe) wird beim Bau ersetzt: feste Zeilenhöhe, Scrollen als Normalfall.
- Die Schriftskala (Runde 4) muss zwei Zeilen in 44 pt tragen (im Nachbau 15/13 pt); der Zeilenaufbau aus dem
  Nachbau ist dafür nur Platzhalter.
- Beschluss am HTML-Nachbau; beim ersten Bau am Gerät bestätigen (UI-2).

**Revisit if:** Am Gerät wird im Stehen die falsche Stunde getroffen, oder zwei Textzeilen passen bei üblicher
Dynamic-Type-Stufe nicht in 44 pt.

*Überholter Wortlaut (2026-11-15, erste Wahl A, am selben Tag geändert):*

> ### UI-4 — Die Zeilen füllen die Höhe: der ganze Tag ohne Scrollen
>
> - category: 2
> - Constrained by: UI-2, UI-3
>
> **Entscheidung:** Die Liste der Tagesansicht bleibt bei der heutigen Dichte: Die Zeilen teilen sich die verfügbare
> Höhe, höchstens 96 pt, mindestens 44 pt, 8 pt Abstand (`Frontstage/UI/DayView/DayViewLayout.swift`); bei 6 Stunden
> 96 pt, bei 8 Stunden etwa 78 pt. Erst wenn selbst 44 pt nicht mehr passen, scrollt die Liste. Für den neuen
> Detailbereich (UI-3) gilt die Skala, die mit dieser Dichte gerendert wurde: 32 pt Rand, 24 pt zwischen
> Abschnitten, 16 pt zwischen Material-Zielen, Material-Ziele etwa 200 pt hoch. Gewählt von Andreas am 2026-11-15.
>
> **Kontext:** Drei Varianten derselben Liste-und-Detail-Ansicht, je mit 6 und 8 Stunden gerendert (HTML-Nachbau).
> Der Nachbau aus Runde 1 hatte 6 statt 8 pt Zeilenabstand; maßgeblich ist der Wert im Code. Die Werte des
> Detailbereichs stammen aus dem Nachbau, weil es ihn im Code noch nicht gibt.
>
> **Verworfen, jeweils mit Vorzug:**
> - Kompakt (Zeilen 44 pt fest, Skala 4/8, Material-Ziele 120 pt) — Systemdichte von iPadOS, auch lange Tage
>   belegen nur die halbe Höhe.
> - Großzügig (Zeilen 112 pt fest, Skala 16/24/32, Material-Ziele 280 pt) — größte Ziele für die Bedienung im
>   Stehen auf Armlänge; dafür scrollt die Liste schon bei 6 Stunden.
>
> **Konsequenzen mit Kosten:**
> - Die Zeilenhöhe ändert sich mit der Zahl der Stunden; ein langer Tag sieht dichter aus als ein kurzer. Die
>   Schriftskala (Runde 4) muss in die kleinste übliche Höhe (etwa 78 pt bei 8 Stunden) passen.
> - Bei großer Dynamic-Type-Stufe oder vielen Stunden fällt die Liste auf Scrollen zurück; der Detailbereich
>   scrollt eigenständig.
> - Beschluss am HTML-Nachbau; beim ersten Bau am Gerät bestätigen (UI-2).
>
> **Revisit if:** Am Gerät sind die Ziele bei 8 Stunden im Stehen zu klein, oder Runde 4 findet keine
> Schriftskala, die in 78 pt drei Zeilen trägt.

---

### UI-5 — Ebenen trennen sich mit Systemmitteln: eine Spaltenlinie, Systemauswahl, getönte Material-Ziele

- category: 3
- Constrained by: UI-2, UI-3, UI-4

**Entscheidung:** Liste und Detailbereich trennt eine Haarlinie (Systemtrenner von `NavigationSplitView`). Die
gewählte Stunde hebt sich durch die Auswahlfläche des Systems ab (`List(selection:)`), Zeilen untereinander und
Abschnitte im Detail nur durch Abstand. Material-Ziele und Aktionen sind getönte Flächen – die Tönung ist eine
System- oder semantische Farbe, nie ein fester Farbwert, damit dunkler Modus und „Kontrast erhöhen“ von selbst
greifen. Keine Schatten auf der Inhaltsebene, kein Liquid Glass auf Zeilen oder Kacheln (Glas nur auf der
Funktionsebene: Tab-Leiste, Werkzeugleiste, Sheets). Gewählt von Andreas am 2026-11-15, nachdem er nach der
Empfehlung der Apple-Richtlinien gefragt hatte.

**Kontext:** Fünf Varianten im kompakten Rahmen (UI-4), je hell und dunkel gerendert (HTML-Nachbau). Gutachten
mit dem Skill `apple-design` (HIG-Seiten liquid-glass, materials, sidebars, split-views, lists-and-tables, color,
dark-mode, layout, accessibility): Glas gehört auf die Funktionsebene, Inhalt nutzt Standard-Materialien und
Systemhintergründe; im dunklen Modus trennt das System über Grund- und erhöhte Farben, nicht über Schatten; die
Auswahl in geteilten Ansichten bleibt in jedem Bereich sichtbar. A entspricht dem, was SwiftUI ohne eigenen Code
liefert.

**Verworfen, jeweils mit Vorzug:**
- Linien überall, umrandete Ziele, Auswahl als Akzentbalken — klarste Struktur, wirkt wie ein Werkzeug; der
  Balken ist aber eine eigene Auswahlform statt der des Systems.
- Flächen (gruppierter Grund, Zeilen als Zellen, Detail als Karte) — ruhig und deutlich in beiden Modi; die
  gruppierten Farben sind für gruppierte Listen gedacht, nicht für Liste und Detail.
- Schatten auf Weiß — plastisch und hell; im dunklen Modus verschwinden die Schatten mitsamt der Auswahl, und
  es entsteht eine zweite Tiefensprache neben Liquid Glass.
- Nur Weißraum — am ruhigsten; die Trefferfläche großer Ziele ist nicht zu sehen, „Kontrast erhöhen“ hat nichts
  zu verstärken.

**Konsequenzen mit Kosten:**
- Kaum eigener Code: Trennung, Auswahl und dunkler Modus kommen vom System. Die Auswahlfarbe folgt dem
  System (grau oder Akzent je nach Fokus) und ist damit nicht frei wählbar.
- Welche System- oder semantische Farbe die Ziele tönt und wie stark, bleibt offen (Runden 5 und 6); Form und
  Radius ebenso (Runde 7).
- Beschluss am HTML-Nachbau; beim ersten Bau am Gerät bestätigen (UI-2), auch mit „Kontrast erhöhen“ und
  „Transparenz reduzieren“.

**Revisit if:** Am Gerät hebt sich im dunklen Modus oder bei „Kontrast erhöhen“ der Detailbereich nicht genug
von der Liste ab, oder die Systemauswahl ist im Stehen nicht auf einen Blick zu sehen.

---

### UI-6 — Hierarchie im Text entsteht nur über die Größe

- category: 4
- Constrained by: UI-2, UI-4, UI-5

**Entscheidung:** Rangfolge im Text zeigt allein die Schriftgröße; alles in normalem Gewicht und in der
Textfarbe, kein Fett, kein Grau als Rangmittel. Gerenderte Skala: Detailtitel 34 pt, Material-Namen 20 pt, Thema
20 pt, Titel in der Liste (Klasse · Fach) 18 pt, Aktionen 15 pt, Stunde, Uhrzeit, Hinweis und Aussagezeilen
13 pt im Detail und 11 pt in der Liste, Dateityp 11 pt. Ausgenommen sind Seitentitel, Tab-Leiste und Werkzeugleiste
(Systemstil). Gewählt von Andreas am 2026-11-15 (Runde 4a; die Schriftfamilie ist offen, Runde 4b).

**Kontext:** Fünf Varianten im kompakten Rahmen (UI-4, UI-5), gesetzt in Inter als Ersatz für SF Pro. Ist-Zustand
im Nachbau: Größe, Gewicht und Grau gemischt (Liste 15/13 pt halbfett/regulär, Detailtitel 28 pt fett); im Code
Systemstile (`.headline`, `.subheadline`, `.title3` in `Frontstage/UI/DayView/DayRowView.swift`).

**Verworfen, jeweils mit Vorzug:**
- Ist-Zustand (gemischt) — vertraut, jede Ebene doppelt markiert.
- Nur Gewicht (fast eine Größe, Titel fett) — ruhige, gleichmäßige Zeilenhöhen, gut für 44 pt.
- Nur Farbe (eine Größe, Abstufung über Grau) — am ruhigsten; im dunklen Modus treten Uhrzeit und Dateityp fast
  ganz zurück.
- Apples Systemtextstile unverändert — wachsen ohne Zutun mit Dynamic Type; füllen die 44-pt-Zeilen aber ohne
  Innenabstand (Widerspruch zu UI-4).

**Konsequenzen mit Kosten:**
- 11 pt ist Apples kleinster Textstil (Caption 2); Uhrzeit und Aussagen in der Liste sind im Stehen auf Armlänge
  knapp lesbar. Die Aussagen (keine Stunde, ohne Material, nicht verfügbar, Ausfall) bleiben über Symbol und Wort
  unterscheidbar, nicht über die Größe.
- Dynamic Type: Jede Größe wird beim Bau an einen Systemstil gekoppelt (`Font.system(size:relativeTo:)` bzw.
  `@ScaledMetric`), damit sie mit „Größerer Text“ mitwächst; bei großen Stufen fällt die Liste auf Scrollen zurück
  (UI-4).
- Ohne Grau und Fett tragen allein die Größensprünge; Material-Namen und Thema (beide 20 pt) stehen gleichrangig.
- Beschluss am Nachbau in Inter; Laufweite und Umbrüche in SF Pro weichen ab – am Gerät bestätigen (UI-2).

**Revisit if:** Am Gerät sind die 11-pt-Angaben im Stehen nicht lesbar, oder bei „Größerer Text“ passen die
Listenzeilen nicht mehr.

---

### UI-7 — Die Schrift ist SF Rounded

- category: 4
- Constrained by: UI-6

**Entscheidung:** Die App setzt ihren Inhalt in SF Rounded, der abgerundeten Variante der Systemschrift
(SwiftUI: `.fontDesign(.rounded)` an der Wurzel der Inhaltsansichten). Größen und Hierarchie folgen UI-6. Uhrzeiten
mit Tabellenziffern (`.monospacedDigit()`). Gewählt von Andreas am 2026-11-15 ohne gerenderten Vergleich (Runde 4b).

**Kontext:** Zur Wahl standen SF Pro (Systemstandard), SF Rounded und New York (Serife) für Überschriften. SF
Rounded lässt sich unter Windows nicht rendern; Andreas hat ohne Vergleichsbild entschieden.

**Verworfen, jeweils mit Vorzug:**
- SF Pro — Apples Standard für Werkzeug-Apps, am neutralsten, keine Abweichung vom System.
- New York für Überschriften — eigene, ruhige Stimme in Titeln, Inhalt bleibt in SF Pro.

**Konsequenzen mit Kosten:**
- Freundlicher, weicher Ton; die App hebt sich von reinen Systemlisten ab. Das passt zur Zielgruppe Schule, kann
  aber verspielt wirken.
- Tab-Leiste, Werkzeugleiste, Menüs und Systemdialoge bleiben in SF Pro (Systembestandteile); zwei Schriftformen
  stehen also nebeneinander.
- Bei 11 pt (UI-6) sind die abgerundeten Formen etwas weniger scharf als SF Pro – am Gerät mitprüfen.
- Kein gerenderter Vergleich: Eindruck am Gerät bestätigen (UI-2).

**Revisit if:** Am Gerät wirkt die Schrift im Unterricht zu verspielt oder die 11-pt-Angaben werden unscharf.

---

### UI-8 — Die Grundtöne sind warm: Elfenbein hell, Braunschwarz dunkel

- category: 5
- Constrained by: UI-5, UI-6

**Entscheidung:** Alle neutralen Töne sind warm gestimmt.

| Rolle | hell | dunkel |
|---|---|---|
| Hintergrund | `#FBF8F2` (Elfenbein) | `#17130E` (Braunschwarz) |
| Auswahlfläche / zweite Fläche | `#ECE5D8` | `#2F2921` |
| Text | `#1F1A14` | `#F5EFE5` |
| Haarlinie | `rgba(92,72,48,.22)` | `rgba(125,108,86,.55)` |

Gewählt von Andreas am 2026-11-15 aus vier Varianten, je hell und dunkel gerendert (HTML-Nachbau, Schrift M PLUS
Rounded als Ersatz für SF Rounded).

**Kontext:** Ist-Zustand sind die Systemfarben von iOS (Weiß/`#F2F2F7`/`#E5E5EA`, dunkel Schwarz/`#1C1C1E`/`#2C2C2E`).
Gemessene Kontraste: Text auf Hintergrund 16,3:1 hell und 16,2:1 dunkel, Text auf Auswahlfläche 13,8:1 und 12,6:1
(Ziel ≥ 7:1, kleine Angaben ≥ 4,5:1).

**Verworfen, jeweils mit Vorzug:**
- Systemgrau (Ist-Zustand) — passt sich ohne Zutun an hell, dunkel und „Kontrast erhöhen“ an; höchster Kontrast.
- Kühles Blaugrau — sachlich, technisch klar.
- Petrol-getönt — leiser Bezug zum App-Icon (UI-1).

**Konsequenzen mit Kosten:**
- Eigene Farben statt Systemfarben: Beim Bau entsteht je Rolle eine Farbe im Asset-Katalog mit Fassungen für hell,
  dunkel und hohen Kontrast; was das System sonst liefert (Hintergrund, Auswahlfläche, Trenner), wird darauf
  umgestellt. UI-5 gilt in der Struktur weiter (eine Spaltenlinie, Auswahlfläche, keine Schatten), aber in diesen
  Farben statt in Systemgrau. Die Auswahlfläche von `List(selection:)` lässt sich nur über eigene Zeilenhintergründe
  färben; die Systemhervorhebung bei Tastaturfokus am Mac bleibt Akzentfarbe.
- Glas-Leisten (Tab-Leiste, Werkzeugleiste) bleiben Systemmaterial und nehmen den warmen Grund durch ihre
  Transparenz auf; sie werden nicht eingefärbt.
- Halbtransparente Tönungen (Material-Ziele) nehmen den warmen Grund an und wirken leicht grünlich-blau; die
  Tönung wird in Runde 6 mit dem Akzent festgelegt.
- Beschluss am Nachbau; Farbwirkung auf dem iPad-Display (True Tone) am Gerät bestätigen (UI-2).

**Revisit if:** Am Gerät wirkt der Grund mit True Tone vergilbt, oder „Kontrast erhöhen“ reicht mit den eigenen
Farben nicht.

*Geändert 2026-11-15:* Mit FR-16 ist der Grundton einstellbar. UI-8 beschreibt den **Standard-Grundton**. Die
verworfenen Varianten werden zu wählbaren Grundtönen mit denselben Rollen:

| Grundton | Hintergrund hell / dunkel | Auswahlfläche hell / dunkel | Text hell / dunkel | Haarlinie hell / dunkel |
|---|---|---|---|---|
| System | Systemfarben (`systemBackground` u. a.) | Systemfarben | Systemfarben | Systemtrenner |
| kühl | `#F7F9FC` / `#0B1120` | `#E2E8F0` / `#1E293B` | `#0F172A` / `#EEF2F7` | `rgba(51,65,85,.20)` / `rgba(71,85,105,.60)` |
| Petrol | `#F6F9F9` / `#061416` | `#DFE9EA` / `#15292C` | `#0C1F23` / `#ECF4F4` | `rgba(14,75,87,.18)` / `rgba(60,100,106,.55)` |

Kosten: vier Farbsätze statt einem, je mit hoher Kontrastfassung; jede Gestaltungsprüfung läuft gegen alle vier.

---

### UI-9 — Standard-Akzent ist Petrol; Kacheln sind deckend getönt

- category: 6
- Constrained by: UI-1, UI-5, UI-8, FR-16.1

**Entscheidung:** Die Standard-Akzentfarbe auf dem warmen Grund ist Petrol: `#0E6B7A` hell, `#5FC2CF` dunkel. Sie gilt
für Material-Ziele (Text, Symbol), Aktionen, gewählten Reiter und Werkzeugleiste. Die Tönung der Material-Ziele
und Aktionen ist **deckend** berechnet, nicht halbtransparent: Akzent zu 14 % (hell) bzw. 22 % (dunkel) über dem
Grund – beim Standard `#DAE4E1` hell und `#273A38` dunkel. Text auf der Tönung erreicht 4,76:1 hell und 5,81:1
dunkel, der Akzent auf dem Grund 5,82:1 und 8,90:1; der Kontrastschutz (FR-16.1) muss den Standard in keinem Modus
korrigieren. Gewählt von Andreas am 2026-11-15 aus vier Varianten, hell und dunkel, mit Signalblatt.

**Signalfarben (fest, nicht wählbar, FR-16.1):** Entfällt Rot `#FF3B30` / `#FF453A`; Material nicht verfügbar
Orange `#FF9500` / `#FF9F0A`; Vertretung ohne eigene Farbe (Textfarbe mit Symbol); „jetzt, gezeigt“ Gelb
`#FFC94A` aus dem Icon (UI-1). Rot und Orange erreichen als kleiner Text auf hellem warmem Grund nur 3,35:1 bzw.
2,07:1 – offen als Q-41. Wo und wie „jetzt, gezeigt“ erscheint, ist nicht entschieden (Runde 8).

**Kontext:** Ist-Zustand war Systemblau `#0088FF`. Gerendert im Rahmen UI-3 bis UI-8 (HTML-Nachbau, M PLUS Rounded
als Ersatz für SF Rounded).

**Verworfen, jeweils mit Vorzug:**
- Systemblau (Ist-Zustand) — vertraut aus allen Apple-Apps; braucht auf warmem Grund in beiden Modi eine Korrektur,
  „Heute“ in der Werkzeugleiste ist hell zu schwach (3,32:1).
- Terrakotta — am wärmsten, passt zum Grund; liegt nah an Rot und Orange, „Ausfall markieren“ stand neben dem roten
  „Entfällt“.
- Waldgrün — deutlich von allen Signalen abgesetzt; hell leicht abzudunkeln.

**Konsequenzen mit Kosten:**
- Icon und Oberfläche teilen jetzt die Farbfamilie Petrol. Das Gelb bleibt der Bedeutung „jetzt, gezeigt“
  vorbehalten.
- Mit FR-16.1 rechnet die App für jeden gewählten Akzent Tönung und Schriftton nach derselben Regel (deckende
  Tönung 14 %/22 %, Helligkeit verschieben bis 4,5:1). Ein Akzent kann damit in einem Modus zwei Töne haben.
- Die Systemhervorhebung bei Tastaturfokus am Mac und Systemsteuerelemente übernehmen den Akzent nur, wenn er als
  `tint` bzw. `AccentColor` gesetzt wird; das ist beim Bau zu prüfen.
- Beschluss am Nachbau; Farbwirkung am Gerät bestätigen (UI-2).

**Revisit if:** Am Gerät wirkt Petrol auf dem warmen Grund trüb, oder Lehrkräfte verwechseln getönte Material-Ziele
mit nicht bedienbaren Flächen.

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
- Q-41: Rot („Entfällt“) und Orange („Material nicht verfügbar“) erreichen als kleiner Text auf dem hellen warmen Grund nur 3,35:1 bzw. 2,07:1 (Ziel 4,5:1). Dunklere Signaltöne für hell (z. B. Rot `#C4271D`, Orange `#B25C00`), Signal nur im Symbol und Text in Textfarbe, oder Signal als getönte Fläche? Gehört zu Runde 8 (Zustände). Gefunden in Runde 6.

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
- 2026-11-15: UI-4 changed — Andreas wählt doch die kompakte Dichte (B) statt des Ist-Zustands (A)
- 2026-11-15: UI-5 new — Runde 3: Trennung der Ebenen mit Systemmitteln (Spaltenlinie, Systemauswahl, getönte Ziele in Systemfarbe), nach HIG-Gutachten
- 2026-11-15: UI-6 new — Runde 4a: Hierarchie im Text nur über die Größe
- 2026-11-15: UI-7 new — Runde 4b: Schrift SF Rounded (ohne gerenderten Vergleich)
- 2026-11-15: UI-8 new — Runde 5: warme Grundtöne (Elfenbein/Braunschwarz); UI-5 gilt in der Struktur, Farben eigene statt Systemgrau
- 2026-11-15: UI-8 changed — warmer Grundton ist der Standard; System, kühl und Petrol werden wählbare Grundtöne (FR-16)
- 2026-11-15: UI-9 new — Runde 6: Standard-Akzent Petrol, deckende Tönung, Signalfarben festgehalten; Q-41 new — Kontrast der Signalfarben auf hellem Grund
