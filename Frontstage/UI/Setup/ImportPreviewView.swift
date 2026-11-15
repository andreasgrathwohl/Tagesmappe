import FrontstageCore
import SwiftUI

/// Gruppen der Vorschau in fester Reihenfolge (neu, geändert, von Hand geändert, entfällt, Zeitraster);
/// reine Ableitung aus `ImportPreview`, testbar ohne Ansicht.
///
/// Swift-Hinweis: Tupel-Arrays sind nicht automatisch `Equatable`; deshalb ist `==` von Hand über die Elemente
/// geschrieben (wie bei `ImportPreview`).
struct ImportPreviewModel: Equatable {
  var added: [TimetableEntry]
  var changed: [(old: TimetableEntry, new: TimetableEntry)]
  var conflicts: [(mine: TimetableEntry, source: TimetableEntry)]
  var removed: [TimetableEntry]
  var bellScheduleChanged: Bool
  var fetchedAt: Date
  /// Quell-Fassungen, die eine eigene ersetzen sollen. Startwert leer = „Meine Fassung behalten“ (AK-3).
  var acceptedFromSource: Set<TimetableEntry> = []

  init(preview: ImportPreview) {
    added = preview.diff.added
    changed = preview.diff.changed
    conflicts = preview.diff.manualConflicts
    removed = preview.diff.removed
    bellScheduleChanged = preview.bellScheduleChanged
    fetchedAt = preview.snapshot.fetchedAt
  }

  /// `true`, wenn der Import nichts verändert (nichts zu zeigen, Übernehmen ist dann folgenlos).
  var isEmpty: Bool {
    added.isEmpty && changed.isEmpty && conflicts.isEmpty && removed.isEmpty && !bellScheduleChanged
  }

  /// Wählt bei einem Konflikt die Quell-Fassung (`source: true`) oder die eigene (`false`).
  /// `conflict` ist die eigene Fassung (`mine`) und kennzeichnet den Konflikt; unbekannte Einträge ändern nichts.
  mutating func choose(source: Bool, for conflict: TimetableEntry) {
    guard let pair = conflicts.first(where: { $0.mine == conflict }) else { return }
    if source {
      acceptedFromSource.insert(pair.source)
    } else {
      acceptedFromSource.remove(pair.source)
    }
  }

  static func == (lhs: ImportPreviewModel, rhs: ImportPreviewModel) -> Bool {
    lhs.added == rhs.added && lhs.removed == rhs.removed
      && lhs.bellScheduleChanged == rhs.bellScheduleChanged && lhs.fetchedAt == rhs.fetchedAt
      && lhs.acceptedFromSource == rhs.acceptedFromSource
      && lhs.changed.elementsEqual(rhs.changed, by: { $0.old == $1.old && $0.new == $1.new })
      && lhs.conflicts.elementsEqual(rhs.conflicts, by: { $0.mine == $1.mine && $0.source == $1.source })
  }
}

/// Import-Abgleich als Sheet (FR-2, AK-3): zeigt, was der Import am Stundenplan ändert, und lässt bei
/// von Hand geänderten Stunden die Wahl. „Abbrechen“ verwirft die Vorschau, „Übernehmen“ schreibt alles oder nichts.
/// Systemstandard; offene Gestaltungskategorien (Zustände, Wortlaut, Dichte) sind nicht entschieden.
struct ImportPreviewView: View {
  @Environment(TimetableSourceCoordinator.self) private var coordinator
  @Environment(\.dismiss) private var dismiss

  @State private var model: ImportPreviewModel
  @State private var failed = false

  init(preview: ImportPreview) {
    _model = State(initialValue: ImportPreviewModel(preview: preview))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text("importPreview.fetchedAt \(model.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
        }
        if model.isEmpty {
          Section { Text("importPreview.noDifferences") }
        }
        if !model.added.isEmpty {
          Section("importPreview.added") {
            ForEach(model.added, id: \.self) { EntryRow(entry: $0) }
          }
        }
        if !model.changed.isEmpty {
          Section("importPreview.changed") {
            ForEach(model.changed.indices, id: \.self) { index in
              let pair = model.changed[index]
              VStack(alignment: .leading) {
                EntryRow(entry: pair.old).foregroundStyle(.secondary)
                Label {
                  EntryRow(entry: pair.new)
                } icon: {
                  Image(systemName: "arrow.right")
                }
              }
            }
          }
        }
        if !model.conflicts.isEmpty {
          Section {
            ForEach(model.conflicts.indices, id: \.self) { index in
              conflictRow(model.conflicts[index])
            }
          } header: {
            Text("importPreview.conflicts")
          } footer: {
            Text("importPreview.conflicts.footer")
          }
        }
        if !model.removed.isEmpty {
          Section("importPreview.removed") {
            ForEach(model.removed, id: \.self) { EntryRow(entry: $0) }
          }
        }
        if model.bellScheduleChanged {
          Section { Label("importPreview.bellScheduleChanged", systemImage: "clock") }
        }
        if failed {
          Section {
            Label("importPreview.error.apply", systemImage: "exclamationmark.triangle")
              .foregroundStyle(.red)
          }
        }
      }
      .themedBackground()
      .navigationTitle("timetableSource.preview.title")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("importPreview.cancel") {
            coordinator.discardPendingPreview()
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("importPreview.apply") { apply() }
        }
      }
    }
  }

  /// Je Konflikt eine Wahl zwischen eigener und Quell-Fassung; beide stehen als Text, nicht nur als Farbe.
  private func conflictRow(_ pair: (mine: TimetableEntry, source: TimetableEntry)) -> some View {
    VStack(alignment: .leading) {
      Picker(selection: choiceBinding(for: pair)) {
        VStack(alignment: .leading) {
          Text("importPreview.keepMine")
          EntryRow(entry: pair.mine).font(.caption)
        }.tag(false)
        VStack(alignment: .leading) {
          Text("importPreview.takeSource")
          EntryRow(entry: pair.source).font(.caption)
        }.tag(true)
      } label: {
        EntryRow(entry: pair.mine)
      }
      .pickerStyle(.inline)
    }
  }

  private func choiceBinding(for pair: (mine: TimetableEntry, source: TimetableEntry)) -> Binding<Bool> {
    Binding(
      get: { model.acceptedFromSource.contains(pair.source) },
      set: { model.choose(source: $0, for: pair.mine) })
  }

  private func apply() {
    do {
      try coordinator.applyPendingPreview(acceptedFromSource: model.acceptedFromSource)
      dismiss()
    } catch {
      failed = true
    }
  }
}

/// Eine Zeile „Mo · 3. Std. · 8b · Englisch“ (bei A/B-Woche mit Variante).
private struct EntryRow: View {
  let entry: TimetableEntry

  var body: some View {
    HStack(spacing: 6) {
      Text(Self.weekdayName(entry.weekday))
      Text("importPreview.period \(entry.period)")
      Text(entry.schoolClass.normalized)
      Text(entry.subject.display)
      if let variant = entry.weekVariant {
        // Zwei Zweige statt `?:`: Ein Ternär über Literale würde als String (ohne Übersetzung) gelesen.
        Group {
          if variant == .a { Text("importPreview.weekA") } else { Text("importPreview.weekB") }
        }
        .foregroundStyle(.secondary)
      }
    }
  }

  /// `Calendar.shortWeekdaySymbols` beginnt mit Sonntag; `Weekday.rawValue` 1 = Montag, 7 = Sonntag.
  private static func weekdayName(_ day: Weekday) -> String {
    Calendar.current.shortWeekdaySymbols[day.rawValue % 7]
  }
}
