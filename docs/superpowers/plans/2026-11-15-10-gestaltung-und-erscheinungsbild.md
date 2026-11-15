# Frontstage — Teilplan 10: Gestaltung umsetzen und Erscheinungsbild

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Rahmen: `docs/superpowers/plans/2026-11-13-00-uebersicht.md` – gilt vollständig und geht diesem Teilplan vor.

**Goal:** Die beschlossene Gestaltung (DESIGN.md, UI-2 bis UI-15) in die App bringen – Tagesansicht als Liste und Detail, warme Grundtöne, Petrol-Akzent, SF Rounded, Signalfarben im Symbol, „Jetzt“ und „Am Smartboard“ – und das Erscheinungsbild einstellbar machen (Grundton, Akzentfarbe mit Kontrastschutz, Hell/Dunkel; FR-16 bis FR-16.2), abgeglichen auf allen Geräten und außerhalb des Standards hinter dem Einmalkauf (FR-13).

**Architecture:** Alle Farbrechnung ist reine Logik im Kern (`Packages/FrontstageCore/Sources/FrontstageCore/Theme/`): sRGB-Werte, relative Leuchtdichte, Kontrastverhältnis nach WCAG, deckendes Mischen, Helligkeitsverschiebung bis zu einem Zielkontrast, die vier Grundtöne als Daten und `ThemeResolver`, der aus Grundton, Akzent und Variante (hell/dunkel, je mit hohem Kontrast) alle Rollenfarben berechnet; dazu die Auswahlregel der Tagesansicht (`DaySelection`) und das Datenordner-Format des Erscheinungsbilds – lokal mit `scripts\swift-test.ps1` getestet. Die App speichert das Erscheinungsbild als einen abgeglichenen Datensatz (`ThemeRecord`, Muster aus Teilplan 09), wendet es in `RootView` als Umgebungswert mit dynamischen Farben an (außerhalb von `DataScopedRoot`, weil Einrichten dort liegt), bietet Einrichten › Erscheinungsbild und baut die Tagesansicht nach UI-3 bis UI-15 neu.

**Tech Stack:** Swift 6 strikt, SwiftUI (`NavigationSplitView`, `List(selection:)`, `ColorPicker`, `ContentUnavailableView`, `@ScaledMetric`, `Date.IntervalFormatStyle`), UIKit/AppKit nur für dynamische Farben (`UIColor(dynamicProvider:)`, `NSColor(name:dynamicProvider:)`), SwiftData, Swift Testing, XcodeGen. Keine neue Abhängigkeit.

**Spec:** `DESIGN.md` (UI-2 bis UI-15 vollständig, besonders UI-8 „Geändert 2026-11-15“ mit den vier Grundtönen, UI-9 Akzent und Signalfarben, UI-11 Signalsymbole, UI-12 Kapseln); `docs/PRD.md` (FR-13 geändert 2026-11-15, FR-16, FR-16.1, FR-16.2, AK-52 bis AK-54, Q-40, Glossar „Erscheinungsbild“ `Theme`, „Grundton“ `BaseTone` mit `warm`/`system`/`cool`/`petrol`, „Akzentfarbe“ `ThemeAccent`, „Hell/Dunkel“ `AppearanceMode` mit `system`/`light`/`dark`); `docs/ARCHITECTURE.md` (Area daten: Datenmodell, Datenort mit beiden Abgleichwegen, Nebenläufigkeit; Area plattform: Kauf); `docs/adr/0012-datenort-icloud-oder-onedrive-nativ.md` (jede Modelländerung in beiden Abgleichwegen).

**Baut auf (Code auf `main`):** Teilpläne 01–09 vollständig gemergt. Genutzt werden u. a.: `ClassScreenCalculator.phase(now:lessons:)` und `ClassScreenPhase.runningLessonKey` (01/07); `DataStore` mit `saveAndBump()`, `mergeDuplicates()` (`LoadedRecords` in `DataStore+Merge.swift`), `ModelContainerFactory.modelTypes` (zwölf Typen) (02/09); `SyncModel`, `RecordPayload`, `RecordCodec` mit `exportAll`/`export(_:from:)`/`liveIDs`/`upsert`/`delete`/`HasRecordID` (08/09); `AppEnvironment`, `DayScreen`/`DayView`/`DayViewModel`/`DayRowActions`/`LessonRow`/`MaterialRow`/`DayRow`/`DayContent`/`DayStatement`, `AssignLessonSheet`, `SetupView`, `RootView` mit `scoped { … }`, `Localizable.xcstrings` (04, 09); `SecondScreenState.shared`, `SmartboardBar`, `HandOffAnchorReader` (06); `Unlock`, `PaidFeature`, `PaidGate`, `PurchaseOfferView`, `ClassroomServices.shared` (07); `SourceStatusBar`, `SourceStatusBarModel`, `TimetableSourceCoordinator` (05).

## Global Constraints

Alle Zeilen der Übersicht gelten (Abschnitt „Global Constraints“, Abstimmung Punkte 1–17). Zusätzlich für diesen Teilplan:

- **Kern zuerst und lokal belegt:** Tasks 1–4 berühren nur `Packages/FrontstageCore` (nur `import Foundation`) und laufen TDD mit `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\swift-test.ps1 -Filter <Struct>`. Gefiltert wird nach dem **Namen der Suite-Struktur** (`SRGBColorTests`), nie nach dem Anzeigenamen aus `@Suite("…")` – sonst läuft nichts und der Exit-Code ist trotzdem 0 („No matching test cases were run“). Jede neue Suite-Struktur heißt wie ihre Datei. Tasks 5–11 sind App-Code: auf Windows nicht baubar; „Test ausführen“ heißt dort Task 12 (ein CI-Lauf, führt der Controller aus). Vor jedem Commit eines App-Tasks `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\swift-parse.ps1` (keine Ausgabezeile mit `error:`) und Diff-Durchsicht.
- **Farbwerte wörtlich aus DESIGN.md** (Hex in Großbuchstaben, `#RRGGBB`):
  - Grundton **warm** (Standard, UI-8): Hintergrund `#FBF8F2` / `#17130E`, Auswahlfläche `#ECE5D8` / `#2F2921`, Text `#1F1A14` / `#F5EFE5`, Haarlinie `rgba(92,72,48,.22)` / `rgba(125,108,86,.55)`.
  - **kühl:** `#F7F9FC` / `#0B1120`, `#E2E8F0` / `#1E293B`, `#0F172A` / `#EEF2F7`, `rgba(51,65,85,.20)` / `rgba(71,85,105,.60)`.
  - **Petrol:** `#F6F9F9` / `#061416`, `#DFE9EA` / `#15292C`, `#0C1F23` / `#ECF4F4`, `rgba(14,75,87,.18)` / `rgba(60,100,106,.55)`.
  - **System:** Systemfarben in der App; für die Kontrastrechnung Bezugswerte – Hintergrund `#FFFFFF` / `#000000` und Auswahlfläche `#E5E5EA` / `#2C2C2E` aus UI-8 „Kontext“; Text `#000000` / `#FFFFFF` und Haarlinie `rgba(60,60,67,.29)` / `rgba(84,84,88,.60)` stehen nicht in DESIGN.md, sondern sind die iOS-Werte von `label` und `separator` (gehen in keine Kontrastregel ein).
  - Standard-Akzent Petrol `#0E6B7A` / `#5FC2CF`; Tönung deckend, Akzent zu **14 %** (hell) bzw. **22 %** (dunkel) über dem Hintergrund (UI-9).
  - Signalsymbole (UI-11): Entfällt `#ED372D` / `#FF453A`, Material nicht verfügbar `#B86B00` / `#FF9F0A`; Vertretung und Ohne Material in Textfarbe.
  - „jetzt, gezeigt“ (UI-12): Kapselfläche `#FFC94A`, Wort und Symbol `#1F1A14` in **beiden** Modi.
- **Kontrastziele (FR-16.1, UI-11):** Akzentton ≥ 4,5:1, Signalsymbole ≥ 3:1, jeweils gegen die ungünstigste von Hintergrund, Auswahlfläche und Tönung. Bei „Kontrast erhöhen“ ≥ 7:1 bzw. ≥ 4,5:1 (Entscheidung 6).
- **Begriffe:** Glossar-Namen `Theme`, `BaseTone` (`warm`, `system`, `cool`, `petrol`), `ThemeAccent`, `AppearanceMode` (`system`, `light`, `dark`). Rein technische Namen dieses Plans (`SRGBColor`, `ContrastAdjuster`, `ThemeVariant`, `ThemeColors`, `ResolvedTheme`, `ThemeResolver`, `ThemeMerger`, `DaySelection`, `ThemeStyle`) brauchen keine Glossarzeile (Übersicht, Abstimmung Punkt 10). Datensatz `ThemeRecord`.
- **iCloud-Regeln (ADR-0002/0012):** `ThemeRecord` ohne `.unique`, jede Eigenschaft mit Vorgabe oder optional; Eindeutigkeit sichert das Zusammenführen (Task 4, Task 5).
- **Freischaltung (FR-13):** neuer Fall `PaidFeature.appearance`. Ohne Kauf gilt überall der Standard (warm, Standard-Akzent, Hell/Dunkel wie das System), auch wenn ein abgeglichener Datensatz etwas anderes sagt; der Datensatz bleibt unberührt (Entscheidung 8).
- **Zweitbildschirm folgt dem Erscheinungsbild nicht (FR-16).** Klassenbildschirm, Tafel und Kaufangebot bleiben unverändert (Q-37, Q-38, Q-39).
- **Wortlaut (UI-15):** „du“ im Imperativ, Tasten Verb zuerst, Aussagen als Zustand („Entfällt“, „Vertretung“, „Ohne Material“, „Material nicht verfügbar“, „Keine Stunde“). Uhrzeiten nur über `Date.FormatStyle` mit `.monospacedDigit()`, nie `String(format: "%d:%02d")`. Dateinamen `.truncationMode(.middle)`. Alle Texte in `Frontstage/Resources/Localizable.xcstrings` (Schlüssel englisch, Wert deutsch, `"state": "translated"`).
- **Design-Takt:** Jeder UI-Task trägt `Design-Takt: Hauptstufe` – vor dem Editieren den projektlokalen Skill `apple-design` laden (fehlt er: `npx skills add dickwu/apple-design-skill --skill apple-design -y`); nie `impeccable` oder `web-design-guidelines`. Die Beschlüsse stehen in DESIGN.md; **kein Task erfindet einen neuen Gestaltungsbeschluss.** Stößt ein Task auf eine Lücke, folgt er der nächstliegenden Regel aus DESIGN.md und nennt die Lücke in einer Zeile im Abschlussbericht. DESIGN.md wird in diesem Teilplan nicht geändert.
- **Testdaten:** Klassen `8b`, `9c`, `7a`; Fächer `Englisch`, `Deutsch`, `Mathe`; Material „Arbeitsblatt Vokabeln.pdf“, „Unit 3 Präsentation.pptx“; Tag Di 17.11.2026 (`Fixtures.tue17`, Zeitraster `Fixtures.bellSchedule`).

## Entscheidungen dieses Teilplans (mit Begründung)

