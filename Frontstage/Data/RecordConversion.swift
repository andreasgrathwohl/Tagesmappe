import Foundation
import FrontstageCore

// Übersetzung zwischen den SwiftData-Datensätzen (Rohwerte, Text) und den reinen Kern-Typen.
// Unlesbare Rohwerte führen nie zum Absturz: Sie ergeben `nil` oder einen dokumentierten Rückfallwert.
// Hinweis zu Swift: Eine `extension` auf einer `@Model`-Klasse ist erlaubt, solange sie keine
// gespeicherten Eigenschaften hinzufügt; berechnete Eigenschaften und Methoden sind unproblematisch.

// MARK: - Stundenplan

extension TimetableRecord {
  /// Berechnet den Kern-Stundenplan. Fehlt die Bezugswoche, gilt der Tag von `createdAt`;
  /// ein nicht lesbares Zeitraster ergibt ein leeres Zeitraster.
  func makeTimetable() -> Timetable {
    let referenceWeek =
      referenceWeekAText.flatMap { CalendarDay(storageText: $0) }
      ?? CalendarDay(createdAt, calendar: .current)
    let bells =
      bellScheduleData.flatMap { try? JSONDecoder().decode(BellSchedule.self, from: $0) }
      ?? BellSchedule()
    // Die Beziehung ist ungeordnet: für ein stabiles Ergebnis nach Wochentag und Stunde sortieren.
    let converted = (entries ?? []).compactMap { $0.makeEntry() }.sorted {
      ($0.weekday.rawValue, $0.period, $0.schoolClass.normalized)
        < ($1.weekday.rawValue, $1.period, $1.schoolClass.normalized)
    }
    return Timetable(
      weekVariantCount: weekVariantCount, referenceWeekA: referenceWeek, bellSchedule: bells,
      entries: converted)
  }

  /// Speichert das Zeitraster als JSON in `bellScheduleData`.
  func setBellSchedule(_ schedule: BellSchedule) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    bellScheduleData = try? encoder.encode(schedule)
  }

  func snapshot() -> TimetableSnapshot {
    TimetableSnapshot(id: id, isActive: isActive, createdAt: createdAt)
  }
}

extension TimetableEntryRecord {
  /// `nil` bei ungültigem Wochentag oder ungültiger Wochenvariante.
  func makeEntry() -> TimetableEntry? {
    guard let weekday = Weekday(rawValue: weekdayRaw) else { return nil }
    var variant: WeekVariant?
    if let raw = weekVariantRaw {
      guard let parsed = WeekVariant(rawValue: raw) else { return nil }
      variant = parsed
    }
    return TimetableEntry(
      weekVariant: variant, weekday: weekday, period: period, schoolClass: SchoolClass(schoolClassText),
      subject: Subject(subjectText))
  }

  /// Übernimmt die Felder des Eintrags; Klasse normalisiert, Fach in Anzeigeschreibweise.
  /// `isManuallyEdited` bleibt unberührt, das entscheidet der Aufrufer.
  func apply(_ entry: TimetableEntry, origin: Origin) {
    weekVariantRaw = entry.weekVariant?.rawValue
    weekdayRaw = entry.weekday.rawValue
    period = entry.period
    schoolClassText = entry.schoolClass.normalized
    subjectText = entry.subject.display
    originRaw = origin.rawValue
  }

  /// Herkunft; ein unbekannter Rohwert gilt als `.manual`.
  var origin: Origin { Origin(rawValue: originRaw) ?? .manual }

  func snapshot() -> TimetableEntrySnapshot? {
    guard let entry = makeEntry() else { return nil }
    return TimetableEntrySnapshot(id: id, timetableID: timetable?.id, entry: entry, createdAt: createdAt)
  }
}

// MARK: - Unterrichtsfreie Zeit und Abweichungen

extension NonTeachingPeriodRecord {
  /// `nil`, wenn einer der beiden Tagestexte nicht lesbar ist.
  func makePeriod() -> NonTeachingPeriod? {
    guard let from = CalendarDay(storageText: fromText), let to = CalendarDay(storageText: toText) else {
      return nil
    }
    return NonTeachingPeriod(from: from, to: to, title: title)
  }

  func apply(_ period: NonTeachingPeriod) {
    fromText = period.from.storageText
    toText = period.to.storageText
    title = period.title
  }

  func snapshot() -> NonTeachingPeriodSnapshot? {
    guard let period = makePeriod() else { return nil }
    return NonTeachingPeriodSnapshot(id: id, period: period, createdAt: createdAt)
  }
}

extension ScheduleChangeRecord {
  private static let cancellationKind = "cancellation"
  private static let substituteKind = "substituteLesson"

  /// `nil` bei unbekannter Art oder fehlenden/unlesbaren Feldern.
  func makeChange() -> ScheduleChange? {
    let origin = Origin(rawValue: originRaw) ?? .manual
    switch kindRaw {
    case Self.cancellationKind:
      guard let text = lessonKeyText, let key = LessonKey(storageText: text) else { return nil }
      return .cancellation(key, origin)
    case Self.substituteKind:
      guard let day = CalendarDay(storageText: dayText), let period, let schoolClassText,
        let subjectText
      else { return nil }
      return .substituteLesson(
        date: day, period: period, schoolClass: SchoolClass(schoolClassText),
        subject: Subject(subjectText), origin)
    default:
      return nil
    }
  }

