import FrontstageCore
import SwiftUI

/// Listenzeile einer Unterrichtsstunde (UI-4, UI-12): oben „8b · Englisch“ (bei Ausfall durchgestrichen) und
/// rechtsbündig „2. Stunde · 08:35 – 09:20“; darunter die zweite Zeile und am Ende ggf. „Jetzt“.
/// Ein Element für VoiceOver. Die Auswahlfläche zeichnet die Liste selbst (UI-3).
struct DayListRow: View {
  let row: LessonRow
  let line: DayRowLine
  let isRunning: Bool

  @Environment(\.themeStyle) private var style
  @ScaledMetric(relativeTo: .body) private var minHeight = DayViewLayout.rowHeight

  init(row: LessonRow, line: DayRowLine, isRunning: Bool) {
    self.row = row
    self.line = line
    self.isRunning = isRunning
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: DayViewLayout.sectionSpacing) {
        Text(verbatim: "\(row.lesson.key.schoolClass.normalized) · \(row.lesson.key.subject.display)")
          .scaledFont(.listTitle)
          .foregroundStyle(style.text)
          .strikethrough(isCancelled)
          .lineLimit(1)
        Spacer(minLength: 0)
        Text(periodTime)
          .scaledFont(.listMeta)
          .foregroundStyle(style.text)
          .monospacedDigit()
          .lineLimit(1)
      }
      HStack(spacing: DayViewLayout.tileSpacing) {
        secondLine
        Spacer(minLength: 0)
        if isRunning {
          SignalCapsule(.now).transition(.opacity)
        }
      }
    }
    .animation(.snappy(duration: 0.15), value: isRunning)
    .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
    .contentShape(Rectangle())
    // Klasse, Fach, Stunde, Zeit, Aussage bzw. Thema und „läuft jetzt“ in einem Element.
    .accessibilityElement(children: .combine)
  }

  private var isCancelled: Bool {
    if case .cancelled = row.status { return true }
    return false
  }

  @ViewBuilder private var secondLine: some View {
    switch line {
    case .statement(let statement):
      StatementView(statement, scale: .listMeta)
    case .topic(let topic):
      Text(verbatim: topic)
        .scaledFont(.listMeta)
        .foregroundStyle(style.text)
        .lineLimit(1)
    case .none:
      EmptyView()
    }
  }

  private var periodTime: Text {
    guard let time = row.lesson.time else { return Text("dayView.period \(row.lesson.period)") }
    return Text(
      "dayView.row.periodTime \(row.lesson.period) \(LessonTimeFormat.range(time, on: row.lesson.key.date))")
  }
}

/// Lücke im Stundenplan: „Keine Stunde“ als Titel ohne Symbol (UI-11), Stunde und Uhrzeit rechts.
struct DayGapRow: View {
  let period: Int
  let time: ClosedRange<TimeOfDay>?
  let day: CalendarDay

  @Environment(\.themeStyle) private var style
  @ScaledMetric(relativeTo: .body) private var minHeight = DayViewLayout.rowHeight

  init(period: Int, time: ClosedRange<TimeOfDay>?, day: CalendarDay) {
    self.period = period
    self.time = time
    self.day = day
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: DayViewLayout.sectionSpacing) {
      Text("dayView.statement.noLesson")
        .scaledFont(.listTitle)
        .foregroundStyle(style.text)
        .lineLimit(1)
      Spacer(minLength: 0)
      periodTime
        .scaledFont(.listMeta)
        .foregroundStyle(style.text)
        .monospacedDigit()
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  private var periodTime: Text {
    guard let time else { return Text("dayView.period \(period)") }
    return Text("dayView.row.periodTime \(period) \(LessonTimeFormat.range(time, on: day))")
  }
}