1. **Signalsymbole hängen nur am Grundton, nie am gewählten Akzent.** Gerechnet wird gegen Hintergrund, Auswahlfläche und die Tönung des *Standard*-Akzents dieses Grundtons. *Grund:* FR-16.1 „Signalfarben … bleiben fest“, AK-53 „behalten ihre Farbe“, UI-11 „je Grundton eine eigene Verschiebung“. *Verworfen:* gegen die Tönung des gewählten Akzents rechnen – dann würde z. B. ein gelber Akzent im dunklen Modus das Rot verschieben (gemessen `#FF453A` → `#FF5045`).
2. **Ausgangswerte der Signalsymbole sind die UI-11-Werte** (`#ED372D`/`#B86B00` hell), nicht die Systemfarben. *Grund:* Damit reproduziert der Standard die beschlossenen Werte exakt; gemessen erfüllen sie in allen vier Grundtönen schon ≥ 3:1 (warm 3,12/3,14, System 3,23/3,25, kühl 3,14/3,16, Petrol 3,13/3,16), die Verschiebung greift also nur bei „Kontrast erhöhen“. Eine Neuberechnung aus `#FF3B30` ergäbe `#F2382E` statt `#ED372D` (das Mockup hatte etwas Abstand zu 3:1).
3. **Ein Akzentton je Variante** (≥ 4,5:1, erfüllt damit auch 3:1 für Symbole) statt getrennter Text- und Symboltöne. *Grund:* YAGNI; die Tönung bleibt der zweite Ton („ein Akzent kann in einem Modus zwei Töne haben“, UI-9).
4. **Tönung aus dem gewählten Akzent, Akzentton verschoben** (UI-9). Mischen in 8-Bit-Ganzzahlen: `(a·p + b·(100−p) + 50) / 100`. *Grund:* nur so ergibt sich exakt `#273A38` (Gleitkomma rundet 57,5 auf 57 → `#273938`).
5. **Verschiebung:** hell = alle Kanäle mit Faktor k ≤ 1 skalieren (Richtung Schwarz), dunkel = Richtung Weiß mischen; größtes k bzw. kleinstes t, das das Ziel gegen die ungünstigste Fläche erreicht. *Grund:* Kanalskalierung ist genau das, was das Mockup für `#FF3B30` → `#ED372D` getan hat (alle Kanäle × 0,93); der Farbton bleibt erhalten.
6. **„Kontrast erhöhen“ (Lücke):** UI-8 verlangt eine Fassung je Rolle für hohen Kontrast, nennt aber keine Werte. Nächstliegende Regel: dieselbe Verschiebung mit dem nächsten WCAG-Ziel (Akzent 7:1, Signale 4,5:1; UI-8 nennt „Ziel ≥ 7:1“), neutrale Töne unverändert (sie erreichen schon 12,6–16,3:1), Haarlinie mit doppelter Deckkraft (höchstens 1). Im Abschlussbericht als Lücke nennen.
7. **Ein `ThemeRecord`, zuletzt geschrieben gewinnt.** Zwei Geräte, die offline je einen anlegen: Zusammenführen behält den ältesten Datensatz (wie alle Modelle) mit dem Inhalt des zuletzt geänderten (`updatedAt`). `DataStore.theme()` liest vor dem Zusammenführen schon den zuletzt geänderten. *Grund:* Area daten, Nebenläufigkeit („zuletzt abgeglichener Stand gilt“); deterministisch auf beiden Geräten.
8. **Freischaltung beim Anwenden, nicht beim Speichern:** `Theme.effective(isUnlocked:)` liefert ohne Kauf `.standard`. Einrichten › Erscheinungsbild zeigt ohne Kauf das Kaufangebot statt der Auswahl (AK-52), die gespeicherte Wahl bleibt. *Kosten:* Beim Start ist `Unlock.isUnlocked` bis zur ersten StoreKit-Antwort `false` – ein gekauftes Erscheinungsbild erscheint einen Moment im Standard. Hingenommen, weil der Kaufstand nirgends gespeichert werden darf (Area plattform, Kauf).
9. **Angewendet in `RootView`, außerhalb von `DataScopedRoot`.** *Grund:* Einrichten (auch Einrichten › Erscheinungsbild) liegt außerhalb; `RootView` liest `dataLocation.store` und dessen `revision` direkt.
10. **`.fontDesign(.rounded)` an jedem Tab-Inhalt, nicht an der `TabView`.** *Grund:* UI-7 – Tab-Leiste, Werkzeugleiste und Menüs bleiben SF Pro.
11. **Schriftgrößen über `@ScaledMetric`** (Modifier `scaledFont(_:relativeTo:)`). *Grund:* UI-6 nennt `Font.system(size:relativeTo:)` – diese API gibt es in SwiftUI nicht (nur `Font.custom(_:size:relativeTo:)`); `@ScaledMetric(relativeTo:)` ist die gleichwertige, in UI-6 ebenfalls genannte Form. Zeilen haben deshalb **Mindesthöhe** 44 pt (skaliert), nicht feste Höhe, damit große Dynamic-Type-Stufen auf Scrollen zurückfallen (UI-4, UI-6).
12. **Auswahlregel im Kern (`DaySelection`).** Neu bestimmt beim Öffnen (Modell entsteht), bei „Heute“/Tageswechsel und wenn die App an einem neuen Kalendertag aktiv wird; eine von Hand gewählte Stunde (auch „keine“ nach Zurück in schmaler Breite) bleibt, bis die Lehrkraft wechselt. *Verworfen:* bei jedem `onAppear` neu wählen – in schmaler Breite erscheint die Liste nach „Zurück“ erneut, die Automatik würde das Detail sofort wieder öffnen (Schleife); bei jeder Rückkehr in die App neu wählen – nach dem Bearbeiten in PowerPoint spränge die Auswahl weg.
13. **Uhrzeiten werden in der App formatiert** (`LessonTimeFormat`, `Date.IntervalFormatStyle`), nicht im Kern. *Grund:* UI-15 verlangt Gerätesprache und 12/24-Stunden-Einstellung; der Kern kennt keine Locale und soll unter Windows nicht von Locale-Daten abhängen.
14. **Grundton System heißt Systemfarben ganz:** keine eigene Zeilenauswahl-Fläche, keine eigenen Hintergründe – UI-5 unverändert. Nur Akzent, Tönung und Signale werden gegen die Bezugswerte gerechnet.
15. **Material-Aktionen bleiben im Kontextmenü der Kachel** („In die nächste Stunde“, „Neu verknüpfen“), Stunden-Aktionen werden Kapselknöpfe im Detail („Ausfall markieren“ / „Ausfall aufheben“, „Material weiterreichen“), die Tafel eine Kachel. Alles aus `DayRowActions` bleibt erreichbar.

## Review Focus

1. **Lehrkraft wählt von Hand eine andere Stunde, dann beginnt die nächste Stunde** → die gewählte bleibt; nach „Heute“ oder am nächsten Morgen wählt die App wieder selbst; nach „Zurück“ in schmaler Breite öffnet sich das Detail nicht von selbst wieder. Tests: Task 3 `manualSelectionSurvivesLessonChange`, `manualDeselectStaysNil`, `resetReturnsToAutomatic`; Task 8 `newCalendarDayResetsSelection`.
2. **Extreme Akzentfarbe (Weiß, Schwarz, helles Gelb, Signalrot) in jedem Grundton, hell und dunkel** → Akzentton ≥ 4,5:1 gegen jede Fläche, Signale unverändert, Rechnung terminiert. Tests: Task 2 `everyBaseToneMeetsFR161`, `customAccentDoesNotMoveSignals`; Task 1 `impossibleTargetEndsAtBlackOrWhite`.
3. **Datensatz vom gekauften Gerät kommt auf ein Gerät ohne Kauf (oder Kauf erstattet)** → App zeigt den Standard, der Datensatz bleibt unverändert, Laden schreibt nichts. Tests: Task 2 `effectiveWithoutUnlockIsStandard`; Task 7 `loadingDoesNotWrite`.
4. **Zwei Geräte ändern das Erscheinungsbild offline** → nach dem Abgleich ein Datensatz mit dem zuletzt geänderten Inhalt; ein Gerät mit älterer App-Version lässt den Ordner `Theme/` unberührt. Tests: Task 4 `keepsOldestRecordWithNewestContent`; Task 5 `mergeDuplicatesKeepsNewestTheme`, `themeReadsNewestBeforeMerge`.
5. **Tag ohne Zeitraster oder nur mit Ausfällen** → Auswahl fällt auf die erste Stunde, keine „Jetzt“-Kapsel, kein Absturz. Tests: Task 3 `withoutTimesSelectsFirst`, `allCancelledSelectsFirstLesson`, `runningLessonOnlyWhileRunning`.

---

## Dateistruktur

| Datei | Verantwortung | Task |
|---|---|---|
| `Packages/FrontstageCore/Sources/FrontstageCore/Theme/SRGBColor.swift`, `ContrastAdjuster.swift` | sRGB, Leuchtdichte, Kontrast, Mischen, Verschiebung | 1 |
| `…/Theme/Theme.swift`, `BaseTone.swift`, `ThemeResolver.swift` | Erscheinungsbild-Werte, Grundton-Paletten, Rollenfarben je Variante | 2 |
| `…/DayView/DaySelection.swift` | Auswahl der laufenden/nächsten Stunde, Handauswahl, „Jetzt“ | 3 |
| `…/DataFolder/ThemePayload.swift`; `SyncModel.swift`, `RecordPayload.swift` (ändern); `…/Theme/ThemeMerger.swift` | Datenordner-Format, Zusammenführen | 4 |
| `Packages/FrontstageCore/Tests/FrontstageCoreTests/Theme/*Tests.swift`, `…/DayView/DaySelectionTests.swift`; `…/DataFolder/RecordFormatTests.swift` (ändern) | Kern-Tests | 1–4 |
| `Frontstage/Data/Records/ThemeRecord.swift`, `Frontstage/Data/DataStore+Theme.swift`; `ModelContainerFactory.swift`, `Folder/RecordCodec.swift`, `DataStore+Merge.swift`, `docs/ARCHITECTURE.md` (ändern) | Datensatz, Abgleich, Zusammenführen, Doku | 5 |
| `Frontstage/UI/Theme/ThemeStyle.swift`, `PlatformColors.swift`, `ScaledFont.swift`, `ThemedButtonStyles.swift`, `AppThemeModifier.swift`; `Purchase/PaidGate.swift`, `App/RootView.swift` (ändern) | Theming-Grundlage, Anwenden | 6 |
| `Frontstage/UI/Setup/AppearanceSettingsModel.swift`, `AppearanceSettingsView.swift`, `ThemePreview.swift`; `SetupView.swift` (ändern) | Einrichten › Erscheinungsbild | 7 |
| `Frontstage/UI/DayView/LessonStatement.swift`, `DayEmptyState.swift`, `Frontstage/UI/Shared/LessonTimeFormat.swift`; `App/AppEnvironment.swift`, `DayViewModel.swift`, `SecondScreen/SecondScreenState.swift` (ändern) | Logik der Tagesansicht | 8 |
| `Frontstage/UI/DayView/DayListRow.swift`, `MaterialTile.swift`, `SignalCapsule.swift`, `StatementView.swift`, `OrphanMaterialRow.swift`; `DayViewLayout.swift`, `SourceStatusBar.swift` (ändern) | Bausteine der Tagesansicht | 9 |
| `Frontstage/UI/DayView/DayLessonDetail.swift`; `DayView.swift`, `DayViewLayout.swift` (ändern), `DayRowView.swift` (löschen) | Liste und Detail zusammensetzen | 10 |
| `PreparationView.swift`, `LessonDetailView.swift`, `CoursePlanView.swift`, `Setup/*View.swift`, `Shared/PlanHintLabel.swift` (ändern) | Grundton und Schrift app-weit | 11 |
| `FrontstageTests/Data/ThemeStoreTests.swift`, `FrontstageTests/UI/AppearanceSettingsModelTests.swift`, `ThemeColorConversionTests.swift`, `DayViewSelectionTests.swift`, `LessonTimeFormatTests.swift`, `LessonStatementTests.swift`, `DayEmptyStateTests.swift`; `RecordCodecTests.swift`, `RecordSchemaTests.swift`, `SecondScreenStateTests.swift`, `TestSupport/UIFixtures.swift` (ändern); `FrontstageTests/UI/DayViewLayoutTests.swift` (löschen) | App-Tests (Simulator) | 5–10 |
| `Frontstage/Resources/Localizable.xcstrings` (ändern) | Texte | 7–10 |

---

### Task 1: Farbrechnung – sRGB, Kontrast, Mischen, Verschiebung

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Theme/SRGBColor.swift`, `Packages/FrontstageCore/Sources/FrontstageCore/Theme/ContrastAdjuster.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/Theme/SRGBColorTests.swift`, `Packages/FrontstageCore/Tests/FrontstageCoreTests/Theme/ContrastAdjusterTests.swift`

**Interfaces:**
- Consumes: –
- Produces:

```swift
/// sRGB-Farbe mit 8-Bit-Kanälen; Deckkraft nur für Haarlinien (Kontrast rechnet ohne Deckkraft).
public struct SRGBColor: Hashable, Codable, Sendable {
  public let red: Int; public let green: Int; public let blue: Int   // 0...255 (precondition)
  public let alpha: Double                                            // 0...1, Vorgabe 1
  public init(red: Int, green: Int, blue: Int, alpha: Double = 1)
  public init?(hex: String)          // "#0E6B7A", "0e6b7a"; sonst nil
  public var hex: String { get }     // "#0E6B7A" (Großbuchstaben, ohne Deckkraft)
  public var relativeLuminance: Double { get }   // WCAG 2.x, Grenzwert 0.04045
  public static func contrastRatio(_ a: SRGBColor, _ b: SRGBColor) -> Double   // (hell+0.05)/(dunkel+0.05)
  public func minimumContrast(against surfaces: [SRGBColor]) -> Double         // ungünstigste Fläche; leer → .infinity
  /// Deckend: `percent` Prozent dieser Farbe über `background`, Ganzzahlrechnung (Entscheidung 4), alpha 1.
  public func mixed(over background: SRGBColor, percent: Int) -> SRGBColor
  public func withAlpha(_ alpha: Double) -> SRGBColor
}
public enum ContrastDirection: Sendable { case darken, lighten }
public enum ContrastAdjuster {
  /// Unverändert, wenn `color` schon reicht; sonst kleinste Verschiebung (Entscheidung 5).
  public static func adjusted(_ color: SRGBColor, against surfaces: [SRGBColor], minimum: Double,
                              direction: ContrastDirection) -> SRGBColor
}
```

Algorithmus (nicht durch Signatur und Tests festgelegt; `rounded()` = kaufmännisch, wie Swift-Vorgabe):

```swift
// darken: candidate(k) = (red·k, green·k, blue·k).rounded(); größtes k in [0, 1] mit minimumContrast ≥ minimum
// lighten: candidate(t) = (c + (255 − c)·t).rounded() je Kanal; kleinstes t in [0, 1]
// Binärsuche, 30 Schritte; Ergebnis ist candidate(lo) bzw. candidate(hi) – der Rand, der das Ziel erfüllt.
// Erreicht selbst k = 0 (Schwarz) bzw. t = 1 (Weiß) das Ziel nicht: Schwarz bzw. Weiß zurückgeben.
```

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("Theme Color") struct SRGBColorTests`, `@Suite("Theme Contrast") struct ContrastAdjusterTests`; Kurzform `c(_ hex: String) -> SRGBColor` = `SRGBColor(hex:)!` je Datei privat)

