---
status: draft
date: 2026-11-20
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

### UI-10 — Formen bleiben beim Ist-Zustand: Kacheln 16, Auswahl 10, Knöpfe als Kapsel

- category: 7
- Constrained by: UI-5, UI-9

**Entscheidung:** Material-Ziele haben 16 pt Eckenradius, die Auswahlfläche in der Liste 10 pt, Aktionsknöpfe sind
Kapseln. Keine Rahmen (Linienstärke 0), keine Schatten (UI-5). Ecken sind kontinuierlich (SwiftUI-Standard von
`RoundedRectangle`, `style: .continuous`). Tab-Leiste und Werkzeugleiste bleiben Systemform. Gewählt von Andreas am
2026-11-15 aus vier Varianten, hell und dunkel.

**Kontext:** Der Nachbau seit Runde 1 nutzte diese Radien; im Code gibt es noch keine Material-Kacheln (heute
`.bordered`-Knöpfe in `DayRowView.swift`). Der Nachbau zeigte A mit gewöhnlich runden Ecken, die anderen mit
kontinuierlichen – in der App sind sie kontinuierlich.

**Verworfen, jeweils mit Vorzug:**
- Eckig (Kacheln 6, Auswahl 4, Knöpfe fast rechteckig) — sachlich, werkzeughaft, größte nutzbare Fläche; steht
  gegen die runden Systemleisten und SF Rounded.
- Konzentrisch (Kacheln 24, Auswahl 12) — Apples Ansatz in iOS 26, Radien aus der umgebenden Form; ohne sichtbare
  Container (UI-5) bleibt die Bezugsform gedacht.
- Kapsel (Kacheln 32, alles kapselförmig) — am weichsten, passt am stärksten zu SF Rounded.

**Konsequenzen mit Kosten:**
- Drei Radien für drei Rollen; neue Elemente wählen einen davon statt eines eigenen Werts.
- Beschluss am Nachbau; am Gerät bestätigen (UI-2).

**Revisit if:** Neben den runden Glas-Leisten von iOS 26 wirken die 16-pt-Kacheln am Gerät zu kantig.

---

### UI-11 — Aussagen tragen ihre Signalfarbe nur im Symbol; das Wort steht in Textfarbe

- category: 8
- Constrained by: UI-6, UI-8, UI-9

**Entscheidung:** Jede Aussage einer Unterrichtsstunde ist Symbol plus Wort. Das Wort steht immer in Textfarbe; die
Signalfarbe trägt allein das Symbol, verschoben auf mindestens 3:1 gegen die ungünstigste Fläche (Grund,
Auswahlfläche, Kachel-Tönung):

| Aussage | Symbol hell | Symbol dunkel | Wort |
|---|---|---|---|
| Entfällt (zusätzlich durchgestrichen) | Rot `#ED372D` | Rot `#FF453A` | Textfarbe |
| Material nicht verfügbar | Orange `#B86B00` | Orange `#FF9F0A` | Textfarbe |
| Vertretung | Textfarbe | Textfarbe | Textfarbe |
| Ohne Material | Textfarbe | Textfarbe | Textfarbe |
| Keine Stunde | ohne Symbol, als Titel | ohne Symbol | Textfarbe |

Gemessen: Wort 16,3/13,8/13,3:1 hell und 16,2/12,6/10,5:1 dunkel (Grund/Auswahl/Kachel); Symbole hell ≥ 3,12:1,
dunkel ≥ 3,53:1. Material, das nicht verfügbar ist, bleibt eine antippbare Kachel in Akzent-Tönung; statt des
Dateityps steht darin die Aussage mit orangem Symbol. Im Detail steht unter dem Titel eine Aussagezeile.

Andreas hat die Wahl am 2026-11-15 delegiert („mache es nach best practice!“); entschieden nach Apples Richtlinie,
Information nie allein über Farbe zu tragen, nach WCAG (Text 4,5:1, Grafik 3:1) und nach der Lesbarkeit der
11-pt-Aussagen (UI-6).

