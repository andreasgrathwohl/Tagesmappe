import Foundation
import FrontstageCore
import SwiftData

@testable import Frontstage

/// Hält die In-Memory-Container der Test-Stores am Leben: `DataStore` hält nur den `ModelContext`,
/// und ein Kontext ohne seinen Container ist ungültig.
@MainActor private var fixtureContainers: [ModelContainer] = []

/// Ein `DataStore` mit leerem Speicher im Arbeitsspeicher (ohne iCloud-Spiegelung).
@MainActor func makeStore() throws -> DataStore {
  let container = try ModelContainerFactory.makeInMemoryContainer()
  fixtureContainers.append(container)
  return DataStore(modelContext: ModelContext(container))
}

let tue17 = CalendarDay(year: 2026, month: 11, day: 17)
let wed18 = CalendarDay(year: 2026, month: 11, day: 18)
let thu19 = CalendarDay(year: 2026, month: 11, day: 19)

private func fixtureEntry(_ weekday: Weekday, _ period: Int, _ schoolClass: String, _ subject: String)
  -> TimetableEntry
{
  TimetableEntry(
    weekday: weekday, period: period, schoolClass: SchoolClass(schoolClass), subject: Subject(subject))
}

/// Fixture A: eine Wochenvariante, Bezugswoche 16.11.2026, fünf Stunden in drei Klassen.
let fixtureA = Timetable(
  weekVariantCount: 1, referenceWeekA: CalendarDay(year: 2026, month: 11, day: 16),
  entries: [
    fixtureEntry(.tuesday, 2, "8a", "Englisch"),
    fixtureEntry(.wednesday, 3, "8b", "Englisch"),
    fixtureEntry(.thursday, 1, "8a", "Englisch"),
    fixtureEntry(.friday, 4, "8b", "Mathe"),
    fixtureEntry(.monday, 5, "9c", "Deutsch"),
  ])

/// Fixture B: nur Klasse 8b Englisch, Di 2. und Do 3. Stunde.
let fixtureB = Timetable(
  weekVariantCount: 1, referenceWeekA: CalendarDay(year: 2026, month: 11, day: 16),
  entries: [
    fixtureEntry(.tuesday, 2, "8b", "Englisch"),
    fixtureEntry(.thursday, 3, "8b", "Englisch"),
  ])

/// Verweis auf eine erfundene PDF-Datei in der Freigabe „Unterricht“.
func reference(_ name: String) -> MaterialReference {
  MaterialReference(
    folderGrantName: "Unterricht", relativePath: "Englisch/\(name)", displayName: name, fileKind: .pdf)
}
