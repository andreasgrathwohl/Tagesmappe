import Foundation
import SwiftData

/// Erzeugt die SwiftData-Container der App (iCloud-Spiegelung in die private Datenbank,
/// ADR-0002, abgelöst durch ADR-0010: iCloud bleibt einer der wählbaren Datenorte; der Ordner in der
/// Ablage folgt in einem späteren Teilplan).
enum ModelContainerFactory {
  /// Alle gespiegelten Modelle. Ordnerfreigaben gehören nicht dazu (nur lokal, Teilplan 03).
  /// Berechnet statt `static let`: Swift 6 strikt verlangt für statische Konstanten einen
  /// `Sendable`-Typ, und Metatypen von `PersistentModel` sind das nicht sicher.
  static var modelTypes: [any PersistentModel.Type] {
    [
      TimetableRecord.self, TimetableEntryRecord.self, NonTeachingPeriodRecord.self,
      ScheduleChangeRecord.self, MaterialLinkRecord.self, PenNoteRecord.self,
      LessonInfoRecord.self, BoardPageRecord.self, SchoolYearRecord.self, CoursePlanRecord.self,
      PlanWeekRecord.self, AssessmentRecord.self,
    ]
  }

  /// Liest den Schlüssel `FrontstageCloudKitContainer` aus der Info.plist; leer oder fehlend ergibt `nil`.
  static func cloudKitContainerIdentifier(bundle: Bundle = .main) -> String? {
    guard let value = bundle.object(forInfoDictionaryKey: "FrontstageCloudKitContainer") as? String,
      !value.isEmpty
    else { return nil }
    return value
  }

  /// Mit Spiegelung in die private CloudKit-Datenbank.
  static func makeCloudContainer(identifier: String) throws -> ModelContainer {
    let schema = Schema(modelTypes)
    let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .private(identifier))
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  /// Für Tests und Vorschauen: nur im Speicher, ohne Spiegelung.
  static func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema(modelTypes)
    let configuration = ModelConfiguration(
      schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  /// Unter Tests (Umgebungsvariable `XCTestConfigurationFilePath` gesetzt) oder ohne Container-Kennung:
  /// im Speicher; sonst mit Spiegelung.
  static func makeDefault() throws -> ModelContainer {
    let underTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    guard !underTest, let identifier = cloudKitContainerIdentifier() else {
      return try makeInMemoryContainer()
    }
    return try makeCloudContainer(identifier: identifier)
  }
}
