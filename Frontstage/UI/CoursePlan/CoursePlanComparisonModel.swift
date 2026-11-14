import Foundation
import FrontstageCore
import Observation

/// Logik der Ansicht „Frühere Jahre“ (FR-15.3): legt den aktuellen Jahresplan und frühere Jahre
/// desselben Fachs und Jahrgangs Woche für Woche nebeneinander. Nur lesend; das Modell schreibt nie
/// in den Store.
///
/// Swift-Hinweis: `@Observable` ersetzt `ObservableObject`; `didSet` an einer beobachteten
/// Eigenschaft funktioniert weiter und baut hier die Zeilen neu auf.
@MainActor @Observable final class CoursePlanComparisonModel {
  /// Höchstzahl der Spalten (aktueller Plan eingeschlossen).
  static let maxColumns = 4

  private let planID: UUID
  private let store: any CoursePlanStore

  private var current: CoursePlanSummary?
  /// Frühere Jahre desselben Fachs und Jahrgangs, neuestes zuerst.
  private(set) var earlier: [CoursePlanSummary] = []
  /// Gewählte Pläne: zuerst der aktuelle, danach frühere Jahre, neuestes zuerst.
  var selected: [UUID] = [] {
    didSet { rebuild() }
  }
  /// „2026/27“, „2025/26“, … je gewählter Spalte.
  private(set) var columnTitles: [String] = []
  private(set) var rows: [ComparisonRow] = []

  init(planID: UUID, store: any CoursePlanStore) {
    self.planID = planID
    self.store = store
    reload()
  }

  /// Liest die Liste neu und behält die Auswahl, soweit die Pläne noch existieren.
  func reload() {
    let summaries = (try? store.coursePlanSummaries()) ?? []
    guard let current = summaries.first(where: { $0.id == planID }) else {
      self.current = nil
      earlier = []
      selected = []
      return
    }
    self.current = current
    let keys = CoursePlanHistory.earlier(than: current.key, among: summaries.map(\.key))
    earlier = keys.compactMap { key in summaries.first { $0.key == key } }

    let previous = selected.filter { id in earlier.contains { $0.id == id } }
    let chosen =
      selected.isEmpty
      ? Array(earlier.prefix(2).map(\.id))
      : previous
    selected = [planID] + chosen
  }

  /// Wählt einen früheren Plan an oder ab; der aktuelle Plan bleibt immer in der Auswahl und es gibt
  /// höchstens vier Spalten (ein weiterer Plan wird dann nicht aufgenommen).
  func toggle(_ id: UUID) {
    guard id != planID, earlier.contains(where: { $0.id == id }) else { return }
    var chosen = selected.filter { $0 != planID }
    if let index = chosen.firstIndex(of: id) {
      chosen.remove(at: index)
    } else if chosen.count + 1 < Self.maxColumns {
      chosen.append(id)
    } else {
      return
    }
    // Reihenfolge der Liste (neuestes zuerst), nicht der Anwahl.
    let ordered = earlier.map(\.id).filter { chosen.contains($0) }
    selected = [planID] + ordered
  }

  private func rebuild() {
    var titles: [String] = []
    var columns: [ComparisonColumn] = []
    for id in selected {
      guard let content = try? store.coursePlan(id: id) else { continue }
      let weeks = (try? store.teachingWeeks(startYear: content.key.startYear)) ?? []
      columns.append(
        ComparisonColumn(
          key: content.key, weeks: weeks, planWeeks: content.planWeeks,
          assessments: content.assessments))
      titles.append(CoursePlanFormat.yearTitle(content.key.startYear))
    }
    columnTitles = titles
    rows = CoursePlanComparison.rows(columns)
  }
}
