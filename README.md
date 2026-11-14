# Frontstage

Tagesbegleiter für Lehrkräfte auf iPad und Mac: Unterrichtsmaterial vorab den Stunden des festen
Stundenplans zuordnen – und im Unterricht nur den heutigen Tag sehen. Eine Stunde antippen, das
Material öffnet sich (z. B. in PowerPoint) und wird über die Klassenraum-Technik gezeigt. Das Material
bleibt in der eigenen Ablage (iCloud Drive, OneDrive, Google Drive, …) und ist immer der aktuelle
Stand.

> **Stand:** Umsetzung. Anforderungen und Architektur sind freigegeben (`docs/PRD.md`, `docs/ARCHITECTURE.md`);
> dreizehn Architekturentscheidungen stehen in `docs/adr/`. Die Teilpläne 01–09 sind umgesetzt (`docs/superpowers/plans/`):
> SwiftUI-App für iPad und Mac unter `Frontstage/`, Kernlogik im Paket `Packages/FrontstageCore`. Offen sind Prüfungen auf
> echten Geräten, die Gestaltungsrunden und der Test der Schulmanager-Schnittstelle (Q-16). Unter `mockup/` liegen HTML-Mockups.
> Der Name „Frontstage“ ist intern festgelegt, die Registerprüfung steht aus (Q-31). Das Repository
> heißt weiter `Tagesmappe`.

## Worum es geht

- **Vorbereiten** am Mac oder iPad: Material den Unterrichtsstunden der Woche oder des nächsten Tages
  zuordnen – mehrere Dateien je Stunde, Übernehmen für Parallelklassen, Weiterschieben bei Ausfall.
- **Stundenplan** von Hand anlegen oder aus Schulmanager Online übernehmen; A/B-Wochen, Ferien,
  Ausfall und Vertretungen.
- **Im Unterricht**: Tagesansicht, ein Tipp öffnet das Material. Mit Microsoft 365 öffnen
  OneDrive-Dateien mit AutoSpeichern, Notizen und Zeichnungen landen sofort in der Ablage. PDFs und
  Bilder zeigt die App selbst, mit Stift; diese Stiftnotizen gelten je Unterrichtsstunde und lassen
  die Datei unverändert. Das Smartboard zeigt dabei als Zweitbildschirm nur das Material – die
  Tagesansicht bleibt auf dem iPad.
- **Smartboard und Tafel**: Ist nichts geöffnet, zeigt das Smartboard einen Klassenbildschirm (Klasse,
  Fach, Uhrzeit, Thema, Timer, Arbeitsform). Mit einem Tipp wird das iPad zur Tafel; das Tafelbild
  bleibt bei der Unterrichtsstunde.
- **Jahresplanung**: je Fach und Jahrgang das Schuljahr in Unterrichtswochen vorplanen – Themen, Tests und
  Klassenarbeiten, Notizen; frühere Jahre nebeneinander ansehen und den Vorjahresplan übernehmen. Das
  Wochenthema erscheint in Vorbereiten als Vorschlag, Leistungsnachweise an den Unterrichtsstunden.
- **Datenschutz**: keine eigenen Server – Stundenplan, Zuordnungen und Material bleiben bei der
  Lehrkraft.

## Dokumente

| Dokument | Inhalt |
|---|---|
| [docs/PRD.md](docs/PRD.md) | Was, für wen, warum: Glossar, Anforderungen, Lieferstufen, Risiken, offene Fragen, Abnahmekriterien |
| [docs/adr/](docs/adr/) | Architekturentscheidungen, je Entscheidung eine Datei |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Wie gebaut wird, je Bereich: Bausteinbild, Datenmodell, Abgleich, Dateizugriff, Stundenplan-Quellen, Anzeige |
| [DESIGN.md](DESIGN.md) | Gestaltungsbeschlüsse – bisher das App-Icon (UI-1, Quelle in `design/icon/`); alle übrigen Kategorien offen |
| [mockup/](mockup/LIESMICH.md) | HTML-Mockups von Tagesansicht, Vorbereiten und Einrichten – Veranschaulichung, kein Beschluss |
| [CLAUDE.md](CLAUDE.md) | Projektregeln: Bauen, Skills, Dokument-Konvention |
| [wiki/](wiki/Home.md) | Einstieg, Überblick und Wegweiser in die Dokumente |

Maßgeblich sind immer die Dokumente unter `docs/` und `DESIGN.md`; das Wiki verweist nur darauf.

## Entwicklung

- Native Apple-App für iPad und Mac (ADR-0001); App-Daten wahlweise in iCloud oder in OneDrive, direkt über
  Microsoft Graph, ein zweites Gerät koppelt per QR-Code (ADR-0012); Stiftnotizen neben dem Dokument (ADR-0011); Material über die Dateien-App, OneDrive
  zusätzlich direkt (ADR-0003).
- Projektlokaler Claude-Code-Skill `apple-design` (Apple Human Interface Guidelines). Er ist nicht im
  Repo enthalten (Inhalt ohne Lizenz bzw. Apple-Texte); wiederherstellen mit
  `npx skills add dickwu/apple-design-skill --skill apple-design -y`.

## Verwandt

[OneDrive Opener](https://github.com/andreasgrathwohl/OneDriveMac) – macOS-App, die Office-Dateien aus
OneDrive mit AutoSpeichern öffnet. Eigenständig; Frontstage übernimmt die dort gewonnenen
Erkenntnisse zum Öffnen von OneDrive-Dokumenten in Office.