```swift
@Test("Hex lesen und schreiben") func parsesAndFormatsHex() {
  #expect(SRGBColor(hex: "#0E6B7A") == SRGBColor(red: 14, green: 107, blue: 122))
  #expect(SRGBColor(hex: "0e6b7a")?.hex == "#0E6B7A")
  #expect(SRGBColor(hex: "#0E6B7") == nil && SRGBColor(hex: "#GGGGGG") == nil && SRGBColor(hex: "") == nil)
}
@Test("Schwarz/Weiß: Leuchtdichte 0 und 1, Kontrast 21:1, symmetrisch") func blackWhiteContrast()
@Test("UI-8: warmer Text auf Grund 16,3:1 hell und 16,2:1 dunkel") func warmTextContrast() {
  #expect(abs(SRGBColor.contrastRatio(c("#1F1A14"), c("#FBF8F2")) - 16.29) < 0.01)
  #expect(abs(SRGBColor.contrastRatio(c("#F5EFE5"), c("#17130E")) - 16.16) < 0.01)
}
@Test("UI-9: Standard-Tönung #DAE4E1 hell und #273A38 dunkel (deckend, halb aufrunden)") func standardTint() {
  #expect(c("#0E6B7A").mixed(over: c("#FBF8F2"), percent: 14).hex == "#DAE4E1")
  #expect(c("#5FC2CF").mixed(over: c("#17130E"), percent: 22).hex == "#273A38")
}
@Test("Ausreichende Farbe bleibt unverändert") func unchangedWhenSufficient()      // #0E6B7A gegen [#FBF8F2, #ECE5D8, #DAE4E1], 4.5, .darken
@Test("AK-53: helles Gelb wird hell auf #6D6845 abgedunkelt") func darkensLightYellow() {
  let surfaces = [c("#FBF8F2"), c("#ECE5D8"), c("#FFF3A0").mixed(over: c("#FBF8F2"), percent: 14)]
  let result = ContrastAdjuster.adjusted(c("#FFF3A0"), against: surfaces, minimum: 4.5, direction: .darken)
  #expect(result.hex == "#6D6845")
  #expect(result.minimumContrast(against: surfaces) >= 4.5)
}
@Test("Dunkler Akzent wird dunkel aufgehellt, knapp über dem Ziel") func lightensDarkAccent()
// #0E1B2A gegen [#17130E, #2F2921, Tönung 22 %], 4.5, .lighten → ≥ 4.5 und < 4.7 (gemessen #8A9198, 4,510)
@Test("Systemblau hell: knapp über 4,5:1, Farbton bleibt (Blau größter Kanal)") func adjustsSystemBlue()
// #0088FF gegen [#FBF8F2, #ECE5D8, Tönung 14 %] → ≥ 4.5 und < 4.6 (gemessen #0067C2, 4,508)
@Test("Unerreichbares Ziel endet bei Schwarz bzw. Weiß") func impossibleTargetEndsAtBlackOrWhite()
// minimum 30 → #000000 (.darken) bzw. #FFFFFF (.lighten)
```

- [ ] **Step 2: Rot belegen** – `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\swift-test.ps1 -Filter SRGBColorTests` → „cannot find 'SRGBColor' in scope“; dasselbe mit `-Filter ContrastAdjusterTests`.
- [ ] **Step 3: Implementieren** (Signaturen und Algorithmus oben).
- [ ] **Step 4: Grün belegen** – beide Filter, danach `scripts\swift-test.ps1` ohne Filter (alle Suites grün).
- [ ] **Step 5: Commit** – `git commit -m "core: add sRGB color math and contrast adjustment"`

---

### Task 2: Erscheinungsbild, Grundtöne, Rollenfarben (FR-16, FR-16.1, UI-8, UI-9, UI-11, UI-12)

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/Theme/Theme.swift`, `BaseTone.swift`, `ThemeResolver.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/Theme/ThemeTests.swift`, `ThemeResolverTests.swift`

**Interfaces:**
- Consumes: `SRGBColor`, `ContrastAdjuster` (1)
- Produces:

```swift
public enum BaseTone: String, CaseIterable, Codable, Sendable { case warm, system, cool, petrol }
public enum AppearanceMode: String, CaseIterable, Codable, Sendable { case system, light, dark }
public struct ThemeAccent: Hashable, Codable, Sendable {
  public let color: SRGBColor
  public init(color: SRGBColor); public init?(hex: String); public var hex: String { get }
}
public struct Theme: Hashable, Codable, Sendable {
  public var baseTone: BaseTone; public var accent: ThemeAccent?   // nil = Standard-Akzent
  public var appearanceMode: AppearanceMode
  public init(baseTone: BaseTone, accent: ThemeAccent?, appearanceMode: AppearanceMode)
  public static let standard: Theme                                 // warm, nil, system
  public var isStandard: Bool { get }
  /// FR-13: ohne Kauf gilt der Standard (Entscheidung 8).
  public func effective(isUnlocked: Bool) -> Theme
}
public struct NeutralColors: Hashable, Sendable { public var background, selection, text, hairline: SRGBColor }
extension BaseTone {
  public func neutrals(isDark: Bool) -> NeutralColors    // Werte aus den Global Constraints
  public var usesSystemColors: Bool { get }              // nur .system
}
public struct ThemeVariant: Hashable, Sendable, CaseIterable {
  public var isDark: Bool; public var isHighContrast: Bool
  public static let light, dark, lightHighContrast, darkHighContrast: ThemeVariant
  public static var allCases: [ThemeVariant] { get }     // [light, dark, lightHighContrast, darkHighContrast]
}
public struct ThemeColors: Hashable, Sendable {
  public var background, selection, text, hairline: SRGBColor
  public var accent: SRGBColor          // korrigierter Ton für Text und Symbole in Akzentfarbe
  public var accentTint: SRGBColor      // deckende Tönung der Kacheln und Aktionen
  public var cancellationSymbol: SRGBColor, unavailableSymbol: SRGBColor
  public var nowFill: SRGBColor, nowText: SRGBColor
}
public struct ResolvedTheme: Hashable, Sendable {
  public let usesSystemNeutrals: Bool
  public func colors(_ variant: ThemeVariant) -> ThemeColors
  public func isAccentAdjusted(_ variant: ThemeVariant) -> Bool   // accent != gewählter Rohwert
}
public enum ThemeResolver {
  public static let standardAccentLight: SRGBColor, standardAccentDark: SRGBColor   // #0E6B7A, #5FC2CF
  public static let tintPercentLight = 14, tintPercentDark = 22
  public static func resolve(_ theme: Theme) -> ResolvedTheme
}
```

Regel je Variante (in `resolve`): `n = baseTone.neutrals(isDark:)`; bei hohem Kontrast `hairline.alpha = min(1, 2 · alpha)`. Roh-Akzent = `theme.accent?.color` oder Standard je Modus; `accentTint = roh.mixed(over: n.background, percent: 14 | 22)`; `accent = ContrastAdjuster.adjusted(roh, against: [n.background, n.selection, accentTint], minimum: hc ? 7 : 4.5, direction: isDark ? .lighten : .darken)`. Signale: Ausgangswerte UI-11 je Modus, verschoben gegen `[n.background, n.selection, Standard-Akzent.mixed(over: n.background, …)]` mit `minimum: hc ? 4.5 : 3`, gleiche Richtung (Entscheidungen 1, 2). `nowFill` `#FFC94A`, `nowText` `#1F1A14` in jeder Variante.

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("Theme Values") struct ThemeTests`, `@Suite("Theme Resolver") struct ThemeResolverTests`)

```swift
// ThemeTests
@Test("FR-16: Standard ist warm, Standard-Akzent, wie das System") func standardTheme()
@Test("Rohwerte laut Glossar") func rawValuesFollowGlossary()
// BaseTone.allCases.map(\.rawValue) == ["warm","system","cool","petrol"]; AppearanceMode … == ["system","light","dark"]
@Test("FR-13: ohne Kauf gilt der Standard, mit Kauf die Wahl") func effectiveWithoutUnlockIsStandard() {
  let cool = Theme(baseTone: .cool, accent: ThemeAccent(hex: "#FFF3A0"), appearanceMode: .dark)
  #expect(cool.effective(isUnlocked: false) == .standard)
  #expect(cool.effective(isUnlocked: true) == cool)
}
// ThemeResolverTests
@Test("UI-9: Standard warm – Tönung, Akzent unverändert, Kontraste wie gemessen") func standardWarmMatchesDesign() {
  let r = ThemeResolver.resolve(.standard)
  let l = r.colors(.light), d = r.colors(.dark)
  #expect(l.accentTint.hex == "#DAE4E1" && d.accentTint.hex == "#273A38")
  #expect(l.accent.hex == "#0E6B7A" && d.accent.hex == "#5FC2CF")
  #expect(abs(SRGBColor.contrastRatio(l.accent, l.accentTint) - 4.76) < 0.02)   // gemessen 4,751
  #expect(abs(SRGBColor.contrastRatio(d.accent, d.accentTint) - 5.81) < 0.05)   // gemessen 5,779
  #expect(abs(SRGBColor.contrastRatio(l.text, l.accentTint) - 13.3) < 0.05)      // UI-11 Kachel
  #expect(abs(SRGBColor.contrastRatio(d.text, d.accentTint) - 10.5) < 0.05)
  #expect(!r.isAccentAdjusted(.light) && !r.isAccentAdjusted(.dark))
}
@Test("UI-11: Signalsymbole in jedem Grundton wie beschlossen") func signalsMatchUI11ForEveryBaseTone()
// für alle BaseTone: light cancellation #ED372D, unavailable #B86B00; dark #FF453A, #FF9F0A
@Test("AK-53: gelber Akzent hell abgedunkelt (#6D6845), dunkel unverändert") func yellowAccentAdjustedInLightOnly() {
  let r = ThemeResolver.resolve(Theme(baseTone: .warm, accent: ThemeAccent(hex: "#FFF3A0"), appearanceMode: .system))
  #expect(r.colors(.light).accent.hex == "#6D6845" && r.isAccentAdjusted(.light))
  #expect(r.colors(.dark).accent.hex == "#FFF3A0" && !r.isAccentAdjusted(.dark))
  #expect(r.colors(.light).accentTint.hex == "#FCF7E7")
}
@Test("FR-16.1: eigener Akzent verschiebt keine Signalfarbe") func customAccentDoesNotMoveSignals()
// für alle BaseTone und Varianten: colors mit Akzent #FFF3A0 / #FF3B30 haben dieselben Signalfarben wie ohne Akzent
@Test("FR-16.1: jeder Grundton, jede Variante, extreme Akzente erreichen die Ziele") func everyBaseToneMeetsFR161()
// Akzente nil, #FFFFFF, #000000, #FFF3A0, #FF3B30, #0088FF; je Variante v, Flächen [background, selection, accentTint]:
// accent.minimumContrast ≥ (v.isHighContrast ? 7 : 4.5); beide Signale gegen [background, selection] und die
// Tönung des Standard-Akzents ≥ (v.isHighContrast ? 4.5 : 3) – nicht gegen die Tönung des eigenen Akzents (Entscheidung 1)
@Test("Kontrast erhöhen: Akzent ≥ 7:1, Haarlinie doppelt deckend") func highContrastRaisesTargets()
// warm: lightHighContrast.hairline.alpha == 0.44; darkHighContrast.hairline.alpha == 1.0; neutrale Töne wie .light/.dark
@Test("UI-12: Gelb und dunkles Wort fest, etwa 11:1") func nowColorsAreFixed()
// alle Varianten nowFill #FFC94A, nowText #1F1A14, Kontrast > 11
@Test("UI-8: Paletten aus DESIGN.md; nur System nutzt Systemfarben") func palettesFromDesign()
// cool hell background #F7F9FC, petrol dunkel selection #15292C, warm hell hairline (92,72,48,0.22); usesSystemNeutrals nur bei .system
```

- [ ] **Step 2: Rot belegen** – `…swift-test.ps1 -Filter ThemeTests`, dann `-Filter ThemeResolverTests`.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Grün belegen** – beide Filter, danach das ganze Paket.
- [ ] **Step 5: Commit** – `git commit -m "core: add theme values, base tone palettes and resolver"`

---

### Task 3: Auswahl der Stunde in der Tagesansicht (UI-3, UI-12)

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/DayView/DaySelection.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/DayView/DaySelectionTests.swift`

