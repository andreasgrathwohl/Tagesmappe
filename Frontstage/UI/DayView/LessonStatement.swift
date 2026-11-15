import FrontstageCore
import Foundation

/// Signalfarbe einer Aussage (UI-11): nur Ausfall und „nicht verfügbar“ tragen eine.
enum SignalKind {
  case cancellation, unavailable
}

/// Aussagen an einer Unterrichtsstunde (UI-11). `DayStatement` bleibt unverändert (die Lücke
/// „Keine Stunde“ bleibt dort).
enum LessonStatement: CaseIterable, Hashable {
  case cancellation, substitute, materialUnavailable, lessonWithoutMaterial

  /// Name des SF Symbols (wie `DayStatement`; Vertretung: Tauschpfeile).
  var symbolName: String {
    switch self {
    case .cancellation: DayStatement.cancellation.symbolName
    case .substitute: "arrow.triangle.swap"
    case .materialUnavailable: DayStatement.materialUnavailable.symbolName
    case .lessonWithoutMaterial: DayStatement.lessonWithoutMaterial.symbolName
    }
  }

  /// Schlüssel in `Localizable.xcstrings`.
  var labelKey: String {
    switch self {
    case .cancellation: DayStatement.cancellation.labelKey
    case .substitute: "dayView.substitute"
    case .materialUnavailable: DayStatement.materialUnavailable.labelKey
    case .lessonWithoutMaterial: DayStatement.lessonWithoutMaterial.labelKey
    }
  }

  /// Signalfarbe; Vertretung und „ohne Material“ bleiben neutral.
  var signal: SignalKind? {
    switch self {
    case .cancellation: .cancellation
    case .materialUnavailable: .unavailable
    case .substitute, .lessonWithoutMaterial: nil
    }
  }
}

/// Die zweite Zeile einer Stunde in der Liste (UI-3, UI-4).
enum DayRowLine: Hashable {
  case statement(LessonStatement)
  case topic(String)
  case none
}

extension LessonRow {
  /// Alle zutreffenden Aussagen in dieser Reihenfolge: Ausfall; Vertretung; nicht verfügbar oder ohne
  /// Material. `availability` liefert den Zustand zur Renderzeit (die Zeile trägt nur den Stand des
  /// letzten Lesens).
  func statements(availability: (MaterialRow) -> MaterialAvailability?) -> [LessonStatement] {
    var result: [LessonStatement] = []
    switch status {
    case .cancelled: result.append(.cancellation)
    case .substitute: result.append(.substitute)
    case .regular: break
    }
    // Ein Ausfall nennt nur sich selbst: Material spielt dann keine Rolle.
    if case .cancelled = status { return result }
    if materials.isEmpty {
      result.append(.lessonWithoutMaterial)
    } else if materials.contains(where: { availability($0).isUnavailable }) {
      result.append(.materialUnavailable)
    }
    return result
  }

  /// Eine Zeile für die Liste (UI-3, UI-4): erste Aussage, sonst Thema, sonst nichts.
  func listLine(availability: (MaterialRow) -> MaterialAvailability?) -> DayRowLine {
    if let first = statements(availability: availability).first { return .statement(first) }
    if let topic = info.topic { return .topic(topic) }
    return .none
  }
}

extension Optional where Wrapped == MaterialAvailability {
  /// `nil` (noch nicht gelesen) gilt nicht als nicht verfügbar.
  var isUnavailable: Bool {
    if case .unavailable? = self { return true }
    return false
  }
}
