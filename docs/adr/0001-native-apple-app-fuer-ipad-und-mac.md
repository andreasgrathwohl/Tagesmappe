---
status: accepted
date: 2026-11-13
reversibility: one-way
area: plattform
---

# ADR-0001 — Native Apple-App für iPad und Mac

## Context and Problem Statement

Das Produkt läuft im Unterricht auf dem persönlichen Tablet der Lehrkraft und wird am Mac oder Tablet
vorbereitet (FR-3, FR-4). Es muss die Dateien-App des Systems und deren Ablage-Anbieter erreichen
(NFR-3), Material an andere Apps übergeben (FR-5), selbst PDFs mit Stift zeigen (FR-6) und mit der
Klassenraum-Technik (Apple TV per AirPlay) zusammenspielen. Die Umkehrkosten sind hoch: Ein Wechsel
der App-Technik ist ein Neubau aller Oberflächen und aller Systemanbindungen.

## Decision Drivers

- Zugriff auf Dateien-App, Ablage-Anbieter und Übergabe an andere Apps ohne Umwege
- Stift (Apple Pencil) und AirPlay in Systemqualität
- ein Code für Tablet und Mac
- keine eigenen Server (NFR-2)

## Considered Options

- Native App mit SwiftUI (ein Projekt für iPadOS und macOS)
- Web-Technik in einer App-Hülle (React, Vite, Capacitor)
- Flutter

## Decision Outcome

Chosen option: "Native App mit SwiftUI", because nur sie Dateien-App, Ablage-Anbieter, Stift und
AirPlay ohne Zusatzbrücken erreicht und Tablet und Mac aus einem Code bedient. Andreas stimmte am
2026-11-13 zu, ausdrücklich mit der Folge, dass Android-Tablets vorerst entfallen.

### Consequences

- Nutzen: volle Systemanbindung (Dateien, Stift, AirPlay, Schlüsselbund, iCloud); eine Codebasis für
  iPad und Mac; gutes Verhalten nach Apples Gestaltungsrichtlinien ist erreichbar.
- Kosten (Pflicht): Android-Tablets und Windows sind ausgeschlossen (PRD, Out of Scope). Gebaut werden
  kann nur auf macOS – der Entwickler arbeitet unter Windows, also baut ausschließlich CI auf
  macOS-Runnern (kostet je Lauf Geld) oder ein Mac. Swift/SwiftUI ist für den Entwickler kein
  Hauptstack; Einarbeitung nötig. Verteilung nur über ein Apple-Entwicklerkonto (RISK-4).

### Confirmation

Das Repo enthält ein Xcode-Projekt mit Zielen für iPadOS und macOS; kein Web- oder Flutter-Code.

### Revisit if

- Mehr als ein Drittel der Interessenten in Rückmeldungen nennt Android-Tablets als Gerät.
- Eine Schule oder ein Träger als Kunde Android oder Windows verbindlich vorgibt.

## Pros and Cons of the Options

### Native App mit SwiftUI

- Vorzug: direkter Zugriff auf alle Systemdienste; ein Code für iPad und Mac.
- Nachteil: nur Apple-Geräte; Bauen nur auf macOS.

### Web-Technik in einer App-Hülle (React, Vite, Capacitor)

- Vorzug (verworfen): Hauptstack des Entwicklers; derselbe Code liefe auch auf Android-Tablets und im
  Browser.
- Nachteil: Dateien-App-Zugriff mit dauerhaften Ordnerrechten, Stift-Zeichnen auf PDFs und Übergabe an
  andere Apps nur über eigene native Erweiterungen – genau die Kernfunktionen würden doch nativ
  geschrieben, nur mit einer Brücke dazwischen.

### Flutter

- Vorzug (verworfen): ein Code für iPad, Android und Desktop mit eigener, einheitlicher Darstellung.
- Nachteil: dieselben nativen Lücken wie bei Web-Technik (Dateien-App, Stift auf PDF, Übergabe);
  zusätzlicher, für den Entwickler fremder Stack.

## More Information

- Area doc: docs/ARCHITECTURE.md#area-plattform