  /// Schreibt alle Felder neu; Felder der jeweils anderen Art werden auf `nil` gesetzt.
  func apply(_ change: ScheduleChange) {
    switch change {
    case .cancellation(let key, let origin):
      kindRaw = Self.cancellationKind
      originRaw = origin.rawValue
      dayText = key.date.storageText
      lessonKeyText = key.storageText
      period = nil
      schoolClassText = nil
      subjectText = nil
    case .substituteLesson(let date, let lessonPeriod, let schoolClass, let subject, let origin):
      kindRaw = Self.substituteKind
      originRaw = origin.rawValue
      dayText = date.storageText
      lessonKeyText = nil
      period = lessonPeriod
      schoolClassText = schoolClass.normalized
      subjectText = subject.display
    }
  }

  func snapshot() -> ScheduleChangeSnapshot? {
    guard let change = makeChange() else { return nil }
    return ScheduleChangeSnapshot(id: id, change: change, createdAt: createdAt)
  }
}

// MARK: - Material, Stiftnotizen, Tafel

extension MaterialLinkRecord {
  /// Schlüssel der Stunde; `nil` bei „Material ohne Stunde“ oder unlesbarem Text.
  var lessonKey: LessonKey? { LessonKey(storageText: lessonKeyText) }

  /// Setzt Schlüsseltext und Tagestext zugleich (Abfrage je Tag, ohne das Schlüsselformat zu kennen).
  func setLessonKey(_ key: LessonKey) {
    lessonKeyText = key.storageText
    dayText = key.date.storageText
  }

  /// Verweis aus den Feldern am Datensatz; ein unbekannter `fileKindRaw` ergibt `.other`.
  var reference: MaterialReference {
    MaterialReference(
      folderGrantName: folderGrantName, relativePath: relativePath, displayName: displayName,
      fileKind: MaterialFileKind(rawValue: fileKindRaw) ?? .other, oneDriveItemID: oneDriveItemID,
      oneDriveDriveID: oneDriveDriveID)
  }

  func setReference(_ reference: MaterialReference) {
    folderGrantName = reference.folderGrantName
    relativePath = reference.relativePath
    displayName = reference.displayName
    fileKindRaw = reference.fileKind.rawValue
    oneDriveItemID = reference.oneDriveItemID
    oneDriveDriveID = reference.oneDriveDriveID
  }

  /// Lösung (FR-6.3); `nil`, solange kein Pfad gesetzt ist.
  var solution: MaterialReference? {
    guard let path = solutionRelativePath, !path.isEmpty else { return nil }
    return MaterialReference(
      folderGrantName: solutionFolderGrantName ?? "", relativePath: path, displayName: solutionDisplayName ?? "",
      fileKind: MaterialFileKind(rawValue: solutionFileKindRaw ?? "") ?? .other,
      oneDriveItemID: solutionOneDriveItemID, oneDriveDriveID: solutionOneDriveDriveID)
  }

  /// Setzt oder entfernt (`nil`) die Lösung.
  func setSolution(_ reference: MaterialReference?) {
    solutionFolderGrantName = reference?.folderGrantName
    solutionRelativePath = reference?.relativePath
    solutionDisplayName = reference?.displayName
    solutionFileKindRaw = reference?.fileKind.rawValue
    solutionOneDriveItemID = reference?.oneDriveItemID
    solutionOneDriveDriveID = reference?.oneDriveDriveID
  }

  func snapshot() -> MaterialLinkSnapshot {
    MaterialLinkSnapshot(
      id: id, lessonKeyText: lessonKeyText, fileIdentity: reference.fileIdentity, createdAt: createdAt,
      hasSolution: solution != nil)
  }
}

extension PenNoteRecord {
  func snapshot() -> PenNoteSnapshot {
    PenNoteSnapshot(
      id: id, linkID: materialLink?.id, pageIndex: pageIndex, createdAt: createdAt, updatedAt: updatedAt)
  }
}

extension BoardPageRecord {
  /// Hintergrund der Seite; ein unbekannter Rohwert ergibt `.blank`.
  var background: BoardBackground {
    get { BoardBackground(rawValue: backgroundRaw) ?? .blank }
    set { backgroundRaw = newValue.rawValue }
  }
}

// MARK: - Stundenangaben

extension LessonInfoRecord {
  func makeInfo() -> LessonInfo {
    LessonInfo(topic: topic, toPrepare: toPrepare, homework: homework)
  }

  /// Übernimmt nur geänderte Felder, setzt deren `*UpdatedAt` und `updatedAt` auf `now`.
  /// Verglichen wird der normalisierte neue Wert mit dem gespeicherten.
  func apply(_ info: LessonInfo, now: Date) {
    let new = info.normalized()
    var changed = false
    if new.topic != topic {
      topic = new.topic
      topicUpdatedAt = now
      changed = true
    }
    if new.toPrepare != toPrepare {
      toPrepare = new.toPrepare
      toPrepareUpdatedAt = now
      changed = true
    }
    if new.homework != homework {
      homework = new.homework
      homeworkUpdatedAt = now
      changed = true
    }
    if changed { updatedAt = now }
  }

  func snapshot() -> LessonInfoSnapshot {
    var stamps: [LessonInfoField: Date] = [:]
    if let topicUpdatedAt { stamps[.topic] = topicUpdatedAt }
    if let toPrepareUpdatedAt { stamps[.toPrepare] = toPrepareUpdatedAt }
    if let homeworkUpdatedAt { stamps[.homework] = homeworkUpdatedAt }
    return LessonInfoSnapshot(
      id: id, lessonKeyText: lessonKeyText, createdAt: createdAt, fieldUpdatedAt: stamps)
  }
}
