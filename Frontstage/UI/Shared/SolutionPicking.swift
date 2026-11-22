import FrontstageCore
import SwiftUI
import UniformTypeIdentifiers

/// Ziel des Ablaufs „Lösung hinzufügen/ersetzen“ (FR-6.3): die Zuordnung und ihr Blatt.
struct SolutionTarget: Identifiable, Equatable {
  let linkID: UUID
  let sheet: MaterialReference
  var id: UUID { linkID }
}

/// Ablauf „Lösung hinzufügen“ (FR-6.3): erst der Vorschlag aus dem Ordner des Blatts, sonst oder auf Wunsch die
/// Dateiauswahl (nur PDF und Bild). Gespeichert wird über `PreparationStore.setSolution(_:forLinkID:)`.
///
/// Swift-Hinweis: Zwei `.fileImporter` am selben Knoten stören sich in SwiftUI (nur einer öffnet). Deshalb hängt die
/// Dateiauswahl hier an einem unsichtbaren Hintergrund – einem eigenen Knoten neben dem der Ansicht.
struct SolutionPicking: ViewModifier {
  @Binding var target: SolutionTarget?
  /// Nach dem Speichern (z. B. neu laden).
  var onChange: () -> Void = {}

  @Environment(AppEnvironment.self) private var environment
  @Environment(\.showSetup) private var showSetup
  @State private var suggestion: Suggestion?
  @State private var importTarget: SolutionTarget?
  @State private var failure: Failure?

  private struct Suggestion: Identifiable {
    let target: SolutionTarget
    let solution: MaterialReference
    var id: UUID { target.linkID }
  }

  private enum Failure: Identifiable {
    case outsideGrants
    case saveFailed
    var id: Self { self }
    var messageKey: LocalizedStringKey {
      switch self {
      case .outsideGrants: "dayView.outsideGrants"
      case .saveFailed: "solution.saveFailed"
      }
    }
  }

  func body(content: Content) -> some View {
    content
      .onChange(of: target) { _, new in
        guard let new else { return }
        target = nil
        if let found = environment.storage.suggestedSolution(for: new.sheet) {
          suggestion = Suggestion(target: new, solution: found)
        } else {
          importTarget = new
        }
      }
      .confirmationDialog(
        Text("solution.suggestion.title \(suggestion?.solution.displayName ?? "")"),
        isPresented: Binding(get: { suggestion != nil }, set: { if !$0 { suggestion = nil } }),
        titleVisibility: .visible, presenting: suggestion
      ) { offer in
        Button("solution.suggestion.use") { save(offer.solution, for: offer.target) }
        Button("solution.suggestion.other") { importTarget = offer.target }
        Button("dayView.cancel", role: .cancel) {}
      }
      .background {
        Color.clear
          .fileImporter(
            isPresented: Binding(get: { importTarget != nil }, set: { if !$0 { importTarget = nil } }),
            allowedContentTypes: [.pdf, .image]
          ) { result in
            guard let current = importTarget else { return }
            importTarget = nil
            guard case .success(let url) = result else { return }
            guard let reference = environment.storage.reference(forPickedFile: url) else {
              failure = .outsideGrants
              return
            }
            save(reference, for: current)
          }
      }
      .alert(
        Text(failure?.messageKey ?? ""),
        isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } }), presenting: failure
      ) { failure in
        if failure == .outsideGrants {
          Button("dayView.grantFolder") { showSetup() }
        }
        Button("dayView.ok", role: .cancel) {}
      }
  }

  private func save(_ solution: MaterialReference, for target: SolutionTarget) {
    do {
      try environment.store.setSolution(solution, forLinkID: target.linkID)
      environment.storage.refreshAvailability(for: [solution])
      onChange()
    } catch {
      failure = .saveFailed
    }
  }
}

extension View {
  /// Hängt den Ablauf „Lösung hinzufügen“ an (FR-6.3); `target` setzen startet ihn.
  func solutionPicking(target: Binding<SolutionTarget?>, onChange: @escaping () -> Void = {}) -> some View {
    modifier(SolutionPicking(target: target, onChange: onChange))
  }
}
