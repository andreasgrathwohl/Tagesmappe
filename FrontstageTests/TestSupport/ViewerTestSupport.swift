import Foundation
import FrontstageCore
import PencilKit

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Erfundene Zeichnungen für die Tests des Betrachters. Task 5 ergänzt die Datei um weitere Hilfen.
enum TestDrawings {
  /// Ein Strich von `start` nach `end`.
  static func line(from start: CGPoint, to end: CGPoint) -> PKDrawing {
    PKDrawing(strokes: [stroke(from: start, to: end)])
  }

  /// Eine Notiz mit einem Strich.
  static var word: PKDrawing {
    line(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 150, y: 80))
  }

  /// Eine Notiz mit zwei Strichen.
  static var twoWords: PKDrawing {
    PKDrawing(strokes: [
      stroke(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 150, y: 80)),
      stroke(from: CGPoint(x: 60, y: 200), to: CGPoint(x: 220, y: 230)),
    ])
  }

  private static func stroke(from start: CGPoint, to end: CGPoint) -> PKStroke {
    #if os(iOS)
      let color = UIColor.black
    #else
      let color = NSColor.black
    #endif
    let points = [start, end].enumerated().map { index, location in
      PKStrokePoint(
        location: location, timeOffset: TimeInterval(index) * 0.1, size: CGSize(width: 4, height: 4),
        opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
    }
    return PKStroke(
      ink: PKInk(.pen, color: color),
      path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))
  }
}

/// Erfundene Stundenschlüssel (nur Klassen `8a`/`8b`, Fach „Englisch“, 17.–19.11.2026).
enum TestKeys {
  static let tue8aEnglish = key("8a", day: 17)
  static let wed8bEnglish = key("8b", day: 18)
  static let thu8aEnglish = key("8a", day: 19)
  static let tue8bEnglish = key("8b", day: 17)
  static let thu8bEnglish = key("8b", day: 19)

  private static func key(_ schoolClass: String, day: Int) -> LessonKey {
    LessonKey(
      date: CalendarDay(year: 2026, month: 11, day: day), schoolClass: SchoolClass(schoolClass),
      subject: Subject("Englisch"), ordinal: 1)
  }
}