**Kontext:** Ist-Zustand war Symbol und Wort in Systemrot/-orange (UI-9); hell 3,35:1 bzw. 2,07:1, dunkel Rot auf
Auswahl und Kachel unter 4,5:1 (Q-41). Vier Varianten an zwei Bildschirmen (2. und 6. Stunde gewählt), hell und
dunkel.

**Verworfen, jeweils mit Vorzug:**
- Systemrot/-orange für Symbol und Wort (Ist-Zustand) — stärkstes Signal, vertraut; als kleiner Text nicht lesbar.
- Symbol und Wort in abgedunkelten Signaltönen (Rot `#BA2B23`, Orange `#915500`, dunkel aufgehellt) — Signal im
  ganzen Ausdruck, überall ≥ 4,5:1; Wort aber nur etwa 4,7:1 statt 13:1, und mehr Farbe in der dichten Liste.
  Nächstbeste Wahl.
- Getönte Plakette — deutlich abgegrenzt; die Pille verschwindet auf der Auswahlfläche (Vertretung 1,01:1) und
  dunkel auf der Kachel.

**Konsequenzen mit Kosten:**
- Das Signal ist leiser: Auf einen Blick fällt nur das farbige Symbol auf. „Entfällt“ trägt zusätzlich die
  Durchstreichung.
- Signalsymbole brauchen je Grundton (FR-16) eine eigene Verschiebung auf 3:1; dieselbe Regel wie beim Akzent.
- SF-Symbole werden einfarbig in der Signalfarbe gesetzt (`foregroundStyle`), der Text getrennt in Textfarbe – nicht
  als ein `Label` mit einer gemeinsamen Farbe.
- Beschluss am Nachbau; am Gerät bestätigen (UI-2).

**Revisit if:** Am Gerät wird ein Ausfall oder fehlendes Material im Unterricht übersehen.

---

### UI-12 — „Jetzt“ und „Am Smartboard“: zwei gelbe Kapseln auf zwei Objekten

- category: 8
- Constrained by: UI-1, UI-3, UI-6, UI-11

**Entscheidung:** Die laufende Unterrichtsstunde trägt in ihrer Listenzeile eine kleine gelbe Kapsel „Jetzt“ (am
Ende der zweiten Zeile); das Material, das gerade auf dem Zweitbildschirm steht, trägt auf seiner Kachel oben eine
gelbe Kapsel „Am Smartboard“. Kapselfläche Gelb `#FFC94A` (UI-1, Bedeutung „jetzt, gezeigt“), Wort und Symbol in
fester dunkler Farbe `#1F1A14` in **beiden** Modi (etwa 11:1); Gelb nie als große Fläche. VoiceOver: die Zeile
liest „läuft jetzt“ mit, die Kachel meldet „am Smartboard“ als Wert; ein Wechsel des gezeigten Materials wird
angesagt. Andreas hat am 2026-11-15 alle weiteren Gestaltungsentscheidungen delegiert („ich will keine fragen mehr beantworten. mach es wie du es für richtig hälst“); entschieden nach Apples Richtlinien (Gutachten mit dem Skill `apple-design`), ohne gerenderte Vergleichsrunde.

**Kontext:** Die laufende Stunde ist meist automatisch gewählt (UI-3) und kann gerade Material, die Tafel oder
nichts zeigen (FR-6.2, FR-11, FR-11.5) – „jetzt“ (Stunde) und „gezeigt“ (Material) sind zwei Aussagen über zwei
Dinge. Ausnahme zu UI-11 (Wort in Textfarbe, keine Plakette): Gelb ist keine Signalfarbe für einen Mangel, sondern
eine Markierung mit eigenem, festem Wortfarbenpaar.

