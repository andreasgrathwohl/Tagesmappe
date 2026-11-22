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

1. Stundenplan einrichten – von Hand
2. Vorbereiten – Material den Unterrichtsstunden zuordnen
3. Tagesansicht im Unterricht öffnen
4. Material öffnen, präsentieren, darin schreiben und zeichnen
5. Änderungen landen sofort in der Ablage
6. Vorplanen – je Fach und Jahrgang das Schuljahr in Wochen planen; Wochenthema und Klassenarbeiten
   erscheinen beim Vorbereiten und im Unterricht

## Jahresplanung

Ein Jahresplan gilt für ein Fach, einen Jahrgang und ein Schuljahr (z. B. Englisch, Jahrgang 8, 2026/27);
alle Klassen des Jahrgangs folgen ihm. Je Unterrichtswoche stehen darin Thema, Tests und Klassenarbeiten
und Notizen. Frühere Jahre lassen sich nebeneinander ansehen und als Vorlage übernehmen.

## Am Smartboard

Das Smartboard ist ein Zweitbildschirm: Es zeigt nie die Tagesansicht, sondern genau eines von vier
Dingen – den Klassenbildschirm (Klasse, Fach, Uhrzeit, Thema, Timer, Arbeitsform), das geöffnete
Material, die Tafel oder nichts (dunkel). Umgeschaltet wird am iPad, das immer zeigt, was die Klasse
gerade sieht. Was an die Tafel geschrieben wird, bleibt als Tafelbild bei der Unterrichtsstunde.
Hängt an einem Arbeitsblatt eine Lösung, zeigt das iPad sie neben dem Blatt; aufs Smartboard kommt sie nie,
und wird das iPad-Bild nur gespiegelt, blendet die App sie aus.

## Hilfe und Rückmeldung

An jedem Bildschirm führt ein Fragezeichen zur passenden Erklärung, die in der App liegt und ohne Netz
lesbar ist; das Hilfecenter in Einrichten durchsucht alle Artikel. Ideen und Hinweise schickt die Lehrkraft
an den Rückmeldedienst der Entwickler – nach einmaliger Zustimmung, ersatzweise per E-Mail –, auf Wunsch mit
Bildschirmfotos, auf die sie zeichnen und auf denen sie Namen schwärzen kann. Die Entwickler lesen sie auf einer
Verwaltungsseite; nach zwölf Monaten werden sie gelöscht. Eine Startseite zeigt an einem Schultag, wie die App hilft.

## Für wen

Lehrkräfte mit eigenem iPad, mit oder ohne Mac, mit oder ohne Microsoft 365. Nicht für Schüler,
Eltern oder Verwaltung.

## Grundsätze

- **Keine Nutzerdaten auf unseren Servern** – nur eine Rückmeldung, die die Lehrkraft ausdrücklich sendet, erreicht den Dienst der Entwickler; alle Daten bleiben bei der Lehrkraft, wahlweise in iCloud oder in ihrem OneDrive; ein zweites Gerät koppelt per QR-Code.
- **Notizen neben dem Dokument** – Stiftnotizen liegen als Notiz-Datei und lesbares PDF im Ordner des Materials.
- **Ein Stand je Datei** – Zuordnen verweist, kopiert nie.
- **Präsentieren bleibt in PowerPoint & Co.** – die App ersetzt sie nicht.
- **Kein Abo** – der Kern ist kostenlos, Klassenbildschirm und Tafel kosten einmal.
