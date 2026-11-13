# Tagesmappe (Arbeitstitel)

Tagesbegleiter für Lehrkräfte auf iPad und Mac: Unterrichtsmaterial vorab den Stunden des festen
Stundenplans zuordnen – und im Unterricht nur den heutigen Tag sehen. Eine Stunde antippen, das
Material öffnet sich (z. B. in PowerPoint) und wird über die Klassenraum-Technik gezeigt. Das Material
bleibt in der eigenen Ablage (iCloud Drive, OneDrive, Google Drive, …) und ist immer der aktuelle
Stand.

> **Stand:** Spezifikation. Die Anforderungen sind freigegeben (`docs/PRD.md`, `status: ready`);
> die ersten fünf Architekturentscheidungen sind beschlossen (`docs/adr/`). Es gibt noch keinen Code.

## Worum es geht

- **Vorbereiten** am Mac oder iPad: Material den Unterrichtsstunden der Woche oder des nächsten Tages
  zuordnen – mehrere Dateien je Stunde, Übernehmen für Parallelklassen, Weiterschieben bei Ausfall.
- **Stundenplan** von Hand anlegen oder aus Schulmanager Online übernehmen; A/B-Wochen, Ferien,
  Ausfall und Vertretungen.
- **Im Unterricht**: Tagesansicht, ein Tipp öffnet das Material. Mit Microsoft 365 öffnen
  OneDrive-Dateien mit AutoSpeichern, Notizen und Zeichnungen landen sofort in der Ablage. PDFs und
  Bilder zeigt die App selbst, mit Stift.
- **Datenschutz**: keine eigenen Server – Stundenplan, Zuordnungen und Material bleiben bei der
  Lehrkraft.

## Dokumente

| Dokument | Inhalt |
|---|---|
| [docs/PRD.md](docs/PRD.md) | Was, für wen, warum: Glossar, Anforderungen, Lieferstufen, Risiken, offene Fragen, Abnahmekriterien |
| [docs/adr/](docs/adr/) | Architekturentscheidungen, je Entscheidung eine Datei |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Wie gebaut wird, je Bereich (Bereichsliste steht, Ausarbeitung folgt) |
| `DESIGN.md` | Gestaltungsbeschlüsse (folgt) |
| [wiki/](wiki/Home.md) | Einstieg, Überblick und Wegweiser in die Dokumente |

Maßgeblich sind immer die Dokumente unter `docs/` und `DESIGN.md`; das Wiki verweist nur darauf.

## Entwicklung

- Native Apple-App für iPad und Mac (ADR-0001); Daten im privaten iCloud-Bereich der Lehrkraft
  (ADR-0002); Material über die Dateien-App, OneDrive zusätzlich direkt (ADR-0003).
- Projektlokaler Claude-Code-Skill `apple-design` (Apple Human Interface Guidelines). Er ist nicht im
  Repo enthalten (Inhalt ohne Lizenz bzw. Apple-Texte); wiederherstellen mit
  `npx skills add dickwu/apple-design-skill --skill apple-design -y`.

## Verwandt

[OneDrive Opener](https://github.com/andreasgrathwohl/OneDriveMac) – macOS-App, die Office-Dateien aus
OneDrive mit AutoSpeichern öffnet. Eigenständig; Tagesmappe übernimmt die dort gewonnenen
Erkenntnisse zum Öffnen von OneDrive-Dokumenten in Office.