**Verworfen, jeweils mit Vorzug:**
- Ein gemeinsamer Marker an der Zeile — weniger Elemente; verschweigt, welches Material die Klasse sieht.
- Zeile gelb tönen — am auffälligsten; kollidiert mit der Auswahlfläche der meist gewählten laufenden Stunde.
- Nur ein gelbes Symbol — leise; 1,4:1 gegen den warmen Grund.
- Farbiger Balken am Zeilenanfang — knapp; Farbe als alleiniger Träger.

**Konsequenzen mit Kosten:**
- Neues Wort „Am Smartboard“ in `Localizable.xcstrings`; „Jetzt“ ebenso.
- Gelb erscheint auch bei frei gewähltem Akzent (FR-16.1) unverändert; ein gelber Akzent kollidiert damit (Q-40).
- Am Gerät bestätigen (UI-2).

**Revisit if:** Am Gerät übersieht die Lehrkraft, welches Material gerade gezeigt wird, oder die Kapsel stört in
der 44-pt-Zeile.

---

### UI-13 — Freie Fläche bleibt leer; Tageszustände als ruhige Aussage im Detailbereich

- category: 8
- Constrained by: UI-3, UI-4, UI-11

**Entscheidung:**
- Unter der kompakten Liste steht nichts, außer es gibt „Material ohne Stunde“ (FR-7) – dann steht dieser Abschnitt
  direkt unter der Liste.
- Tag ohne Unterrichtsstunde, unterrichtsfreier Tag (mit Namen, z. B. „Herbstferien“) und Fehler ohne jeden Stand:
  `ContentUnavailableView` im Detailbereich, je mit eigenem Symbol und Titel; der Fehler mit der Taste „Erneut
  abfragen“.
- Laden und Aktualisieren: Der letzte Stand bleibt sichtbar; ein kleiner Fortschrittsanzeiger in der Statusleiste
  der Quelle (`SourceStatusBar`), nie ein Vollbild-Ladezustand.
- Fehler der Quelle bei vorhandenem Stand: Symbol und Wort in der Statusleiste, kein Dialog.

Andreas hat am 2026-11-15 alle weiteren Gestaltungsentscheidungen delegiert („ich will keine fragen mehr beantworten. mach es wie du es für richtig hälst“); entschieden nach Apples Richtlinien (Gutachten mit dem Skill `apple-design`), ohne gerenderte Vergleichsrunde.

**Kontext:** Die kompakte Dichte (UI-4) lässt an kurzen Tagen viel Fläche frei. Apples Richtlinien: so früh wie
möglich etwas zeigen, Status in die Oberfläche integrieren statt Dialoge, leere Bildschirme mit klarem nächstem
Schritt.

**Verworfen, jeweils mit Vorzug:**
- Tageszusammenfassung in der freien Fläche (Zahl der Stunden, Leistungsnachweise) — nutzt den Platz; ist eine
  daneben gepflegte Zahl und Lärm beim kurzen Blick.
- Nächster Tag als Vorschau darunter — vorausschauend; vermischt zwei Tage in einer Liste.
- Ladezustand als Vollbild — eindeutig; versteckt den letzten gültigen Stand.

**Konsequenzen mit Kosten:**
- An kurzen Tagen wirkt die Liste unten leer; das ist gewollt.
- Am Gerät bestätigen (UI-2).

**Revisit if:** Lehrkräfte vermissen am Gerät einen Überblick über den Tag.

---

### UI-14 — Bewegung nur, wo sie erklärt: Systemauswahl, kurze Überblendung, nichts blinkt

- category: 9
- Constrained by: UI-3, UI-11, UI-12

**Entscheidung:**
- Auswahlwechsel in der Liste: Systemverhalten, keine eigene Animation.
- Wechsel des Detailbereichs: Überblendung, höchstens etwa 0,2 s (`.smooth`).
- Druck auf Kacheln und Knöpfe: Hervorhebung des Systemstils, kein eigenes Skalieren.
- Material öffnen: System-Vollbilddarstellung; Zoom-Übergang erlaubt, bei „Bewegung reduzieren“ Überblendung.
- Wechsel der gelben Kapseln (UI-12): Überblendung etwa 0,15 s (`.snappy`), am iPad mit leichtem haptischem Tick.
- Nie bewegt: Pulsieren oder Blinken (auch nicht „Jetzt“), Änderung von Zeilenhöhen, automatisches Scrollen,
  während die Lehrkraft die Liste hält, Sekunden- oder Minutentakt der Uhrzeit.