**Interfaces:**
- Consumes: `Lesson`, `LessonKey`, `TimeOfDay`, `ClassScreenCalculator.phase(now:lessons:)`, `ClassScreenPhase.runningLessonKey` (01, 07)
- Produces:

```swift
/// `now == nil`: der angezeigte Tag ist nicht heute.
public struct DaySelection: Hashable, Sendable {
  public private(set) var selected: LessonKey?
  public private(set) var isManual: Bool
  public init()
  /// Neuer Stand oder Minutentakt: Handauswahl bleibt, solange es die Stunde gibt (Handauswahl `nil` bleibt `nil`);
  /// sonst automatisches Ziel.
  public mutating func update(lessons: [Lesson], now: TimeOfDay?)
  /// Von Hand: `isManual = (key != automaticTarget)`.
  public mutating func select(_ key: LessonKey?, lessons: [Lesson], now: TimeOfDay?)
  /// Tageswechsel, „Heute“, neuer Kalendertag: zurück zur Automatik (danach `update`).
  public mutating func reset()
  /// Laufende, sonst nächste Stunde ohne Ausfall; nach der letzten die letzte ohne Ausfall; ohne Zeiten oder
  /// an einem anderen Tag die erste ohne Ausfall; nur Ausfälle → die erste; keine Stunden → nil.
  public static func automaticTarget(lessons: [Lesson], now: TimeOfDay?) -> LessonKey?
  /// Nur während einer Stunde ohne Ausfall (Pause, vor der ersten, nach der letzten: nil).
  public static func runningLesson(lessons: [Lesson], now: TimeOfDay) -> LessonKey?
}
```

- [ ] **Step 1: Failing Tests schreiben** (`@Suite("DayView Selection") struct DaySelectionTests`; Stunden über `CoreFixtures.lesson(_:_:period:from:to:cancelled:)`: 1. 8b Englisch 7:45–8:30, 2. 9c Deutsch 8:35–9:20, 3. 7a Mathe 9:40–10:25)

```swift
@Test("UI-3: laufende Stunde gewählt") func selectsRunningLesson()            // now 8:40 → 9c
@Test("In der Pause die nächste") func selectsNextDuringBreak()               // now 9:25 → 7a
@Test("Ausgefallene laufende Stunde wird übersprungen") func skipsCancelledRunningLesson()
@Test("Nach der letzten Stunde die letzte") func selectsLastAfterDayEnds()    // now 14:00 → 7a
@Test("Anderer Tag: erste Stunde") func otherDaySelectsFirst()                // now nil → 8b
@Test("Ohne Zeitraster: erste Stunde") func withoutTimesSelectsFirst()
// `Lesson(key:period:time: nil, isSubstituteLesson: false, isCancelled: false, cancellationOrigin: nil)` direkt anlegen –
// `CoreFixtures.lesson` setzt immer eine Zeit
@Test("Nur Ausfälle: erste Stunde") func allCancelledSelectsFirstLesson()
@Test("Handauswahl bleibt beim Stundenwechsel") func manualSelectionSurvivesLessonChange() {
  var s = DaySelection(); s.update(lessons: all, now: t(8, 40))
  s.select(key8b, lessons: all, now: t(8, 40))
  #expect(s.isManual)
  s.update(lessons: all, now: t(9, 45))
  #expect(s.selected == key8b)
}
@Test("Wahl der automatischen Stunde bleibt automatisch") func selectingAutomaticTargetStaysAutomatic()
// select(key9c) bei 8:40 → isManual false; update 9:45 → key7a
@Test("Zurück in schmaler Breite: keine Auswahl bleibt") func manualDeselectStaysNil()
// select(nil) → selected nil, isManual true; update 9:45 → nil
@Test("Verschwundene Handauswahl fällt auf die Automatik") func vanishedManualFallsBackToAutomatic()
@Test("reset kehrt zur Automatik zurück") func resetReturnsToAutomatic()
@Test("UI-12: Jetzt nur während einer Stunde") func runningLessonOnlyWhileRunning()
// 8:40 → 9c; 9:25 → nil; 7:00 → nil; laufende Stunde ausgefallen → nil
```

- [ ] **Step 2: Rot belegen** – `…swift-test.ps1 -Filter DaySelectionTests`.
- [ ] **Step 3: Implementieren** – `automaticTarget` nutzt `ClassScreenCalculator.phase`: `.inLesson`/`.finalMinutes`/`.upcoming` → deren Schlüssel; `.noMoreLessons` → hat irgendeine Stunde ohne Ausfall eine Zeit, die letzte nach Zeit, sonst die erste ohne Ausfall; gibt es keine Stunde ohne Ausfall, die erste Stunde (`allCancelledSelectsFirstLesson`; `phase` lässt Ausfälle weg und liefert dann `.noMoreLessons`). `now == nil` → ohne `phase` direkt die erste ohne Ausfall (bzw. die erste). `runningLesson` = `phase(…).runningLessonKey`.
- [ ] **Step 4: Grün belegen**, danach das ganze Paket.
- [ ] **Step 5: Commit** – `git commit -m "core: add day view lesson selection rule"`

---

### Task 4: Datenordner-Format und Zusammenführen des Erscheinungsbilds (ADR-0012)

Design-Takt: keiner

**Files:**
- Create: `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/ThemePayload.swift`, `Packages/FrontstageCore/Sources/FrontstageCore/Theme/ThemeMerger.swift`
- Modify: `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/SyncModel.swift` – `case theme = "Theme"` **hinten** anhängen; `Packages/FrontstageCore/Sources/FrontstageCore/DataFolder/RecordPayload.swift` – Fall `theme(ThemePayload)` in Enum, `model`, `encode(to:)`, `init(model:from:)` (`attachments`, `parentID`: keine)
- Modify (Test): `Packages/FrontstageCore/Tests/FrontstageCoreTests/DataFolder/RecordFormatTests.swift`
- Test: `Packages/FrontstageCore/Tests/FrontstageCoreTests/Theme/ThemeMergerTests.swift`

**Interfaces:**
- Consumes: `RecordPayload`, `SyncModel`, `DataFolderCoding` (08)
- Produces:

```swift
public struct ThemePayload: Codable, Hashable, Sendable {
  public var createdAt: Date; public var baseToneRaw: String; public var accentHex: String?
  public var appearanceModeRaw: String; public var updatedAt: Date
  public init(createdAt: Date, baseToneRaw: String, accentHex: String?, appearanceModeRaw: String, updatedAt: Date)
}
public struct ThemeMergeEntry: Hashable, Sendable {
  public let id: UUID; public let createdAt: Date; public let updatedAt: Date
  public init(id: UUID, createdAt: Date, updatedAt: Date)
}
public struct ThemeMergePlan: Hashable, Sendable {
  public let keeperID: UUID?; public let contentSourceID: UUID?; public let deletions: [UUID]
  public var isEmpty: Bool { get }                      // deletions.isEmpty
}
public enum ThemeMerger {
  /// Behalten: ältester (`createdAt`, bei Gleichstand kleinere `uuidString`); Inhalt: zuletzt geänderter
  /// (`updatedAt`, bei Gleichstand der Behaltene); löschen: alle anderen. Ein oder kein Eintrag → leerer Plan.
  public static func plan(for entries: [ThemeMergeEntry]) -> ThemeMergePlan
}
```

- [ ] **Step 1: Failing Tests schreiben**

```swift
// RecordFormatTests (Suite „DataFolder Format“): Hülle mit .theme hin und zurück; applyOrder endet mit .theme
@Test("FR-16: Erscheinungsbild hin und zurück") func themePayloadRoundTrips()
// ThemePayload(createdAt: created, baseToneRaw: "cool", accentHex: "#FFF3A0", appearanceModeRaw: "dark", updatedAt: created)
@Test("Theme hängt hinten an, die zwölf bisherigen behalten ihre Reihenfolge") func themeAppendedLast() {
  #expect(SyncModel.applyOrder.last == .theme)
  #expect(SyncModel.applyOrder.count == 13)
  #expect(SyncModel(rawValue: "Theme") == .theme)
}
// ThemeMergerTests (@Suite("Theme Merge") struct ThemeMergerTests)
@Test("Ein Datensatz: nichts zu tun") func singleRecordNeedsNothing()
@Test("Zwei Geräte: ältester bleibt, Inhalt des zuletzt geänderten") func keepsOldestRecordWithNewestContent()
@Test("Gleiche Anlagezeit: kleinere Kennung bleibt") func tieOnCreatedAtUsesSmallerID()
```

- [ ] **Step 2: Rot belegen** – `…swift-test.ps1 -Filter RecordFormatTests`, dann `-Filter ThemeMergerTests`.
- [ ] **Step 3: Implementieren.** Vorhandene Tests der Suite bleiben unverändert grün.
- [ ] **Step 4: Grün belegen**, danach das ganze Paket (auch `RemoteLayoutTests`: der neue Ordner wird über `SyncModel(rawValue:)` erkannt).
- [ ] **Step 5: Commit** – `git commit -m "core: add theme payload and duplicate merge rule"`

---

### Task 5: `ThemeRecord`, Abgleich, Zusammenführen, `DataStore`-Methoden

Design-Takt: keiner

**Files:**
- Create: `Frontstage/Data/Records/ThemeRecord.swift`, `Frontstage/Data/DataStore+Theme.swift`
- Modify: `Frontstage/Data/ModelContainerFactory.swift` (`modelTypes` + `ThemeRecord.self` → 13), `Frontstage/Data/Folder/RecordCodec.swift` (`exportAll`, `export(_:from:)`-`switch`, `liveIDs`, privates `export(_ record: ThemeRecord)`, `upsert`, `delete`, `extension ThemeRecord: HasRecordID {}`; Doku-Kommentar „zwölf“ → „dreizehn“), `Frontstage/Data/DataStore+Merge.swift` (`LoadedRecords.themes`, Plan, Anwenden)
- Modify: `docs/ARCHITECTURE.md` – Area daten, Tabelle „Datenmodell“: Zeile `| Erscheinungsbild | Grundton, Akzentfarbe (sRGB-Hex, leer = Standard), Hell/Dunkel, Änderungszeit | FR-16; ein Datensatz für alle Geräte, doppelte werden zusammengeführt |`; Tabelle „Nebenläufigkeit“: `| Erscheinungsbild (zwei Geräte) | doppelte werden zusammengeführt; der Inhalt des zuletzt geänderten gilt | Wahl des anderen Geräts verloren – sichtbar, sofort korrigierbar |`; Area plattform, „Kauf“: „Freigeschaltet wird an genau einer Stelle („Freischaltung“), die Klassenbildschirm, Tafel und Erscheinungsbild abfragen. Ohne Kauf gilt der Standard des Erscheinungsbilds; eine gespeicherte Wahl bleibt erhalten und gilt, sobald der Kauf besteht (FR-13, FR-16).“; Area daten, Abschnitt „Datenort“, Liste „OneDrive-Abgleich“: Ordner `Theme/` im Datenordner, ein Gerät mit älterer Version lässt ihn unberührt; `## Changes` (Format der vorhandenen Zeilen `<area> changed — …`): `- 2026-11-15: daten changed — Erscheinungsbild als abgeglichener Datensatz (FR-16), Modell, Nebenläufigkeit und Ordner `Theme/` ergänzt; plattform changed — Freischaltung um das Erscheinungsbild ergänzt (FR-13)`.
- Modify (Test): `FrontstageTests/Data/Folder/RecordCodecTests.swift` (`populate(_:)` legt zusätzlich einen `ThemeRecord` mit allen Feldern an; `liveIDsCoverAllModels`: `exported.count == 13`; Testname des Rundlaufs „dreizehn Modelle“), `FrontstageTests/Data/RecordSchemaTests.swift` (ThemeRecord einfügen, speichern, zählen)
- Test: `FrontstageTests/Data/ThemeStoreTests.swift`

**Interfaces:**
- Consumes: `Theme`, `BaseTone`, `ThemeAccent`, `AppearanceMode` (2); `ThemePayload`, `ThemeMerger` (4)
- Produces:

```swift
@Model final class ThemeRecord {
  var id: UUID = UUID(); var createdAt: Date = Date.now
  var baseToneRaw: String = "warm"; var accentHex: String?; var appearanceModeRaw: String = "system"
  var updatedAt: Date = Date.now
  init() {}
}
extension ThemeRecord {
  /// Unbekannte Rohwerte → Standard des jeweiligen Felds; ungültiges Hex → Standard-Akzent.
  func makeTheme() -> Theme
  func apply(_ theme: Theme)          // setzt die drei Felder, nicht updatedAt
}
extension DataStore {
  /// Kein Datensatz → `.standard`; mehrere (vor dem Zusammenführen) → der mit dem neuesten `updatedAt`.
  func theme() throws -> Theme
  /// Schreibt in den ältesten Datensatz (legt ihn bei Bedarf an), `updatedAt = .now`, `saveAndBump()`.
  /// Gleicher Inhalt wie gespeichert → nichts schreiben.
  func setTheme(_ theme: Theme) throws
}
```

