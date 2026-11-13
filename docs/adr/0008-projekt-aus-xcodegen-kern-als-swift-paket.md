---
status: accepted
date: 2026-11-13
reversibility: two-way
area: plattform
---

# ADR-0008 — Xcode-Projekt aus XcodeGen, Kern als Swift-Paket, Swift 6

## Context and Problem Statement

Der Entwicklungsrechner ist Windows und kann nicht bauen; gebaut wird nur per CI auf macOS oder auf
einem Mac. Ein Xcode-Projekt (`.xcodeproj`) ist eine maschinengeschriebene Datei, die sich von Hand und
ohne Xcode kaum fehlerfrei pflegen lässt. Zu entscheiden war, wie das Projekt beschrieben wird und wie
Logik so geschnitten wird, dass ein CI-Lauf möglichst viel belegt. Umkehrkosten gering: Ein generiertes
Projekt lässt sich jederzeit einchecken und von da an in Xcode pflegen.

## Decision Drivers

- Projektbeschreibung muss als lesbarer Text auf Windows bearbeitbar sein
- Möglichst viel Logik ohne Oberfläche und ohne Simulator testbar (`swift test`)
- Jeder CI-Lauf kostet Geld; Fehler sollen vorher im Diff erkennbar sein

## Considered Options

- XcodeGen (`project.yml`), Kern als lokales Swift-Paket
- Tuist (Projektbeschreibung in Swift)
- `.xcodeproj` einchecken und von Hand pflegen

## Decision Outcome

Chosen option: "XcodeGen, Kern als lokales Swift-Paket", because `project.yml` kurzer, lesbarer YAML-Text
ist und die CI das Projekt vor jedem Bau neu erzeugt. Festgelegt:

- `project.yml` im Wurzelverzeichnis beschreibt zwei App-Ziele (iPadOS, macOS) aus gemeinsamem Code; das
  `.xcodeproj` wird nicht eingecheckt.
- Logik ohne Oberfläche liegt im Swift-Paket `FrontstageKern` (`Packages/FrontstageKern`), getestet mit
  `swift test` auf dem macOS-Runner. Es hängt nicht von SwiftUI, SwiftData oder UIKit ab.
- Sprachmodus Swift 6 mit strikter Nebenläufigkeitsprüfung.
- Tests im Kern mit Swift Testing (`import Testing`, `@Test`, `#expect`).

### Consequences

- Nutzen: Projektänderungen sind im Diff lesbar; der Kern ist ohne Simulator in Sekunden geprüft.
- Kosten (Pflicht): Abhängigkeit von einem Werkzeug außerhalb von Apple (XcodeGen), das zu neuen
  Xcode-Versionen nachziehen muss. Wer später am Mac in Xcode Einstellungen ändert, muss sie in
  `project.yml` nachtragen, sonst gehen sie beim nächsten Erzeugen verloren. Swift 6 strikt erzeugt
  anfangs mehr Compilerfehler, die nur per CI sichtbar werden.

### Revisit if

- XcodeGen unterstützt eine neue Xcode-Version länger als einen Monat nicht, oder es gibt dauerhaft
  einen Mac in der Entwicklung, sodass Xcode selbst das Projekt pflegen kann.

## Pros and Cons of the Options

### XcodeGen

- Vorzug: kurzes YAML, verbreitet, einfach in CI.
- Nachteil: Fremdwerkzeug.

### Tuist

- Vorzug (verworfen): Projektbeschreibung in Swift mit Typprüfung; mächtiger bei vielen Modulen.
- Nachteil: Prüfung erst auf dem Mac möglich – auf Windows ist Swift-Code ebenso wenig prüfbar wie YAML,
  aber schwerer zu lesen; mehr Einrichtung.

### `.xcodeproj` einchecken

- Vorzug (verworfen): kein Fremdwerkzeug, Standard für Xcode-Nutzer.
- Nachteil: ohne Xcode praktisch nicht fehlerfrei änderbar; unlesbare Diffs.

## More Information

- Area doc: docs/ARCHITECTURE.md#area-plattform
