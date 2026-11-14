import FrontstageCore
import SwiftUI

/// Inhalt des Klassenbildschirms (FR-11, FR-11.1, FR-11.7). Reine Darstellung: bekommt nur die
/// fertige `ClassScreenDisplay` und die Uhrzeit, nie Stundenlisten oder Zuordnungen.
///
/// Gestaltung offen (Kategorien in `DESIGN.md` noch ohne Beschluss): nur Systemstile und Systemfarben.
struct ClassScreenContentView: View {
  let display: ClassScreenDisplay
  let now: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      switch display.kind {
      case .upcoming:
        Text("classScreen.upcoming").font(.title)
        header
        toPrepareLine
      case .inLesson:
        header
        untilLine
        topicLine
        toPrepareLine
        workModeLabel
      case .finalMinutes:
        header
        untilLine
        if let homework = display.homework {
          Text("classScreen.homework \(homework)").font(.largeTitle).bold()
        } else {
          topicLine
          toPrepareLine
        }
        workModeLabel
      case .clockOnly:
        EmptyView()
      }
      Spacer(minLength: 0)
      clock
    }
    .padding(48)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(SystemBackground.color)
  }

  /// Klasse und Fach; fehlt eines, entsteht keine leere Lücke.
  @ViewBuilder private var header: some View {
    let parts = [display.schoolClass, display.subject].compactMap { $0 }
    if !parts.isEmpty {
      Text(parts.joined(separator: " · ")).font(.largeTitle).bold()
    }
  }

  @ViewBuilder private var untilLine: some View {
    if let end = display.endTime {
      let text = String(format: "%02d:%02d", end.hour, end.minute)
      Text("classScreen.until \(text)").font(.title)
    }
  }

  @ViewBuilder private var topicLine: some View {
    if let topic = display.topic {
      Text(topic).font(.title)
    }
  }

  @ViewBuilder private var toPrepareLine: some View {
    if let toPrepare = display.toPrepare {
      Text("classScreen.toPrepare \(toPrepare)").font(.title2)
    }
  }

  /// Platzhalter-Symbole (Gestaltung offen).
  @ViewBuilder private var workModeLabel: some View {
    switch display.workMode {
    case .individual: Label("workMode.individual", systemImage: "person").font(.title2)
    case .pairs: Label("workMode.pairs", systemImage: "person.2").font(.title2)
    case .groups: Label("workMode.groups", systemImage: "person.3").font(.title2)
    case nil: EmptyView()
    }
  }

  /// Uhrzeit ist immer sichtbar (AK-24); Datum nur ohne laufende Stunde groß dabei.
  private var clock: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(now.formatted(date: .omitted, time: .shortened))
        .font(display.kind == .clockOnly ? .largeTitle : .title2)
        .monospacedDigit()
      if display.kind == .clockOnly {
        Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.title2)
      }
    }
  }
}