`mergeDuplicates()`: `let themePlan = ThemeMerger.plan(for: loaded.themes.map { ThemeMergeEntry(id: $0.id, createdAt: $0.createdAt, updatedAt: $0.updatedAt) })`; früher Ausgang nur, wenn **alle drei** Pläne leer sind. Anwenden vor Schritt 7 (Speichern): Felder und `updatedAt` von `contentSourceID` auf `keeperID` kopieren (wenn verschieden), dann `deletions` löschen. Rückgabewert bleibt `MergePlan`.

- [ ] **Step 1: Failing Tests schreiben** (`makeStore()` aus `FrontstageTests/Data/Fixtures.swift`)

```swift
@MainActor @Suite struct ThemeStoreTests {
  @Test("FR-16: ohne Datensatz gilt der Standard") func themeDefaultsToStandard() throws
  @Test("Speichern und Lesen ergibt dieselbe Wahl, ein Datensatz") func setThemeRoundTrips() throws
  @Test("Gleiche Wahl erneut speichern schreibt nichts") func unchangedThemeDoesNotSave() throws   // revision gleich
  @Test("Zwei Datensätze vor dem Zusammenführen: der zuletzt geänderte gilt") func themeReadsNewestBeforeMerge() throws
  @Test("Zusammenführen: ein Datensatz, Inhalt des zuletzt geänderten") func mergeDuplicatesKeepsNewestTheme() throws
  @Test("Nur das Erscheinungsbild doppelt: Zusammenführen läuft trotzdem") func themeMergeRunsWhenOtherPlansEmpty() throws
  @Test("Unbekannte Rohwerte ergeben den Standard des Felds") func unknownRawValuesFallBack() throws
}
// RecordCodecTests: vorhandener Rundlauf deckt ThemeRecord mit ab (Prüfsumme gleich nach export → upsert → export)
```

- [ ] **Step 2: Diff durchsehen** – jede Eigenschaft von `ThemeRecord` hin **und** zurück im Codec; kein `save()` im Codec; `ThemeRecord` ohne `.unique`, alle Felder mit Vorgabe oder optional; `modelTypes` enthält 13 Typen.
- [ ] **Step 3: Implementieren** (inkl. `docs/ARCHITECTURE.md`).
- [ ] **Step 4: Syntax prüfen** – `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\swift-parse.ps1` → keine `error:`-Zeile; Diff erneut durchsehen (Test läuft in Task 12).
- [ ] **Step 5: Commit** – `git commit -m "data: add synced theme record with merge and store methods"`

---

### Task 6: Theming-Grundlage und Anwenden in `RootView` (UI-5, UI-7, UI-8, UI-9, FR-16, FR-16.2)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/UI/Theme/PlatformColors.swift`, `Frontstage/UI/Theme/ThemeStyle.swift`, `Frontstage/UI/Theme/ScaledFont.swift`, `Frontstage/UI/Theme/ThemedButtonStyles.swift`, `Frontstage/UI/Theme/AppThemeModifier.swift`
- Modify: `Frontstage/Purchase/PaidGate.swift` – `case classScreen, timer, workMode, board, appearance` (Doku-Kommentar: Erscheinungsbild außerhalb des Standards, FR-13)
- Modify: `Frontstage/App/RootView.swift` – an der `TabView` `.appTheme(store: dataLocation.store, unlock: ClassroomServices.shared.unlock)`; in **jedem** Tab-Inhalt `.fontDesign(.rounded)` (am Ergebnis von `scoped { … }` bzw. an `setup`), nicht an der `TabView` (Entscheidung 10). Nichts aus 04–09 entfernen.
- Test: `FrontstageTests/UI/ThemeColorConversionTests.swift`

**Interfaces:**
- Consumes: `ThemeResolver`, `ResolvedTheme`, `ThemeColors`, `ThemeVariant`, `Theme.effective(isUnlocked:)`, `AppearanceMode` (2); `DataStore.theme()` (5); `Unlock` (07)
- Produces:

```swift
// PlatformColors.swift
extension SRGBColor { init(cgColor: CGColor) }   // nach sRGB konvertieren (`CGColorSpace.sRGB`), Kanäle auf 0...1 begrenzen, ×255 runden, alpha 1
extension Color { init(_ color: SRGBColor) }     // Color(.sRGB, red:green:blue:opacity:)
// ThemeStyle.swift
struct ThemeStyle: Equatable {
  let resolved: ResolvedTheme
  init(_ resolved: ResolvedTheme)
  var usesSystemNeutrals: Bool { get }
  var background: Color { get }; var selection: Color { get }; var text: Color { get }; var hairline: Color { get }
  var accent: Color { get }; var accentTint: Color { get }
  var cancellationSymbol: Color { get }; var unavailableSymbol: Color { get }
  var nowFill: Color { get }; var nowText: Color { get }
}
extension EnvironmentValues { @Entry var themeStyle = ThemeStyle(ThemeResolver.resolve(.standard)) }
// ScaledFont.swift – Schriftskala UI-6 (Größe → Systemstil für Dynamic Type)
enum TypeScale {
  case detailTitle      // 34, .largeTitle
  case materialName     // 20, .title3
  case topic            // 20, .title3
  case listTitle        // 18, .body
  case action           // 15, .subheadline
  case detailMeta       // 13, .footnote
  case listMeta         // 11, .caption2
  case fileType         // 11, .caption2
  var size: CGFloat { get }; var textStyle: Font.TextStyle { get }
}
extension View { func scaledFont(_ scale: TypeScale) -> some View }   // @ScaledMetric(relativeTo:) im Modifier,
// `.font(.system(size:design:))` mit `design` aus `@Environment(\.fontDesign)`; kein Fett (UI-6)
// ThemedButtonStyles.swift – UI-9, UI-10, UI-14
struct TileButtonStyle: ButtonStyle          // RoundedRectangle(cornerRadius: 16, style: .continuous) in accentTint, kein Rahmen/Schatten; gedrückt: opacity 0.7
struct CapsuleActionButtonStyle: ButtonStyle // Capsule in accentTint, Label accent, scaledFont(.action), minHeight 44, Innenrand 16 waagrecht; gedrückt: opacity 0.7
// AppThemeModifier.swift
extension AppearanceMode { var colorScheme: ColorScheme? { get } }   // system → nil
extension View { func appTheme(store: DataStore, unlock: Unlock) -> some View }
```

Swift-Hinweise für den Implementierer (auch als Kommentar übernehmen):
- **Dynamische Farbe:** Jede `ThemeStyle`-Farbe ist **eine** `Color`, die sich bei hell/dunkel und „Kontrast erhöhen“ selbst umstellt – iOS `Color(uiColor: UIColor { traits in … })` mit `traits.userInterfaceStyle == .dark` und `traits.accessibilityContrast == .high`; macOS `Color(nsColor: NSColor(name: nil) { appearance in … })` mit `appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua])`. Die Closure ist `@Sendable`: nur `ResolvedTheme` (Sendable) einfangen. So greift `.preferredColorScheme` ohne weiteren Code, auch in Sheets.
- **Systemneutrale (Grundton System, Entscheidung 14):** `background`/`selection`/`text`/`hairline` liefern iOS `.systemBackground`/`.systemGray5`/`.label`/`.separator`, macOS `.windowBackgroundColor`/`.unemphasizedSelectedContentBackgroundColor`/`.labelColor`/`.separatorColor`.
- **Haarlinie** mit Deckkraft: `UIColor(red:green:blue:alpha:)` mit `SRGBColor.alpha`.
- `appTheme`: liest `store.revision` (damit ein Abgleich neu zeichnet) und `unlock.isUnlocked`, berechnet `((try? store.theme()) ?? .standard).effective(isUnlocked:)`, setzt `.environment(\.themeStyle, ThemeStyle(ThemeResolver.resolve(effective)))`, `.tint(style.accent)` und `.preferredColorScheme(effective.appearanceMode.colorScheme)`. Glas-Leisten werden nicht eingefärbt (UI-8).

- [ ] **Step 1: Failing Tests schreiben**

```swift
@Suite struct ThemeColorConversionTests {
  @Test("sRGB-Rot aus CGColor ergibt #FF0000") func srgbRedConverts()
  @Test("Display-P3-Grün außerhalb von sRGB wird begrenzt, nie außerhalb 0...255") func p3IsClamped()
  @Test("Gelb #FFC94A über CGColor hin und zurück bleibt gleich") func roundTripKeepsHex()
  @Test("Hell/Dunkel: system → nil, light → .light, dark → .dark") func appearanceModeMapsToColorScheme()
}
```

- [ ] **Step 2: Skill laden** – `apple-design` (Hauptstufe); prüfen gegen HIG color, dark-mode, accessibility (Kontrast erhöhen), typography (Dynamic Type).
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Syntax prüfen** (`scripts\swift-parse.ps1`), Diff durchsehen: `RootView` behält alles aus 04–09; `.fontDesign(.rounded)` nicht an der `TabView`; `PaidFeature` hat fünf Fälle; vorhandene `switch` über `PaidFeature` (falls vorhanden, `rg "PaidFeature" Frontstage`) ergänzen.
- [ ] **Step 5: Commit** – `git commit -m "ui: theme style environment with dynamic colors, rounded type scale and app theme"`

---

### Task 7: Einrichten › Erscheinungsbild (FR-16, FR-16.1, FR-16.2, AK-52–AK-54)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/UI/Setup/AppearanceSettingsModel.swift`, `Frontstage/UI/Setup/AppearanceSettingsView.swift`, `Frontstage/UI/Setup/ThemePreview.swift`
- Modify: `Frontstage/UI/Setup/SetupView.swift` – eigene `Section` direkt vor der Kauf-Section: `NavigationLink("setup.appearance.title") { scoped { AppearanceSettingsScreen() } }`
- Modify: `Frontstage/Resources/Localizable.xcstrings`
- Test: `FrontstageTests/UI/AppearanceSettingsModelTests.swift`

**Interfaces:**
- Consumes: `DataStore.theme()`/`setTheme(_:)` (5); `ThemeResolver` (2); `ThemeStyle`, `SRGBColor(cgColor:)`, `Color(_ srgb:)`, `TileButtonStyle`, `CapsuleActionButtonStyle`, `PaidFeature.appearance` (6); `PaidGate`, `PurchaseOfferView` (07)
- Produces:

```swift
@MainActor protocol ThemeStore: AnyObject {
  var revision: Int { get }
  func theme() throws -> Theme
  func setTheme(_ theme: Theme) throws
}
extension DataStore: ThemeStore {}
@MainActor @Observable final class AppearanceSettingsModel {
  init(store: any ThemeStore)                 // lädt, schreibt nie
  private(set) var theme: Theme               // gespeicherte Wahl samt Vorschau-Akzent
  var resolved: ResolvedTheme { get }         // ThemeResolver.resolve(theme)
  var isStandard: Bool { get }
  private(set) var saveFailed: Bool
  func reload()
  func setBaseTone(_ tone: BaseTone)          // speichert sofort
  func setAppearanceMode(_ mode: AppearanceMode)
  func previewAccent(_ color: SRGBColor)      // nur Vorschau (Farbwähler zieht laufend)
  func commitAccent()                          // speichert, wenn vom Gespeicherten verschieden
  func useStandardAccent()                     // accent = nil, speichert
  func resetToStandard()                       // .standard, speichert
}
/// Ziel des NavigationLink; holt `DataStore` aus der Umgebung, Modell als @State (Muster `SchoolYearSettingsScreen`).
struct AppearanceSettingsScreen: View
struct ThemePreview: View { let resolved: ResolvedTheme }   // hell und dunkel nebeneinander, statische Farben aus colors(.light/.dark)
```

Ansicht (`Form`, Systemstandard; Inhalt in `PaidGate(feature: .appearance) { … }`):
- Abschnitt „Grundton“: `Picker` mit `.pickerStyle(.inline)`, vier Fälle in Reihenfolge `BaseTone.allCases`.
- Abschnitt „Akzentfarbe“: `ColorPicker("setup.appearance.accent", selection: <Binding<CGColor>>, supportsOpacity: false)`; der Setter ruft `previewAccent(SRGBColor(cgColor:))`; Speichern entprellt: `.task(id: model.theme.accent) { try? await Task.sleep(for: .milliseconds(300)); model.commitAccent() }`. Taste „Standardakzent verwenden“, nur wenn `theme.accent != nil`.
- Abschnitt „Vorschau“: `ThemePreview` – je Modus eine Fläche im Hintergrund mit einer Material-Kachel (Tönung, Name „Arbeitsblatt Vokabeln“ in `scaledFont(.materialName)` und „PDF“ in `scaledFont(.fileType)`, beide im Akzentton) und einem Kapselknopf „Ausfall markieren“; darunter je Modus „Für ausreichenden Kontrast angepasst“, wenn `resolved.isAccentAdjusted(.light/.dark)` (FR-16.1: die Lehrkraft sieht, was erscheint). Kein Hinweis zu Q-40.
- Abschnitt „Hell/Dunkel“: `Picker` `.pickerStyle(.segmented)`.
- Taste „Auf Standard zurücksetzen“, nur wenn `!isStandard`.
- `saveFailed` → Zeile mit `setup.appearance.saveFailed`.
- Ohne Kauf (`PaidGate` zeigt `PurchaseOfferView`): darüber außerhalb des Gates der Fußtext `setup.appearance.locked`.
- `.onChange(of: store.revision) { model.reload() }` (Abgleich vom anderen Gerät).

