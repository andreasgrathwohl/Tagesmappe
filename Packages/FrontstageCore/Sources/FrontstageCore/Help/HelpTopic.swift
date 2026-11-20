import Foundation

/// Hilfethema (Glossar). Die Reihenfolge der Fälle ist die Reihenfolge im Hilfecenter und bei
/// Gleichstand in der Suche.
public enum HelpTopic: String, CaseIterable, Codable, Sendable, Hashable {
  case gettingStarted, dayView, openingMaterial, penNotes, secondScreen, classScreen, board,
       preparation, coursePlan, timetable, bellSchedule, nonTeachingDays, schoolYears, schulmanager,
       storage, dataLocation, pairing, appearance, purchase, privacy, feedback

  /// Gruppe, unter der das Thema im Hilfecenter steht.
  public var group: HelpGroup {
    switch self {
    case .gettingStarted: .start
    case .dayView, .openingMaterial, .penNotes: .teaching
    case .secondScreen, .classScreen, .board: .classroom
    case .preparation, .coursePlan: .planning
    case .timetable, .bellSchedule, .nonTeachingDays, .schoolYears, .schulmanager,
         .storage, .dataLocation, .pairing, .appearance: .setup
    case .purchase, .privacy, .feedback: .about
    }
  }

  /// Ob das Thema in der Hilfe erscheint. Das Schulmanager-Thema folgt der Quelle (ADR-0016): Ist sie
  /// abgeschaltet, fehlt es in Gliederung, Suche und bei den verwandten Themen; die Texte bleiben erhalten.
  public var isAvailable: Bool {
    switch self {
    case .schulmanager: TimetableSourceKind.schulmanager.isAvailable
    default: true
    }
  }

  /// Die angezeigten Themen, in der Reihenfolge von `allCases`.
  public static var availableCases: [HelpTopic] { allCases.filter(\.isAvailable) }

  /// Verwandte Themen (1–3 Einträge, nie das Thema selbst), ohne abgeschaltete Themen.
  public var related: [HelpTopic] { relatedTable.filter(\.isAvailable) }

  /// Feste Tabelle der verwandten Themen, unabhängig davon, was gerade angeboten wird.
  var relatedTable: [HelpTopic] {
    switch self {
    case .gettingStarted: [.timetable, .storage, .dataLocation]
    case .dayView: [.openingMaterial, .secondScreen, .preparation]
    case .openingMaterial: [.storage, .penNotes, .dayView]
    case .penNotes: [.openingMaterial, .secondScreen]
    case .secondScreen: [.classScreen, .board, .dayView]
    case .classScreen: [.secondScreen, .purchase]
    case .board: [.secondScreen, .purchase]
    case .preparation: [.dayView, .coursePlan, .storage]
    case .coursePlan: [.schoolYears, .preparation]
    case .timetable: [.bellSchedule, .schulmanager, .nonTeachingDays]
    case .bellSchedule: [.timetable]
    case .nonTeachingDays: [.schoolYears, .timetable]
    case .schoolYears: [.coursePlan, .nonTeachingDays]
    case .schulmanager: [.timetable, .privacy]
    case .storage: [.openingMaterial, .dataLocation]
    case .dataLocation: [.pairing, .privacy]
    case .pairing: [.dataLocation]
    case .appearance: [.purchase]
    case .purchase: [.classScreen, .board, .appearance]
    case .privacy: [.dataLocation, .feedback]
    case .feedback: [.privacy]
    }
  }

  /// Präfix der Textschlüssel in `Localizable.xcstrings`.
  public var textKeyPrefix: String { "help.\(rawValue)" }
}

/// Gruppen des Hilfecenters.
public enum HelpGroup: String, CaseIterable, Sendable {
  case start, teaching, classroom, planning, setup, about
}

extension HelpGroup {
  /// Angezeigte Themen der Gruppe in der Reihenfolge von `HelpTopic.allCases`.
  public var topics: [HelpTopic] { HelpTopic.availableCases.filter { $0.group == self } }
}
