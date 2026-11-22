# Frontstage

Tagesbegleiter für Lehrkräfte auf iPad und Mac: Unterrichtsmaterial vorab den Stunden des festen
Stundenplans zuordnen – und im Unterricht nur den heutigen Tag sehen. Eine Stunde antippen, das
Material öffnet sich (z. B. in PowerPoint) und wird über die Klassenraum-Technik gezeigt. Das Material
bleibt in der eigenen Ablage (iCloud Drive, OneDrive, Google Drive, …) und ist immer der aktuelle
Stand.

> **Stand:** Umsetzung. Anforderungen und Architektur sind freigegeben (`docs/PRD.md`, `docs/ARCHITECTURE.md`);
> sechzehn Architekturentscheidungen stehen in `docs/adr/`. Die Teilpläne 01–10 sind umgesetzt, Teilpläne 11 (Hilfe und Rückmeldung), 12 (Rückmeldedienst und Verwaltung) und 13 (Startseite) sind geplant (`docs/superpowers/plans/`):
> SwiftUI-App für iPad und Mac unter `Frontstage/`, Kernlogik im Paket `Packages/FrontstageCore`; Rückmeldedienst und Startseite (geplant) unter `server/`. Offen sind Prüfungen auf
> echten Geräten, die Gestaltungsrunden. Die Schulmanager-Anbindung ist abgeschaltet, bis ihre Zulässigkeit geklärt ist (ADR-0016). Unter `mockup/` liegen HTML-Mockups.
> Der Name „Frontstage“ ist intern festgelegt, die Registerprüfung steht aus (Q-31). Das Repository
> heißt weiter `Tagesmappe`.

## Worum es geht

- **Vorbereiten** am Mac oder iPad: Material den Unterrichtsstunden der Woche oder des nächsten Tages
  zuordnen – mehrere Dateien je Stunde, Übernehmen für Parallelklassen, Weiterschieben bei Ausfall.
- **Stundenplan** von Hand anlegen; A/B-Wochen, Ferien,
  Ausfall und Vertretungen.
- **Im Unterricht**: Tagesansicht, ein Tipp öffnet das Material. Mit Microsoft 365 öffnen
  OneDrive-Dateien mit AutoSpeichern, Notizen und Zeichnungen landen sofort in der Ablage. PDFs und
  Bilder zeigt die App selbst, mit Stift; diese Stiftnotizen gelten je Unterrichtsstunde und lassen
  die Datei unverändert. Das Smartboard zeigt dabei als Zweitbildschirm nur das Material – die
  Tagesansicht bleibt auf dem iPad. Hängt an einem Arbeitsblatt eine Lösung, sieht die Lehrkraft sie am
  iPad daneben, die Klasse nie.
- **Smartboard und Tafel**: Ist nichts geöffnet, zeigt das Smartboard einen Klassenbildschirm (Klasse,
  Fach, Uhrzeit, Thema, Timer, Arbeitsform). Mit einem Tipp wird das iPad zur Tafel; das Tafelbild
  bleibt bei der Unterrichtsstunde.
- **Jahresplanung**: je Fach und Jahrgang das Schuljahr in Unterrichtswochen vorplanen – Themen, Tests und
  Klassenarbeiten, Notizen; frühere Jahre nebeneinander ansehen und den Vorjahresplan übernehmen. Das
  Wochenthema erscheint in Vorbereiten als Vorschlag, Leistungsnachweise an den Unterrichtsstunden.
- **Erscheinungsbild**: warmer Standard; Grundton, Akzentfarbe (frei, mit Kontrastschutz) und Hell/Dunkel
  einstellbar, außerhalb des Standards per Einmalkauf.
- **Hilfe und Rückmeldung**: ein Fragezeichen an jedem Bildschirm öffnet die passende Erklärung, auch ohne Netz;
  das Hilfecenter durchsucht alle Artikel. Ideen und Hinweise gehen an den Rückmeldedienst der Entwickler (ersatzweise per E-Mail),
  mit Bildschirmfotos, auf die man zeichnen und Stellen schwärzen kann. Kurz-Tipps erklären das Wichtigste beim
  ersten Gebrauch.
- **Datenschutz**: keine Nutzerdaten auf Servern des Produkts – Stundenplan, Zuordnungen und Material bleiben bei der
  Lehrkraft; nur eine ausdrücklich gesendete Rückmeldung erreicht den Rückmeldedienst, der sie nach zwölf Monaten löscht.
- **Rückmeldedienst und Startseite**: ein Container beim Betreiber nimmt Rückmeldungen an, bietet eine Verwaltungsseite
  und liefert die Startseite mit Impressum und Datenschutz aus (`server/`, ADR-0015).

## Dokumente

| Dokument | Inhalt |
|---|---|
| [docs/PRD.md](docs/PRD.md) | Was, für wen, warum: Glossar, Anforderungen, Lieferstufen, Risiken, offene Fragen, Abnahmekriterien |
| [docs/adr/](docs/adr/) | Architekturentscheidungen, je Entscheidung eine Datei |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Wie gebaut wird, je Bereich: Bausteinbild, Datenmodell, Abgleich, Dateizugriff, Stundenplan-Quellen, Anzeige |
| [DESIGN.md](DESIGN.md) | Gestaltungsbeschlüsse UI-1 bis UI-15 (App-Icon, Tagesansicht, Farben, Schrift, Formen, Sprache); offen: Klassenbildschirm, Tafel, Kaufangebot |
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