Texte: `setup.appearance.title` Erscheinungsbild · `setup.appearance.baseTone` Grundton · `setup.appearance.baseTone.warm` Warm (Standard) · `setup.appearance.baseTone.system` System · `setup.appearance.baseTone.cool` Kühl · `setup.appearance.baseTone.petrol` Petrol · `setup.appearance.accent` Akzentfarbe · `setup.appearance.accent.standard` Standardakzent verwenden · `setup.appearance.preview` Vorschau · `setup.appearance.preview.light` Hell · `setup.appearance.preview.dark` Dunkel · `setup.appearance.preview.sampleMaterial` Arbeitsblatt Vokabeln · `setup.appearance.preview.adjusted` Für ausreichenden Kontrast angepasst · `setup.appearance.mode` Hell/Dunkel · `setup.appearance.mode.system` Wie das System · `setup.appearance.mode.light` Hell · `setup.appearance.mode.dark` Dunkel · `setup.appearance.reset` Auf Standard zurücksetzen · `setup.appearance.locked` Ohne Kauf gilt der Standard. Deine Auswahl bleibt gespeichert. · `setup.appearance.saveFailed` Nicht gespeichert. Die bisherige Einstellung bleibt. Versuch es erneut.

- [ ] **Step 1: Failing Tests schreiben** (In-Memory-`DataStore` aus `makeStore()`)

```swift
@MainActor @Suite struct AppearanceSettingsModelTests {
  @Test("AK-52: voreingestellt warm mit Standardakzent") func loadsStandardWithoutRecord() throws
  @Test("Öffnen schreibt nichts") func loadingDoesNotWrite() throws          // store.revision unverändert
  @Test("AK-52: kühl wählen speichert") func setBaseToneSaves() throws        // store.theme().baseTone == .cool
  @Test("Farbwähler ändert nur die Vorschau, bis commitAccent") func previewAccentDoesNotSaveUntilCommit() throws
  @Test("AK-53: Vorschau zeigt die abgedunkelte Fassung") func previewShowsAdjustedAccent() throws {
    let model = AppearanceSettingsModel(store: data)
    model.previewAccent(SRGBColor(hex: "#FFF3A0")!)
    #expect(model.resolved.colors(.light).accent.hex == "#6D6845")
    #expect(model.resolved.isAccentAdjusted(.light) && !model.resolved.isAccentAdjusted(.dark))
  }
  @Test("AK-54: Dunkel wählen speichert den Modus") func setAppearanceModeSaves() throws
  @Test("Zurücksetzen schreibt den Standard") func resetToStandardSaves() throws
  @Test("Abgleich vom anderen Gerät wird nach reload sichtbar") func reloadPicksUpExternalChange() throws
}
```

- [ ] **Step 2: Skill laden** – `apple-design`; prüfen gegen HIG color-wells (Farbwähler), pickers, segmented controls, settings.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Syntax prüfen** (`scripts\swift-parse.ps1`), Diff durchsehen: keine Logik in der Ansicht außer Bindungen; alle Texte über `Localizable.xcstrings`; `SetupView` behält alle Einträge.
- [ ] **Step 5: Commit** – `git commit -m "ui: appearance settings with base tone, accent and light/dark"`

---

### Task 8: Logik der Tagesansicht – Auswahl, „Jetzt“, Aussagen, Uhrzeiten, leere Zustände

Design-Takt: keiner

**Files:**
- Create: `Frontstage/UI/DayView/LessonStatement.swift`, `Frontstage/UI/DayView/DayEmptyState.swift`, `Frontstage/UI/Shared/LessonTimeFormat.swift`
- Modify: `Frontstage/App/AppEnvironment.swift` – `let now: @MainActor () -> Date`, als **letzter** `init`-Parameter mit Vorgabe `{ Date() }` (vorhandene Aufrufe bleiben gültig); `Frontstage/App/ScopedAppContent.swift` unverändert lassen (Vorgabe greift)
- Modify: `Frontstage/UI/DayView/DayViewModel.swift`
- Modify: `Frontstage/SecondScreen/SecondScreenState.swift` – zwei berechnete Eigenschaften
- Modify (Test): `FrontstageTests/TestSupport/UIFixtures.swift` – `Fixtures.environment(…, now: Date? = nil)` (nil → `{ Date() }`), `Fixtures.date(_ day: CalendarDay, _ hour: Int, _ minute: Int) -> Date` (über `Calendar.current`); `FrontstageTests/SecondScreen/SecondScreenStateTests.swift`
- Test: `FrontstageTests/UI/DayViewSelectionTests.swift`, `FrontstageTests/UI/LessonTimeFormatTests.swift`, `FrontstageTests/UI/LessonStatementTests.swift`, `FrontstageTests/UI/DayEmptyStateTests.swift`

**Interfaces:**
- Consumes: `DaySelection` (3); `LessonRow`, `MaterialRow`, `DayContent`, `DayStatement` (04); `TimetableSourceKind`, `TimetableSourceError` (05); `SecondScreenState` (06)
- Produces:

```swift
// DayViewModel (zusätzlich; vorhandene API bleibt)
private(set) var selectionState: DaySelection
var selection: LessonKey? { get set }          // set = Handauswahl (`selectionState.select`); für List(selection:)
private(set) var runningLessonKey: LessonKey?  // „Jetzt“ nur am heutigen Tag
var selectedRow: LessonRow? { get }
func tick()                                    // Minutentakt: update(lessons:now:) und runningLessonKey
func sceneDidBecomeActive()                    // neuer Kalendertag seit der letzten Aktivierung → showToday()
// reload(): nach dem Zeilenbau selectionState.update(…); showPreviousDay/NextDay/Today: selectionState.reset() vor reload()

// LessonStatement.swift
enum SignalKind { case cancellation, unavailable }
/// Aussagen an einer Unterrichtsstunde (UI-11). `DayStatement` bleibt unverändert (Lücke „Keine Stunde“ bleibt dort).
enum LessonStatement: CaseIterable, Hashable {
  case cancellation, substitute, materialUnavailable, lessonWithoutMaterial
  var symbolName: String { get }   // DayStatement-Symbole; substitute "arrow.triangle.swap"
  var labelKey: String { get }     // DayStatement-Schlüssel; substitute "dayView.substitute"
  var signal: SignalKind? { get }  // cancellation → .cancellation, materialUnavailable → .unavailable, sonst nil
}
enum DayRowLine: Hashable { case statement(LessonStatement), topic(String), none }
extension LessonRow {
  /// Alle zutreffenden Aussagen in dieser Reihenfolge: Ausfall; Vertretung; nicht verfügbar oder ohne Material.
  func statements(availability: (MaterialRow) -> MaterialAvailability?) -> [LessonStatement]
  /// Eine Zeile für die Liste (UI-3, UI-4): erste Aussage, sonst Thema, sonst nichts.
  func listLine(availability: (MaterialRow) -> MaterialAvailability?) -> DayRowLine
}
// `extension Optional<MaterialAvailability> { var isUnavailable: Bool }` aus DayRowView.swift hierher verschieben
// (LessonDetailView nutzt sie).

// DayEmptyState.swift (UI-13)
enum DayEmptyState: Equatable {
  case noLessons, nonTeachingDay(title: String), sourceFailed(TimetableSourceError), selectLesson
  /// `.rows` → nil; `.noLessons` mit Quelle ≠ manual, ohne je einen Stand und mit Fehler → sourceFailed.
  static func make(content: DayContent, sourceKind: TimetableSourceKind, fetchedAt: Date?,
                   lastError: TimetableSourceError?) -> DayEmptyState?
}

// LessonTimeFormat.swift (UI-15, Entscheidung 13)
enum LessonTimeFormat {
  static func range(_ time: ClosedRange<TimeOfDay>, on day: CalendarDay, calendar: Calendar = .current,
                    locale: Locale = .current) -> String   // Date.IntervalFormatStyle(date: nil, time: .shortened, …)
  static func accessibilityRange(…) -> String              // gleiche Parameter; „08:35 bis 09:20“ über `dayView.timeRange.accessibility %@ %@`
}

// SecondScreenState (zusätzlich)
/// Zuordnung, die gerade am verbundenen Zweitbildschirm steht (UI-12); sonst nil.
var shownMaterialLinkID: UUID? { get }      // isConnected && content == .material ? material?.linkID : nil
var isBoardShown: Bool { get }              // isConnected && content == .board
```

- [ ] **Step 1: Failing Tests schreiben** (Stundenplan: Di 1. 8b Englisch, 2. 9c Deutsch, 3. 7a Mathe; `Fixtures.bellSchedule`)

```swift
@MainActor @Suite struct DayViewSelectionTests {
  @Test("UI-3: Öffnen um 8:40 wählt die 2. Stunde") func openingSelectsRunningLesson() throws
  @Test("Stundenwechsel: tick um 9:45 wählt die 3. Stunde") func tickFollowsLessonChange() throws
  @Test("Handauswahl bleibt über tick und reload") func manualSelectionSurvivesTickAndReload() throws
  @Test("Nächster Tag wählt die erste Stunde, Heute wieder die laufende") func dayChangeResetsSelection() throws
  @Test("Neuer Kalendertag beim Aktivwerden: zurück zu heute und Automatik") func newCalendarDayResetsSelection() throws
  @Test("UI-12: runningLessonKey nur heute und nur während der Stunde") func runningLessonOnlyTodayDuringLesson() throws
}
@Suite struct LessonTimeFormatTests {
  @Test("UI-15: deutsches Systemformat 08:35 und 09:20") func germanRange()     // Locale de_DE, Europe/Berlin
  @Test("UI-15: 12-Stunden-Format in en_US enthält 8:35 und 9:20") func usRange()
}
@Suite struct LessonStatementTests {
  @Test("UI-11: nur Entfällt und nicht verfügbar tragen eine Signalfarbe") func onlyTwoStatementsCarrySignal()
  @Test("Liste: Ausfall vor Vertretung vor Material vor Thema") func listLinePriority()
  @Test("Detail: Vertretung und Ohne Material zusammen") func detailListsAllStatements()
  @Test("Ohne Aussage und ohne Thema bleibt die zweite Zeile leer") func listLineNone()
}
@Suite struct DayEmptyStateTests {
  @Test("UI-13: Ferien mit Namen") func nonTeachingDayKeepsTitle()
  @Test("UI-13: Fehler ohne jeden Stand nur bei Quelle mit Fehler") func sourceFailedOnlyWithoutAnyState()
  @Test("Zeilen vorhanden: kein leerer Zustand") func rowsHaveNoEmptyState()
}
// SecondScreenStateTests
@Test("UI-12: gezeigtes Material nur verbunden und im Modus Material") func shownMaterialLinkIDOnlyWhenShown()
```

- [ ] **Step 2: Diff durchsehen** – vorhandene `DayViewModelTests` bauen unverändert (Signaturen nur ergänzt); `AppEnvironment`-Aufrufe in App und Tests bleiben gültig.
- [ ] **Step 3: Implementieren.** Texte: `dayView.timeRange.accessibility %@ %@` „%1$@ bis %2$@“.
- [ ] **Step 4: Syntax prüfen** (`scripts\swift-parse.ps1`), Diff erneut durchsehen.
- [ ] **Step 5: Commit** – `git commit -m "ui: day view selection, running lesson, statements and system time formats"`

---