- „Bewegung reduzieren“: Zoom und Skalieren entfallen, Überblendungen bleiben. Keine Bedeutung hängt an Bewegung.

Andreas hat am 2026-11-15 alle weiteren Gestaltungsentscheidungen delegiert („ich will keine fragen mehr beantworten. mach es wie du es für richtig hälst“); entschieden nach Apples Richtlinien (Gutachten mit dem Skill `apple-design`), ohne gerenderte Vergleichsrunde.

**Kontext:** Apples Richtlinien nennen keine Dauern; sie verlangen sparsame Bewegung bei häufigen Handlungen,
Ergänzung durch Haptik und Rücksicht auf „Bewegung reduzieren“. Die Tagesansicht wird im Unterricht oft und
schnell bedient.

**Verworfen, jeweils mit Vorzug:**
- Federnde Übergänge beim Stundenwechsel — lebendig; lenkt beim kurzen Blick ab.
- Pulsierender „Jetzt“-Marker — fällt sofort auf; Blinken verbietet die Barrierefreiheit, und es lenkt die Klasse
  bei Bildschirmspiegelung ab.

**Konsequenzen mit Kosten:**
- Die App wirkt ruhig, fast statisch.
- Am Gerät bestätigen (UI-2).

**Revisit if:** Am Gerät fühlen sich Wechsel abrupt an.

---

### UI-15 — Sprache: du, Verb zuerst, Systemformate, Dateinamen in der Mitte gekürzt

- category: 10
- Constrained by: UI-6, UI-11

**Entscheidung:**
- Anrede „du“ im Imperativ, wie die vorhandenen Texte („Gib ihn unter Einrichten frei“). Kein „wir“, kein „Ups“,
  keine Schuldzuweisung.
- Fehlertexte: Ursache, Folge, nächster Schritt („Keine Verbindung. Der letzte Stand bleibt erhalten.“).
- Tasten: Verb zuerst, kurz („Erneut abfragen“, „Zuordnen“, „Ausfall markieren“).
- Aussagen an der Stunde als Zustand: „Entfällt“, „Vertretung“, „Ohne Material“, „Material nicht verfügbar“,
  „Keine Stunde“. Im PRD und Glossar bleibt der Begriff „Ausfall“.
- Uhrzeiten und Daten nur über die Systemformate (`Date.FormatStyle`, Intervallstil), damit 12/24 Stunden und
  Sprache des Geräts gelten; Uhrzeiten mit Tabellenziffern. Kein handformatiertes `"%d:%02d"`.
- Lange Dateinamen werden in der Mitte gekürzt (`.truncationMode(.middle)`), Endung bleibt sichtbar; im Detail
  bis zu zwei Zeilen.

Andreas hat am 2026-11-15 alle weiteren Gestaltungsentscheidungen delegiert („ich will keine fragen mehr beantworten. mach es wie du es für richtig hälst“); entschieden nach Apples Richtlinien (Gutachten mit dem Skill `apple-design`), ohne gerenderte Vergleichsrunde.

**Kontext:** Die vorhandenen Texte in `Frontstage/Resources/Localizable.xcstrings` duzen bereits. Die Tagesansicht
formatiert Uhrzeiten heute von Hand (`PeriodHeader` in `Frontstage/UI/DayView/DayRowView.swift`).

**Verworfen, jeweils mit Vorzug:**
- „Sie“ — förmlich, in Schulverwaltung üblich; bricht mit allen vorhandenen Texten.
- Feste Schreibweise „8:45“ von Hand — kompakt; ignoriert die Einstellungen des Geräts.
- Kürzen am Ende — Anfang bleibt lesbar; die Endung (pdf, pptx) geht verloren.

