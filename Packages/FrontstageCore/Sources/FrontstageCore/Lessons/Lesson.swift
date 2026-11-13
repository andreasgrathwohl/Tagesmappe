/// Eine berechnete Unterrichtsstunde eines Tages.
public struct Lesson: Hashable, Sendable {
  public let key: LessonKey
  public let period: Int
  /// `nil`, wenn das Zeitraster für diese Stunde keine Zeit enthält.
  public let time: ClosedRange<TimeOfDay>?
  public let isSubstituteLesson: Bool
  public let isCancelled: Bool
  public let cancellationOrigin: Origin?

  public init(
    key: LessonKey, period: Int, time: ClosedRange<TimeOfDay>?, isSubstituteLesson: Bool,
    isCancelled: Bool, cancellationOrigin: Origin?
  ) {
    self.key = key
    self.period = period
    self.time = time
    self.isSubstituteLesson = isSubstituteLesson
    self.isCancelled = isCancelled
    self.cancellationOrigin = cancellationOrigin
  }
}