### Task 9: Bausteine der Tagesansicht – Zeile, Kachel, Kapseln, Aussage (UI-4, UI-6, UI-10, UI-11, UI-12, UI-14, UI-15)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/UI/DayView/StatementView.swift`, `Frontstage/UI/DayView/SignalCapsule.swift`, `Frontstage/UI/DayView/DayListRow.swift`, `Frontstage/UI/DayView/MaterialTile.swift`, `Frontstage/UI/DayView/OrphanMaterialRow.swift`
- Modify: `Frontstage/UI/DayView/DayViewLayout.swift` – Inhalt ersetzen durch Konstanten (UI-4, UI-10): `rowHeight 44`, `rowSpacing 4`, `detailPadding 16`, `sectionSpacing 16`, `tileSpacing 8`, `tileHeight 120`, `tileMinWidth 200`, `tileRadius 16`, `selectionRadius 10`; `rowHeight(availableHeight:rowCount:spacing:)`, `minRowHeight`, `maxRowHeight`, `orphanReserve(count:)` bleiben in diesem Task noch stehen (das alte `DayView.swift` nutzt sie bis Task 10) und entfallen in Task 10
- Modify: `Frontstage/UI/DayView/SourceStatusBar.swift` – beim Abfragen `ProgressView().controlSize(.small)` vor dem Stand (`coordinator.isFetching`, UI-13); Schrift `scaledFont(.detailMeta)`, Farben `themeStyle.text` statt `.secondary` (UI-6); Fehler bleiben Symbol und Wort, kein Dialog
- Modify: `Frontstage/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `ThemeStyle`, `scaledFont(_:)`, `TypeScale`, `TileButtonStyle` (6); `LessonStatement`, `DayRowLine`, `LessonTimeFormat`, `SignalKind` (8); `DayRowActions`, `MaterialRow`, `MaterialLinkItem`, `HandOffAnchor`, `HandOffAnchorReader` (04, 03)
- Produces:

```swift
/// Symbol in Signalfarbe (oder Textfarbe), Wort immer in Textfarbe – getrennt, kein gemeinsames Label (UI-11).
struct StatementView: View { init(_ statement: LessonStatement, scale: TypeScale) }
/// Gelbe Kapsel #FFC94A, Wort #1F1A14 in beiden Modi, Wortgröße scaledFont(.listMeta) (UI-12).
struct SignalCapsule: View {
  enum Kind { case now, onSmartboard }   // „Jetzt“ / „Am Smartboard“; VoiceOver: „läuft jetzt“ / „am Smartboard“
  init(_ kind: Kind)
}
/// Listenzeile, Mindesthöhe @ScaledMetric 44 pt: oben „8b · Englisch“ (listTitle, durchgestrichen bei Ausfall) und rechtsbündig
/// „2. Stunde · 08:35–09:20“ (listMeta, monospacedDigit); darunter `DayRowLine` (listMeta) und am Ende ggf. SignalCapsule(.now).
/// Ein VoiceOver-Element (`.accessibilityElement(children: .combine)`).
struct DayListRow: View { init(row: LessonRow, line: DayRowLine, isRunning: Bool) }
/// Lücke: „Keine Stunde“ als Titel ohne Symbol (UI-11), Stunde und Uhrzeit rechts.
struct DayGapRow: View { init(period: Int, time: ClosedRange<TimeOfDay>?, day: CalendarDay) }
/// Material-Ziel (UI-4, UI-9, UI-10, UI-11): Höhe @ScaledMetric 120, TileButtonStyle; oben ggf. SignalCapsule(.onSmartboard);
/// Name materialName im Akzentton, 2 Zeilen, Mitte gekürzt; unten Dateityp (fileType, Endung groß, sonst „Datei“) –
/// oder bei nicht verfügbar StatementView(.materialUnavailable, scale: .fileType) – oder beim Laden ProgressView + „Wird geladen …“ (`dayView.loading`).
/// Kontextmenü: inLesson → „In die nächste Stunde“; sonst „Zuordnen …“; nicht verfügbar → zusätzlich „Neu verknüpfen“.
/// Barrierefreiheit: Label = Dateiname, Value = „am Smartboard“ / „Wird geladen …“ / „Material nicht verfügbar“.
struct MaterialTile: View {
  init(row: MaterialRow, isOpening: Bool, isShown: Bool, inLesson: Bool, actions: DayRowActions)
}
/// Tafel als Kachel derselben Form: Symbol „pencil.and.scribble“ und „Tafel“ (materialName); ggf. SignalCapsule(.onSmartboard).
struct BoardTile: View { init(key: LessonKey, isShown: Bool, actions: DayRowActions) }
/// „Material ohne Stunde“ (FR-7): Name (listTitle, Mitte gekürzt) öffnet, Kapselknopf „Zuordnen …“, Kontextmenü wie MaterialTile.
struct OrphanMaterialRow: View { init(row: MaterialRow, isOpening: Bool, actions: DayRowActions) }
```

Alle Texte und Symbole in `themeStyle.text` bzw. Akzent/Signal laut Rolle, nie `.secondary`, nie Fett (UI-6). Kapselwechsel `.transition(.opacity)` mit `.animation(.snappy(duration: 0.15), value: isShown)`; kein Pulsieren (UI-14). `MaterialTile` liest die Verfügbarkeit live aus `environment.storage.availability` wie bisher `MaterialButton`; den Anker für „Öffnen in …“ über `HandOffAnchorReader`.

Texte: `dayView.now` Jetzt · `dayView.now.accessibility` läuft jetzt · `dayView.onSmartboard` Am Smartboard · `dayView.onSmartboard.accessibility` am Smartboard · `dayView.row.periodTime %lld %@` %1$lld. Stunde · %2$@ · `dayView.fileType.unknown` Datei. Vorhanden und weiter genutzt: `dayView.statement.*`, `dayView.substitute`, `dayView.loading`, `dayView.moveToNext`, `dayView.assign`, `dayView.relink`, `board.title`, `dayView.period %lld`.

- [ ] **Step 1: Skill laden** – `apple-design`; prüfen gegen HIG lists-and-tables, buttons, color (Signal nie allein über Farbe), typography, accessibility (VoiceOver, Dynamic Type, 44-pt-Ziele).
- [ ] **Step 2: Diff-Plan durchsehen** – jede Maßzahl aus `DayViewLayout`, keine Zahl im View-Code außer `TypeScale`; keine Datei außer den genannten berührt.
- [ ] **Step 3: Implementieren.** `DayRowView.swift` und die alten Funktionen in `DayViewLayout` bleiben in diesem Task noch stehen (Task 10 löscht sie), damit der Stand baut. Die neue Konstante `rowHeight` und die alte Funktion `rowHeight(availableHeight:rowCount:spacing:)` dürfen nebeneinander stehen (verschiedene vollständige Namen).
- [ ] **Step 4: Syntax prüfen** (`scripts\swift-parse.ps1`), Diff durchsehen; Lücken im Abschlussbericht (mindestens: Kachelbreite 200 pt, Tafel-Kachel trägt „Am Smartboard“ nach UI-12 sinngemäß).
- [ ] **Step 5: Commit** – `git commit -m "ui: day view rows, material tiles and yellow capsules"`

---

### Task 10: Tagesansicht als Liste und Detail (UI-3, UI-4, UI-5, UI-11–UI-14)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/UI/DayView/DayLessonDetail.swift`
- Modify: `Frontstage/UI/DayView/DayView.swift`
- Delete: `Frontstage/UI/DayView/DayRowView.swift` (`DayRowActions` vorher nach `DayLessonDetail.swift` verschieben, unverändert; `MaterialButton`, `PeriodHeader`, `StatementLabel`, `LessonRowView` entfallen)
- Modify: `Frontstage/UI/DayView/DayViewLayout.swift` – `rowHeight(availableHeight:rowCount:spacing:)`, `minRowHeight`, `maxRowHeight`, `orphanReserve(count:)` entfernen (aus Task 9 hierher verschoben, weil das alte `DayView.swift` sie bis hier nutzt)
- Delete: `FrontstageTests/UI/DayViewLayoutTests.swift` (prüfte nur die entfallenen Funktionen)
- Modify: `Frontstage/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: alles aus Tasks 6, 8, 9; `DayViewModel` (`selection`, `selectedRow`, `runningLessonKey`, `tick()`, `sceneDidBecomeActive()`); `SecondScreenState` (`shownMaterialLinkID`, `isBoardShown`, `boardLessonKey`); `TimetableSourceCoordinator` (`repository.timetableSourceKind()`, `repository.sourceFetchedAt()`, `status.lastError`, `refresh(.userRequest)`); `SmartboardBar` (06); `PlanHintLabel` (09)
- Produces:

```swift
/// Detail der gewählten Unterrichtsstunde, ScrollView mit DayViewLayout.detailPadding/sectionSpacing:
/// Titel (detailTitle, durchgestrichen bei Ausfall) · Stunde und Uhrzeit (detailMeta) · Aussagezeile (alle `statements`,
/// detailMeta) · Thema (topic) · Bereitlegen, Hausaufgabe, Leistungsnachweise (detailMeta) · Material-Kacheln in Reihenfolge
/// (LazyVGrid adaptive(minimum: tileMinWidth), spacing tileSpacing) · Tafel-Kachel (nicht bei Ausfall) ·
/// Kapselknöpfe: „Ausfall markieren“ (regular/substitute) bzw. „Ausfall aufheben“ (nur Ausfall von Hand, FR-8),
/// „Material weiterreichen“ (nur mit Material).
struct DayLessonDetail: View {
  init(row: LessonRow, day: CalendarDay, openingIDs: Set<UUID>, shownLinkID: UUID?, isBoardShown: Bool,
       actions: DayRowActions, zoomNamespace: Namespace.ID)
}
```

`DayView`-Aufbau:
- `NavigationSplitView { list } detail: { detail }`; `.safeAreaInset(edge: .bottom, spacing: 0) { SmartboardBar() }` (iOS) am Split-View. Alle vorhandenen Dialoge, `fileImporter`, Alerts, `confirmationDialog`, Betrachter-Anzeige (`fullScreenCover`/`sheet`), `boardPresentation`, `AssignLessonSheet` und Aktionen (`rowActions`, `open`, `handle`, `offer`, `relink`, `carryNotes`) bleiben inhaltlich unverändert.
- **Listenspalte:** `List(selection: $model.selection)`, `.listStyle(.plain)`, `.listRowSeparator(.hidden)`, iOS `.listRowSpacing(DayViewLayout.rowSpacing)`; Stunden als `DayListRow(...).tag(key)`, Lücken als `DayGapRow` ohne Tag mit `.selectionDisabled()`; darunter Section „Material ohne Stunde“ mit `OrphanMaterialRow` nur bei Einträgen (UI-13). Ohne Systemneutrale: `.scrollContentBackground(.hidden)`, `.background(themeStyle.background)`, gewählte Zeile `.listRowBackground(RoundedRectangle(cornerRadius: DayViewLayout.selectionRadius, style: .continuous).fill(themeStyle.selection))`, sonst `themeStyle.background` (UI-8, UI-10); mit Systemneutralen nichts davon (Entscheidung 14). Oben `.safeAreaInset(edge: .top) { SourceStatusBar() }`. Titel und Werkzeugleiste (gestern/Heute/morgen) wie bisher an der Listenspalte.
- **Detailspalte:** `DayEmptyState.make(...)` ≠ nil → `ContentUnavailableView` (noLessons: Titel `dayView.noLesson`, Symbol `DayStatement.noLesson.symbolName`; nonTeachingDay: Titel = Name, Symbol `sun.max`; sourceFailed: Titel `dayView.empty.sourceFailed`, Beschreibung = `error.settingsMessageKey` bzw. `timetableSource.error.server %lld`, Symbol `calendar.badge.exclamationmark`, Taste `dayView.retry` → `coordinator.refresh(.userRequest)`); sonst `selectedRow` → `DayLessonDetail(...).id(key.storageText).transition(.opacity)`, `.animation(.smooth(duration: 0.2), value: model.selection)` (UI-14); sonst `.selectLesson` → `ContentUnavailableView("dayView.selectLesson", systemImage: "hand.tap")`. Hintergrund `themeStyle.background` (ohne Systemneutrale).
- **Schmale Breite (Lücke):** Ist der Tag ohne Zeilen und `horizontalSizeClass == .compact` (nur `#if os(iOS)`: `EnvironmentValues.horizontalSizeClass` gibt es unter macOS nicht), zeigt die Listenspalte denselben `ContentUnavailableView` als `.overlay` – das Detail ist dort sonst nicht erreichbar. Im Abschlussbericht nennen.
- **Takt:** `.task(id: model.day) { while !Task.isCancelled { try? await Task.sleep(for: .seconds(30)); model.tick() } }`; in der vorhandenen `onChange(of: scenePhase)` bei `.active` zusätzlich `model.sceneDidBecomeActive()`. Kein automatisches Scrollen (UI-14).
- **„Am Smartboard“ ansagen (UI-12, UI-14):** `.onChange(of: secondScreen.shownMaterialLinkID)` → neuer Wert mit Namen aus den Zeilen: `AccessibilityNotification.Announcement(String(localized: "dayView.onSmartboard.announcement \(name)")).post()`; iOS zusätzlich `.sensoryFeedback(.selection, trigger: secondScreen.shownMaterialLinkID)`.
- **Material öffnen (UI-14):** iOS: Kachel `.matchedTransitionSource(id: row.id, in: zoomNamespace)`, Betrachter `.navigationTransition(.zoom(sourceID: target.id, in: zoomNamespace))` nur wenn `!accessibilityReduceMotion`; sonst die Systemdarstellung ohne Zoom.

Texte: `dayView.selectLesson` Wähle eine Stunde · `dayView.empty.sourceFailed` Stundenplan nicht abrufbar · `dayView.retry` Erneut abfragen · `dayView.onSmartboard.announcement %@` Am Smartboard: %@ · Aktionen vorhanden: `dayView.cancel` Ausfall markieren, `dayView.uncancel` Ausfall aufheben, `dayView.passOn` Material weiterreichen.

