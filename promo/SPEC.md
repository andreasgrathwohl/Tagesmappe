# SPEC — Frontstage, 30 s

GOAL:    Eine Lehrkraft denkt am Ende „das Material liegt schon bei der Stunde, ein Tipp zeigt es an der Wand“.
OUTPUT:  HyperFrames, 1920 x 1080, 30 fps
TIME:    30 s x 30 fps = 900 Frames; keine Musik (keine Quelle), Geräusche auf Handlungen.

LOOK:
- Welten (aus der Startseite `server/landing`):
  - Klassenzimmer: Wand `#E4DCCB` mit Putzrauschen 3 %, Licht von links oben (Verlauf 8 % heller links),
    Smartboard 75" an der Wand: Rahmen `#15191B` 16 px, Radius 6 px, Schatten auf der Wand 0 30px 60px rgba(0,0,0,.28),
    Spiegelung als diagonaler Streifen weiß 5 %.
  - Pult: Eiche, Holzmaserung aus drei `repeating-linear-gradient`, Grundton `#B98A5E`.
  - Petrol-Bühne `#0B3F49`, Tinte `#FBF8F2`, gedämpft `#B9D3D2`.
  - Papier `#F5F7F4`, Tinte `#0D2327`.
- Titel: Bricolage Grotesque 700, 104 px (9,6 % der Höhe), Laufweite −2 %; Zweitzeile 56 px 500.
- App (DESIGN.md UI-3 bis UI-12): Grund `#FBF8F2`, Auswahl `#ECE5D8` Radius 10, Text `#1F1A14`, Akzent `#0E6B7A`,
  Kachel-Tönung `#DAE4E1` Radius 16 ohne Schatten, Haarlinie rgba(92,72,48,.22); Schrift Nunito 400 (Ersatz SF Rounded),
  Größen 34/20/18/13/11; Systemleisten in Inter.
- Gelb `#FFC94A` mit Wort `#1F1A14` nur: Kapsel „Jetzt“, Kapsel „Am Smartboard“, Fläche im Icon.
- Geräte: iPad Air 11" quer, Alu-Kante 3 px (#D5D8DA→#8C9194), schwarzer Rand 24 px, Bildschirm 1180 x 820 mit
  Radius 22; Kontaktschatten 0 50px 90px rgba(0,0,0,.38) + 0 10px 20px rgba(0,0,0,.25).
  Mac: macOS-Fenster mit Ampel, Seitenleiste, Systemstil.

OBJECTS: Smartboard (schwarzer Rahmen, matte Fläche, Spiegelung), iPad auf Eichenpult, Mac-Fenster mit
Finder-Datei, Mauszeiger 64 px, Fingerpunkt (iOS-Bildschirmaufnahme: grauer Kreis 56 px, 35 %).

MOTION:
- Ankunft `expo.out` 0,6–0,9 s; Kamera `power2.inOut` 0,5–0,7 s; Abgang/Zoom-through `power3.in` 0,35 s.
- Kapseln: `back.out(1.6)` auf scale, nie auf Deckkraft.
- Titel pro Wort: blur 6 → 0, opacity 0 → 1 in 0,14 s, 0,07 s Versatz; landen und stehen still.
- Wörter-Rolle: 0,1 s je Fassung.

SHOTS:
1. 0,0–2,4 Klassenzimmer. Board schwarz. Links „8:34“ (wortweise), „Die Klasse wartet.“ Ab 1,9 s Zoom durch das
   schwarze Board (power3.in) → Petrol. Ton: whoosh bei 2,2.
2. 2,4–5,6 Petrol. Pfad „Unterricht › Englisch › 8b › Unit 3 ›“ baut sich auf (Tick je Glied), der Dateiname rollt
   „Präsentation.pptx / Präsentation_neu.pptx / Präsentation_final.pptx / Präsentation_final_v2.pptx“, bleibt hängen,
   wird durchgestrichen; darunter „Welche war die richtige?“. Übergabe: der Dateiname bleibt, Grund flutet zu Papier.
3. 5,6–10,0 Papier. „Gestern, 14:30“, dann Mac-Fenster „Vorbereiten“ fährt ein; Zeiger zieht „Unit 3 Präsentation.pptx“
   aus dem Finder auf „Di · 8b · Englisch“; Zeile erscheint in der Materialliste; Titel „Einmal zuordnen. Fertig.“
   Ton: click beim Greifen, click-soft beim Ablegen.
4. 10,0–16,0 Pult. „Heute, 8:35“; iPad mit Tagesansicht (2. Stunde gewählt, „Jetzt“). Kamera auf die Kachel
   (1,0 → 1,9), Fingertipp, Kapsel „Am Smartboard“ springt auf; Schnitt beim Rückprall auf das Smartboard an der
   Wand: Folie „Past tense“. Titel „Ein Tipp. Schon an der Wand.“ Ton: click-soft, pop, whoosh-short.
5. 16,0–20,4 iPad-Tafel: Karo, Hand schreibt „go → went“, Kreis um „went“; rechts klein das Smartboard spiegelt
   live. Titel „Die Tafel ist im iPad.“
6. 20,4–25,2 Klassenzimmer weit: Smartboard „Hausaufgabe: Workbook S. 34“, Timer 2:00 → 1:56; iPad auf dem Pult im
   Vordergrund. Titel „Die Hausaufgabe steht an der Wand.“
7. 25,2–30,0 Petrol. „Ein Tipp. Am Smartboard.“ (bis 27,0), dann das Icon: drei blasse Zeilen fallen ein, die gelbe
   Zeile wächst zur großen Fläche (genau die Bedeutung aus UI-1); Wortmarke „Frontstage“ wischt ein; „Für iPad und Mac ·
   Bald im App Store“ steht ab 28,0 bis zum Ende. Ton: riser endet 27,6, impact-bass auf dem Icon.

BANNED: dunkle Leere mit kleinen schwebenden Elementen; Glow, Partikel; lila/blaue Verläufe, Glaskarten (außer
der Systemleiste von iPadOS); alles zentriert; alles blendet gleichzeitig ein; Titel, die nach dem Landen weitergleiten;
Logo in der Ecke; drei Karten in einer Reihe; schräg gestellte 3D-Geräte; Klick-Ringe; erfundene Funktionen;
**Schulmanager** (Anbindung entfällt, 2026-11-20); Vertretungen „aus der Stundenplan-Quelle“.

QA: 0,0 (Thumbnail: Board + 8:34) · 3,8 (Rolle mitten) · 8,6 (Datei abgelegt) · 12,4 (Kapsel sichtbar) ·
14,2 (Folie an der Wand) · 18,8 (Tafel geschrieben) · 23,0 (Hausaufgabe + Timer) · 26,0 (Claim) · 29,5 (Endkarte).
