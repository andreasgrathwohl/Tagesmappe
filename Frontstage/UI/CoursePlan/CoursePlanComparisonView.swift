import FrontstageCore
import SwiftUI

/// Frühere Jahre nebeneinander (FR-15.3): oben die Auswahl der Jahre, darunter ein Raster mit einer
/// Zeile je Unterrichtswoche. Nur lesend – keine Eingabefelder, keine Änderungsaktionen.
///
/// Systemstandard (`List`, `Grid`, `ScrollView`); die Vergleichsdarstellung und ihre Breite am iPad
/// im Hochformat sind eine offene Gestaltungskategorie.
struct CoursePlanComparisonView: View {
  @State private var model: CoursePlanComparisonModel
  private let store: any CoursePlanStore
  @Environment(\.dismiss) private var dismiss

  /// Breite der Wochenspalte und je Planspalte; bei vier Jahren scrollt das Raster waagerecht.
  private let labelWidth: CGFloat = 96
  private let columnWidth: CGFloat = 220

  init(planID: UUID, store: any CoursePlanStore) {
    self.store = store
    _model = State(initialValue: CoursePlanComparisonModel(planID: planID, store: store))
  }

  var body: some View {
    NavigationStack {
      Group {
        if model.earlier.isEmpty {
          ContentUnavailableView(
            "coursePlan.compare.none", systemImage: "clock.arrow.circlepath")
        } else {
          content
        }
      }
      .navigationTitle(Text("coursePlan.compare.title"))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("coursePlan.compare.done") { dismiss() }
        }
      }
    }
    // Neuer Stand von diesem oder dem anderen Gerät → neu lesen.
    .onChange(of: store.revision) { model.reload() }
  }

  private var content: some View {
    VStack(spacing: 0) {
      yearPicker
      Divider()
      grid
    }
  }

  /// Jahre zum An- und Abwählen; der aktuelle Plan ist immer dabei und steht nicht zur Wahl.
  private var yearPicker: some View {
    ScrollView(.horizontal) {
      HStack {
        ForEach(model.earlier) { plan in
          let isSelected = model.selected.contains(plan.id)
          Toggle(
            CoursePlanFormat.yearTitle(plan.key.startYear),
            isOn: Binding(get: { isSelected }, set: { _ in model.toggle(plan.id) })
          )
          .toggleStyle(.button)
          .frame(minHeight: 44)
        }
      }
      .padding(.horizontal)
    }
    .scrollIndicators(.hidden)
  }

  private var grid: some View {
    ScrollView([.horizontal, .vertical]) {
      Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 0) {
        GridRow {
          Color.clear.frame(width: labelWidth, height: 1)
          ForEach(Array(model.columnTitles.enumerated()), id: \.offset) { _, title in
            Text(verbatim: title)
              .font(.headline)
              .frame(width: columnWidth, alignment: .leading)
              .accessibilityAddTraits(.isHeader)
          }
        }
        Divider().gridCellUnsizedAxes(.horizontal)
        ForEach(model.rows, id: \.number) { row in
          if row.cells.contains(where: { $0?.startsSecondTerm == true }) {
            secondTermDivider
          }
          GridRow {
            Text("coursePlan.compare.week \(row.number)")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .frame(width: labelWidth, alignment: .leading)
              .padding(.vertical, 6)
            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
              cellView(cell)
            }
          }
        }
      }
      .padding()
    }
  }

  /// Trennlinie mit Beschriftung (ein Grid-Element außerhalb einer `GridRow` füllt die ganze Zeile) vor der Zeile, in der in einem Jahr das 2. Halbjahr beginnt.
  private var secondTermDivider: some View {
    VStack(alignment: .leading, spacing: 2) {
      Divider()
      Text("coursePlan.compare.secondTerm")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.top, 8)
  }

  @ViewBuilder
  private func cellView(_ cell: ComparisonCell?) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      if let cell {
        if let topic = cell.topic {
          Text(verbatim: topic)
        }
        ForEach(cell.assessments, id: \.id) { assessment in
          Text(verbatim: CoursePlanFormat.assessmentLine(assessment))
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
    }
    .frame(width: columnWidth, alignment: .topLeading)
    .padding(.vertical, 6)
  }
}