**Konsequenzen mit Kosten:**
- `PeriodHeader` und andere handformatierte Zeiten werden beim Bau umgestellt; die Darstellung kann „08:45“
  lauten (deutsches Systemformat).
- Am Gerät bestätigen (UI-2).

**Revisit if:** Testerinnen empfinden „du“ als unpassend.

---

### UI-16 — Stundenplan-Editor: Raster links, fester Bearbeitungsbereich rechts, kein Blatt

- category: 1
- Constrained by: UI-2, UI-3, FR-1.3

**Entscheidung:** „Einrichten › Stundenplan“ zeigt links das Raster Wochentag × Stunde und rechts dauerhaft einen
Bearbeitungsbereich für das gewählte Feld: Überschrift „Montag, 4. Stunde“ mit Uhrzeit, Klasse und Fach mit
Vorschlägen, Wochentag, Stunde, bei A/B „gilt für“, „Sichern und nächste“, beim Ändern „Auf andere Tage übernehmen“
und „Stunde löschen“. Ein Tipp ins Raster wählt das Feld; „Sichern und nächste“ bewegt die Auswahl sichtbar zum
nächsten freien Feld. Gewählt von Andreas am 2026-11-20 aus vier Varianten (HTML-Nachbau in iPad-Querformatbreite,
gleicher Moment in allen: Mo 4. Stunde wird 9c Deutsch, im Rahmen UI-7 bis UI-10).

**Kontext:** Ist-Zustand war das Raster mit `.bordered`-Knöpfen in einer `List` und ein Blatt je Stunde
(`Frontstage/UI/Setup/TimetableEditorView.swift`, `TimetableEntrySheet.swift`); das Blatt verdeckt das Raster, so dass
man beim Eintragen am Stück nicht sieht, wo man steht. Seit ADR-0016 ist der Editor der einzige Weg zum Stundenplan.

**Verworfen, jeweils mit Vorzug:**
- A, Ist-Zustand (Raster, Eingabe im Blatt) — volle Breite fürs Raster, vertraute Systemform, schon gebaut.
- B, Liste je Tag mit Blatt — Uhrzeit an jeder Stunde, funktioniert auch schmal ohne Umbau.
- C, Raster mit Stundenpalette (Paar wählen, Felder antippen) — am schnellsten bei vielen gleichen Stunden, kaum
  Formular.

**Konsequenzen mit Kosten:**
- Das Raster verliert rund 360 pt Breite; Zellen werden schmaler, lange Fächer werden gekürzt.
- Bei schmaler Breite (iPad hochkant, Split View) ist kein Platz für zwei Spalten. Umsetzung mit dem
  System-Inspector (`.inspector`, iPadOS 17+/macOS 14+): Er zeigt den Bereich bei voller Breite als Spalte und bei
  schmaler Breite von selbst als Blatt – ein Weg, kein zweiter Entwurf.
- `TimetableEntrySheet` wird zum Bereichsinhalt; die Logik (`TimetableEditorViewModel`, FR-1.3) bleibt.
- Ohne Auswahl braucht der Bereich einen ruhigen Zustand (UI-13), etwa „Tippe ein Feld an“; Wortlaut nach UI-15.
- Am Gerät bestätigen (UI-2).

**Revisit if:** Am Gerät zeigt sich, dass das Raster mit Bereich zu eng wird, oder die Eingabe am Stück trotzdem
langsam bleibt (dann C als Ergänzung prüfen).

### UI-17 — Lösung als zweite Spalte der Anzeige, nur am Tablet

- category: 1
- Constrained by: UI-2, UI-5, UI-13, FR-6.3

