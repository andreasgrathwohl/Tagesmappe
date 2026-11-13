# Überblick

> Zusammenfassung von [docs/PRD.md](../docs/PRD.md). Bei Abweichung gilt das PRD.

## Das Problem

Lehrkräfte suchen ihr Unterrichtsmaterial vor und in jeder Stunde in tiefen Ordnerstrukturen
zusammen. Das kostet Zeit und Ruhe vor der Klasse – besonders, wenn das Schulnetz wackelt.

## Die Idee

Material wird **vorher** den Stunden des Stundenplans zugeordnet. Im Unterricht zeigt das iPad nur
**den heutigen Tag**; ein Tipp öffnet das Material in der gewohnten App, gezeigt wird wie bisher –
etwa per Apple TV auf dem Smartboard.

```
Mac oder iPad (Vorbereiten)                iPad (Unterricht)
┌──────────────────────────────┐           ┌───────────────────────────┐
│ Woche 47                     │           │ Dienstag, 17.11.          │
│ Di 2. Std 8b Englisch        │  ──────▶  │ 1  7a  Deutsch   [AB 3]   │
│   ▸ Unit 4 – Präsentation    │  Abgleich │ 2  8b  Englisch  [Unit 4] │
│   ▸ Arbeitsblatt Vokabeln    │           │ 3  —                      │
│ Mi 3. Std 8a Englisch  …     │           │ 4  9b  Englisch  [KA 1]   │
└──────────────────────────────┘           └───────────────────────────┘
          │                                            │ Tipp
          ▼                                            ▼
   Ablage der Lehrkraft (iCloud Drive, OneDrive, Google Drive, …)
   – Material bleibt dort, wird nie kopiert –
```

*(Skizze zur Veranschaulichung, kein Gestaltungsbeschluss – der gehört in `DESIGN.md`.)*

## Ablauf

1. Stundenplan einrichten – von Hand oder aus Schulmanager Online
2. Vorbereiten – Material den Unterrichtsstunden zuordnen
3. Tagesansicht im Unterricht öffnen
4. Material öffnen, präsentieren, darin schreiben und zeichnen
5. Änderungen landen sofort in der Ablage

## Am Smartboard

Das Smartboard ist ein Zweitbildschirm: Es zeigt nie die Tagesansicht, sondern genau eines von vier
Dingen – den Klassenbildschirm (Klasse, Fach, Uhrzeit, Thema, Timer, Arbeitsform), das geöffnete
Material, die Tafel oder nichts (dunkel). Umgeschaltet wird am iPad, das immer zeigt, was die Klasse
gerade sieht. Was an die Tafel geschrieben wird, bleibt als Tafelbild bei der Unterrichtsstunde.

## Für wen

Lehrkräfte mit eigenem iPad, mit oder ohne Mac, mit oder ohne Microsoft 365. Nicht für Schüler,
Eltern oder Verwaltung.

## Grundsätze

- **Keine eigenen Server** – Daten bleiben bei der Lehrkraft.
- **Ein Stand je Datei** – Zuordnen verweist, kopiert nie.
- **Präsentieren bleibt in PowerPoint & Co.** – die App ersetzt sie nicht.