- [ ] **Step 1: Skill laden** – `apple-design`; prüfen gegen HIG split-views, sidebars, lists-and-tables (Auswahl), materials (Glas nur Funktionsebene), motion (Reduce Motion), accessibility (Ansagen).
- [ ] **Step 2: Erreichbarkeit prüfen (vor dem Löschen)** – Liste aller Closures in `DayRowActions` (`open`, `relink`, `moveToNext`, `assign`, `setCancelled`, `passOn`, `openBoard`) und je die neue Stelle notieren: Kachel-Tipp, Kachel-Kontextmenü, Kapselknopf, Tafel-Kachel, `OrphanMaterialRow`. Jede muss eine Stelle haben.
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Syntax prüfen** (`scripts\swift-parse.ps1`), `rg "DayRowView|MaterialButton|DayViewLayout\.rowHeight\(|minRowHeight|maxRowHeight|orphanReserve|%d:%02d" Frontstage FrontstageTests` → keine Treffer (die Konstante `DayViewLayout.rowHeight` ohne Klammer bleibt erlaubt); vorhandene `DayViewModelTests`, `PlanHintTests` bauen unverändert. Lücken im Abschlussbericht.
- [ ] **Step 5: Commit** – `git commit -m "ui: rebuild day view as list and detail per design decisions"`

---

### Task 11: Grundton und Schrift app-weit, wo es wenig kostet (UI-6, UI-7, UI-8)

Design-Takt: Hauptstufe

**Files:**
- Create: `Frontstage/UI/Theme/ThemedBackground.swift`
- Modify: `Frontstage/UI/Preparation/PreparationView.swift` (Wochen-`List`), `Frontstage/UI/Preparation/LessonDetailView.swift` (`List` im `body`), `Frontstage/UI/CoursePlan/CoursePlanView.swift` (beide `List`), `Frontstage/UI/Setup/SetupView.swift` (`Form`), `BellScheduleEditorView.swift`, `NonTeachingPeriodsView.swift`, `SchoolYearSettingsView.swift`, `TimetableEditorView.swift` (je `List`), `StorageSettingsView.swift`, `TimetableSourceSettingsView.swift`, `ImportPreviewView.swift`, `AppearanceSettingsView.swift` (je äußeres `Form`)
- Modify: `Frontstage/UI/Shared/PlanHintLabel.swift` – `.font(.subheadline)` → `scaledFont(.detailMeta)` (UI-6: Hinweise 13 pt im Detail)

**Interfaces:**
- Consumes: `ThemeStyle` (6)
- Produces:

```swift
extension View {
  /// Ohne Systemneutrale: `.scrollContentBackground(.hidden)` und `.background(themeStyle.background)`; mit: unverändert.
  func themedBackground() -> some View
}
```

Nicht in diesem Task: Zeilenhintergründe gruppierter Formulare (bleiben Systemzellen), Textfarbe außerhalb der Tagesansicht (bleibt Systemfarbe `label`), Klassenbildschirm, Tafel, Kaufangebot (Q-37–Q-39), `CoursePlanComparisonView`. Diese Grenzen als Lücke im Abschlussbericht nennen.

- [ ] **Step 1: Skill laden** – `apple-design`; prüfen gegen HIG color, dark-mode.
- [ ] **Step 2: Je Datei das äußere `List`/`Form` lesen**, erst dann den Modifier anhängen (eine Zeile je Container).
- [ ] **Step 3: Implementieren.**
- [ ] **Step 4: Syntax prüfen** (`scripts\swift-parse.ps1`), Diff durchsehen: keine weiteren Änderungen in den Dateien.
- [ ] **Step 5: Commit** – `git commit -m "ui: apply base tone backgrounds app-wide"`

---

### Task 12: CI-Lauf (workflow_dispatch) und Ergebnis prüfen – führt der Controller aus

Design-Takt: keiner

- [ ] **Step 1: Gesamtdiff durchsehen** – `git diff main...HEAD -- Packages Frontstage FrontstageTests project.yml docs`: `FrontstageCore` importiert nur `Foundation`; Swift 6 strikt (dynamische Farb-Closures fangen nur Sendable ein); `ThemeRecord` ohne `.unique`, alle Felder mit Vorgabe; `ModelContainerFactory.modelTypes` = 13; `RecordCodec` behandelt 13 Modelle in `exportAll`, `export(_:from:)`, `liveIDs`, `upsert`, `delete`, `HasRecordID`; `mergeDuplicates()` wendet `ThemeMerger` auch an, wenn die anderen Pläne leer sind; `RootView` behält alles aus 04–09; keine Handformatierung von Uhrzeiten in `Frontstage/UI/DayView`.
- [ ] **Step 2: Kern lokal** – `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\swift-test.ps1` → alle Suites grün; `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\swift-parse.ps1` → keine Syntaxfehler.
- [ ] **Step 3: Lauf starten**

```bash
git push -u origin "$(git branch --show-current)"
gh workflow run ci.yml --ref "$(git branch --show-current)"
gh run list --workflow ci.yml --limit 1
gh run watch <run-id> --exit-status
```

Erwartet: Schritt „Core tests“ grün inkl. `Theme Color`, `Theme Contrast`, `Theme Values`, `Theme Resolver`, `Theme Merge`, `DayView Selection`, `DataFolder Format`; Schritt „App tests (iPad simulator)“ grün mit `ThemeStoreTests`, `RecordCodecTests`, `RecordSchemaTests`, `ThemeColorConversionTests`, `AppearanceSettingsModelTests`, `DayViewSelectionTests`, `LessonTimeFormatTests`, `LessonStatementTests`, `DayEmptyStateTests`, `SecondScreenStateTests` sowie allen vorhandenen (`DayViewModelTests`, `PlanHintTests` unverändert); Schritt „Build macOS“ grün. Implementierer pushen nicht und starten keinen Lauf.

- [ ] **Step 4: Bei Rot** – erst `TestResults.xcresult` und `gh run view <run-id> --log-failed` lesen, Ursache mit superpowers:systematic-debugging klären, alle Korrekturen sammeln, Diff prüfen, **ein** neuer Lauf.

---

## Geräte-Checkliste (Mensch mit iPad und Mac, nach Task 12)

| # | Aufbau | Handlung | Erwartet | Ergebnis |
|---|---|---|---|---|
| 1 | **AK-52:** frische Installation, iPad hell, zweites Gerät gleicher Datenort | Einrichten › Erscheinungsbild ohne Kauf öffnen; Kauf (Sandbox); „kühl“ wählen | ohne Kauf Kaufangebot, App warm; nach Kauf kühl, auch am zweiten Gerät nach dem Abgleich (bei OneDrive Datei in `Apps/Frontstage/Theme/`) | ☐ iCloud ☐ OneDrive |
| 2 | **AK-53:** Kauf, warm | Akzent `#FFF3A0` wählen | Vorschau hell abgedunkelt mit Hinweis, dunkel unverändert; „Entfällt“/„nicht verfügbar“ unverändert | ☐ |
| 3 | **AK-54:** Kauf, iPad hell | „Dunkel“, dann „Wie das System“ | App dunkel, andere Apps hell; zurück folgt sie dem iPad (auch ohne Neustart) | ☐ |
| 4 | UI-3/UI-12, Tag mit laufender Stunde | Tagesansicht öffnen; andere Stunde wählen; Stundenwechsel abwarten | laufende Stunde gewählt, „Jetzt“ an ihrer Zeile; Handauswahl bleibt; nichts blinkt | ☐ |
| 5 | UI-12, Apple TV verbunden | PDF öffnen, zeigen, zurück; VoiceOver an | „Am Smartboard“ auf der Kachel, Ansage beim Wechsel | ☐ |
| 6 | UI-4/UI-6, Stehen auf Armlänge | Stunde in der Liste treffen; Dynamic Type „Größerer Text“ | 44-pt-Zeilen treffbar, zwei Zeilen passen bei Standardgröße; groß: Liste scrollt, nichts abgeschnitten | ☐ |
| 7 | UI-5/UI-8, warm hell und dunkel | gewählte Zeile ansehen; „Kontrast erhöhen“, „Transparenz reduzieren“ | Auswahlfläche `#ECE5D8`/`#2F2921` mit 10-pt-Ecken sichtbar (keine Systemhervorhebung darüber); Kontrastfassung greift | ☐ |
| 8 | UI-7 | Tab-Leiste, Werkzeugleiste, Inhalt vergleichen | Inhalt SF Rounded, Leisten SF Pro | ☐ |
| 9 | UI-14, „Bewegung reduzieren“ an/aus | Stunde wechseln, Material öffnen | Detail blendet über; Zoom nur ohne „Bewegung reduzieren“ | ☐ |
| 10 | Mac | Tagesansicht mit Tastatur bedienen | Fokus-Hervorhebung in Akzentfarbe, Liste und Detail bedienbar | ☐ |

---

## Abdeckung

| Anforderung / Beschluss | Task |
|---|---|
| FR-16 – Grundton, Akzent, Hell/Dunkel, auf allen Geräten | 2, 4, 5, 6, 7; Geräte-Checkliste 1 |
| FR-16.1 – Kontrastschutz, Vorschau zeigt Angepasstes, Signale fest | 1, 2, 7; Geräte-Checkliste 2 |
| FR-16.2 – Hell/Dunkel unabhängig vom Gerät | 2, 6, 7; Geräte-Checkliste 3 |
| FR-13 (geändert 2026-11-15) – Anpassung im Kauf, Standard frei | 2, 6, 7 |
| AK-52, AK-53, AK-54 | 2, 5, 7 (Logik), Geräte-Checkliste 1–3 |
| UI-3 Liste und Detail, automatische Auswahl | 3, 8, 10; Geräte-Checkliste 4 |
| UI-4 Dichte | 9, 10; Geräte-Checkliste 6 |
| UI-5 Ebenen, UI-8 Grundtöne, UI-9 Akzent | 2, 6, 10, 11; Geräte-Checkliste 7 |
| UI-6 Schriftskala, UI-7 SF Rounded | 6, 9, 11; Geräte-Checkliste 6, 8 |
| UI-10 Formen | 6, 9 |
| UI-11 Aussagen | 2, 8, 9 |
| UI-12 Kapseln | 3, 8, 9, 10; Geräte-Checkliste 4, 5 |
| UI-13 Zustände | 8, 9, 10 |
| UI-14 Bewegung | 9, 10; Geräte-Checkliste 9 |
| UI-15 Sprache, Formate | 8, 9, 10 |
| ADR-0012 – beide Abgleichwege | 4, 5 |

## Produziert für spätere Teilpläne (Zusammenfassung)

- **Kern:** `SRGBColor`, `ContrastDirection`, `ContrastAdjuster`, `BaseTone`, `AppearanceMode`, `ThemeAccent`, `Theme`, `NeutralColors`, `ThemeVariant`, `ThemeColors`, `ResolvedTheme`, `ThemeResolver`, `DaySelection`, `ThemePayload`, `SyncModel.theme`, `RecordPayload.theme`, `ThemeMergeEntry`, `ThemeMergePlan`, `ThemeMerger`.
- **App:** `ThemeRecord`, `DataStore.theme()`/`setTheme(_:)`, `ThemeStore`, `PaidFeature.appearance`, `EnvironmentValues.themeStyle`/`ThemeStyle`, `TypeScale`/`scaledFont(_:)`, `TileButtonStyle`, `CapsuleActionButtonStyle`, `appTheme(store:unlock:)`, `themedBackground()`, `AppEnvironment.now`, `LessonTimeFormat`, `LessonStatement`, `DayRowLine`, `DayEmptyState`, `SecondScreenState.shownMaterialLinkID`/`isBoardShown`, `SignalCapsule`, `MaterialTile`, `BoardTile`, `DayLessonDetail`; `DayViewLayout` ist jetzt eine Konstantensammlung.

## Abstimmungsbedarf

- **Kontrast erhöhen (UI-8):** keine Werte beschlossen; gebaut nach Entscheidung 6. Bei Bedarf eine Design-Runde.
- **Q-40 (PRD):** Akzent gleich einer Signalfarbe bleibt zulässig, ohne Hinweis in der Vorschau.
- **Klassenbildschirm, Tafel, Kaufangebot** (Q-37–Q-39) folgen weiter Systemvorgaben.
- **Zeilenhintergründe gruppierter Formulare und Textfarbe außerhalb der Tagesansicht** bleiben Systemfarben (Task 11).

## Offene Risiken

1. **Auswahlfläche von `List(selection:)`:** Ob iPadOS seine eigene Hervorhebung über `.listRowBackground` legt, zeigt erst das Gerät (Checkliste 7). Rückfall: Zeilen als `Button` mit eigenem Auswahlzustand und `.accessibilityAddTraits(.isSelected)`.
2. **Spaltentrenner von `NavigationSplitView`** lässt sich in SwiftUI nicht einfärben; er bleibt Systemtrenner statt warmer Haarlinie (UI-8).
3. **Kurzer Standard beim Start** trotz Kauf (Entscheidung 8).
4. **Haptischer Tick (UI-14)** wirkt nur auf Geräten mit Taptic Engine; die meisten iPads haben keine – dort bleibt es bei der Überblendung.
5. **`.preferredColorScheme(nil)`** kehrte in früheren SwiftUI-Versionen nicht immer sofort zur Systemeinstellung zurück; Checkliste 3 prüft es.
6. **Gemischte App-Versionen:** Ein Gerät ohne Teilplan 10 ignoriert den Ordner `Theme/` bzw. die Datensatzart und zeigt den Standard, löscht aber nichts.