**Entscheidung:** Hat das Material eine Lösung, teilt sich die Anzeige: links das Blatt mit Stift, rechts die Lösung nur
lesend, je halbe Breite, getrennt durch die Spaltenlinie des Systems (UI-5); bei schmaler Breite übereinander, Blatt
oben. Die Lösungsspalte trägt eine schlichte Kopfzeile: „Lösung“, „Seite 2 von 3“ mit eigenen Pfeilen, Schalter
„Seiten koppeln“ (`link`) und „Ausblenden“. Ein Knopf „Lösung“ (`sidebar.right`) in der Leiste blendet die Spalte ein und
aus. Die Kachel nennt im Fuß „· mit Lösung“. Bei erkannter Spiegelung zeigt die Spalte statt der Lösung eine ruhige
Aussage (UI-13) mit „Trotzdem zeigen“. Nach best practice entschieden, von Andreas delegiert (2026-11-22).

**Kontext:** Ist-Zustand: Die Anzeige (`Frontstage/Viewer/ViewerView.swift`) zeigt ein Dokument über die volle Breite,
darunter die Smartboard-Leiste. Apples HIG zu Split Views: Nebeneinander, wenn beide Inhalte gleichzeitig gebraucht
werden; die Lehrkraft vergleicht Blatt und Lösung Zeile für Zeile, daher gleiche Breite statt schmaler Seitenleiste.

**Verworfen, jeweils mit Vorzug:**
- Lösung als Inspector (schmale Spalte rechts, `.inspector`) — Systembaustein, bei schmaler Breite von selbst ein Blatt;
  aber zu schmal, um eine A4-Seite lesbar zu zeigen, und als Blatt verdeckt er das Blatt.
- Lösung als schwebendes Bild-im-Bild über dem Blatt — spart Platz; verdeckt aber Teile des Blatts, auf die man schreibt.
- Umschalten zwischen Blatt und Lösung (Segment) — volle Größe für beide; aber nie gleichzeitig, und genau das ist der Wunsch.

**Konsequenzen mit Kosten:**
- Das Blatt hat am Tablet nur halbe Breite, solange die Lösung offen ist; Schreiben wird kleiner. Abhilfe: ausblenden.
- Hochkant werden beide Seiten klein; übereinander ist dort trotzdem besser lesbar als nebeneinander.
- Am Gerät bestätigen (UI-2).

**Revisit if:** Am Gerät zeigt sich, dass halbe Breite zum Schreiben nicht reicht (dann verschiebbare Trennlinie oder
schmalere Lösung prüfen).

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

