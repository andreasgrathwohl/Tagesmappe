# Prüfprotokoll Startseite (Teilplan 13, Task 5, AK-64)

Datum: 2026-11-16. Gegen den Container (`docker compose up -d --build`, Test-`.env`, `COOKIE_SECURE=false`,
`NOINDEX=true`), Basis `http://127.0.0.1:8000/`. Chromium über Playwright 1.65, axe-core 4 aus dem
lokalen npm-Paket (kein CDN).

## Ergebnisse

| Prüfung | Ergebnis |
|---|---|
| 390x844 und 1440x900, hell und dunkel: `scrollWidth <= innerWidth` | bestanden (4 von 4) |
| 390 px mit 200 % Schrift (eigener Kontext, `bypassCSP`) | zunächst Überlauf (516 px), nach Fix 390 px |
| `javaScriptEnabled: false`, `reducedMotion: reduce` | alle 13 `main`-Abschnitte (Hero + 12 Stationen) sichtbar, Deckkraft 1 |
| Netzwerk | nur Ursprung `127.0.0.1:8000`; keine `Set-Cookie`-Antwort; 0 Cookies; Konsole ohne Fehler und CSP-Verstoß |
| axe-core (serious/critical) | zunächst 5 Verstöße `color-contrast` (Tabelle Vorjahr), nach Fix 0, in allen vier Varianten |
| Tastatur | Sprunglink, Wortmarke, Navigation, Knöpfe, dann Inhalt; Fokus immer 3 px Kontur sichtbar |
| Impressum, Datenschutz (AK-65) | `/impressum/` und `/datenschutz/` liefern 200 |
| `robots.txt`, `X-Robots-Tag` | `Disallow: /`, `noindex, nofollow` (NOINDEX aktiv) |

## Befunde und Fixes

1. 200 % Schrift: Hero-Raster wurde 500 px breit (min-content der Grid-Kinder) und der Knopf der Kopfzeile
   (`nowrap`) 281 px. Fix: `.hero .wrap > * { min-width: 0 }`, Knöpfe umbrechbar, Kopfzeile `flex-wrap`.
2. Kontrast: `.plan__table .old` mit `opacity: 0.45` unter 4,5:1. Fix: Farbmischung 70 % Text / 30 % Grund.
3. Der leise Knopf („So sieht ein Tag aus“) war auf Mobil um 26 px eingerückt: `padding-inline: 0`.
4. Befund (Dienst, nicht Teilplan): `.woff2` wird mit `Content-Type: application/octet-stream` ausgeliefert
   statt `font/woff2`. Browser laden die Schrift trotz `nosniff` (geprüft), Korrektur gehört in den Dienst:
   `mimetypes.add_type("font/woff2", ".woff2")`.

## Look-and-fix (design-taste-frontend, Bildschirmfotos je Abschnitt)

Gesamtwirkung ruhig und eigenständig, Rhythmus aus Wechsel von Grund, Alt-Grund und Petrol-Flächen,
keine Eyebrows, Verläufe oder Schatten. Offen (kein Fehler): Hero-Detailfläche unter den Kacheln auf Desktop leer;
Jahresplan-Karte im Dunkelmodus hebt sich kaum vom Grund ab.
