/// Ersetzt die aus der Quelle stammenden Abweichungen eines Zeitraums, ohne Handarbeit anzutasten.
public enum ScheduleChangeMerger {
  /// Behält alle `.manual`; entfernt `.source` mit Datum in `range`; hängt `new` an. `.source` außerhalb bleibt.
  public static func replacingSourceChanges(
    in existing: [ScheduleChange], with new: [ScheduleChange], range: ClosedRange<CalendarDay>
  ) -> [ScheduleChange] {
    existing.filter { !(origin(of: $0) == .source && range.contains(date(of: $0))) } + new
  }

  private static func origin(of change: ScheduleChange) -> Origin {
    switch change {
    case let .cancellation(_, origin): return origin
    case let .substituteLesson(_, _, _, _, origin): return origin
    }
  }

  private static func date(of change: ScheduleChange) -> CalendarDay {
    switch change {
    case let .cancellation(key, _): return key.date
    case let .substituteLesson(date, _, _, _, _): return date
    }
  }
}