- Q-19: Die Tagesansicht ist während des Unterrichts per Bildschirmspiegelung für die Klasse sichtbar. Was darf dort stehen, was nicht (z. B. Material anderer Klassen, Lösungen, Namen von Dateien wie „KA 1 9b“)? — eingegrenzt 2026-11-13 durch FR-6.2: Mit Zweitbildschirm sieht die Klasse die Tagesansicht nicht. Offen bleibt die Frage für reine Bildschirmspiegelung (z. B. beim Wechsel zu einer anderen App, RISK-5). Ergänzt 2026-11-22: Für die Lösung (FR-6.3) beantwortet – bei erkannter Spiegelung ausgeblendet, mit Warnung und „Trotzdem zeigen“ (UI-17).
- ~~Q-21~~: Was zeigt der Zweitbildschirm, solange kein Material geöffnet ist (FR-6.2) – eine leere Fläche, Klasse und Fach der laufenden Unterrichtsstunde, die Uhrzeit, etwas anderes? → answered 2026-11-13: den Klassenbildschirm mit Klasse, Fach, Uhrzeit, Stundenende, Thema, Hinweis, Timer und Arbeitsform (FR-11, FR-11.1 bis FR-11.3). Wie er aussieht, ist wie jede Kategorie hier offen.
- Q-37: Wie zeigt sich der Klassenbildschirm auf Distanz (FR-11 bis FR-11.3)? Offen seit Teilplan 07, gebaut mit Systemvorgaben: Schriftgrößen (Systemstile, aus dem Klassenraum vermutlich zu klein), Farben, Symbole der Arbeitsform (`person`, `person.2`, `person.3`), Material der Timer-Karte, Timer-Signal (Platzhalter Sinus 880 Hz, dreimal), Wortlaut.
- Q-38: Wie sieht die Tafel aus (FR-12 bis FR-12.7)? Offen seit Teilplan 07, gebaut mit Systemvorgaben: Breite (220 pt) und Reihenfolge der Seitenleiste, Seitenvorschauen statt Nummern, Farbe und Abstand der Linien und Karos, Farbe der Abdeckung (Platzhalter Schwarz; die Systemhintergrundfarbe wäre auf der weißen Seite am Tablet unsichtbar), Farbe der Streifen neben der Seite am Zweitbildschirm (Platzhalter Schwarz), Wortlaut „Letztes Tafelbild“.
- Q-39: Wie sieht das Kaufangebot aus (FR-13)? Offen seit Teilplan 07: Wortlaut (Platzhalter) und Anordnung von Titel, Hinweis, Produktansicht und „Käufe wiederherstellen“.
- ~~Q-41~~: Rot („Entfällt“) und Orange („Material nicht verfügbar“) erreichen als kleiner Text auf dem hellen warmen Grund nur 3,35:1 bzw. 2,07:1 (Ziel 4,5:1). Dunklere Signaltöne für hell (z. B. Rot `#C4271D`, Orange `#B25C00`), Signal nur im Symbol und Text in Textfarbe, oder Signal als getönte Fläche? Gehört zu Runde 8 (Zustände). Gefunden in Runde 6. → answered 2026-11-15: Signalfarbe nur im Symbol (≥ 3:1), Wort in Textfarbe (UI-11).
- Q-46: Wie sieht die Startseite aus (FR-19)? Sie ist eine neue Oberfläche außerhalb der Referenz aus UI-2 (Web, Modus Persuade statt Operate). Bis zur Antwort: Die Gestaltung entsteht beim Bau (Teilplan 13) mit dem Skill `design-taste-frontend`, von Andreas delegiert; Darstellungen der App folgen UI-6 bis UI-12 (warmer Grundton, Petrol-Akzent, Rundschrift als Ersatz für SF Rounded). Das Ergebnis wird danach hier als Beschluss festgehalten oder in einer Design-Runde bestätigt.
- Q-47: Wie verhält und zeigt sich die Verwaltungsseite (FR-18.1)? Neue Oberfläche außerhalb von UI-2 (Web, datendicht, nur für den Betreiber). Bis zur Antwort: Verhalten nach `design:enterprise-ux-patterns` (Liste mit Filtern, leere/Fehler-Zustände, Löschen mit Rückfrage), Aussehen schlicht nach Systemstandard des Browsers mit den Grundtönen aus UI-8; entschieden beim Bau (Teilplan 12), von Andreas delegiert.

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
- 2026-11-15: UI-10 new — Runde 7: Formen beim Ist-Zustand (Kacheln 16, Auswahl 10, Knöpfe Kapsel)
- 2026-11-15: UI-11 new — Runde 8a: Aussagen mit Signalfarbe nur im Symbol (nach best practice, von Andreas delegiert); Q-41 answered
- 2026-11-15: UI-12, UI-13, UI-14, UI-15 new — Runden 8b, 8c, 9, 10 von Andreas delegiert, nach Apples Richtlinien entschieden (Gutachten apple-design)
- 2026-11-16: Q-46, Q-47 new — Startseite und Verwaltungsseite als neue Oberflächen außerhalb von UI-2 (FR-18.1, FR-19, ADR-0015); Aussehen entsteht beim Bau, keine UI-Beschlüsse jetzt
- 2026-11-20: UI-16 new — Runde 1 für den Stundenplan-Editor: Raster mit festem Bearbeitungsbereich statt Blatt (Andreas aus vier Varianten)
- 2026-11-22: UI-17 new — Lösung als zweite Spalte der Anzeige, nur am Tablet (FR-6.3; nach best practice, von Andreas delegiert); Q-19 ergänzt
