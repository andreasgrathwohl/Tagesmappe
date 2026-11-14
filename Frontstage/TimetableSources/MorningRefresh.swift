import Foundation
import FrontstageCore

#if os(iOS)
  import BackgroundTasks
#endif

/// Die morgendliche Aktualisierung der Stundenplan-Quelle im Hintergrund (nur iPadOS).
///
/// Das System sagt keine Uhrzeit zu; maßgeblich bleibt der Abruf beim ersten Öffnen am Tag (ADR-0004, AK-21).
/// Am Mac gibt es `BGTaskScheduler` nicht – dort genügt das Aktivieren der Szene.
enum MorningRefresh {
  /// Fest, unabhängig von der Bundle-Kennung aus CI; muss wörtlich in `project.yml`
  /// (`BGTaskSchedulerPermittedIdentifiers`) stehen.
  static let taskIdentifier = "frontstage.timetable-source.morning-refresh"

  #if os(iOS)
    /// Meldet die nächste Aktualisierung an. Swift-Hinweis: Eine `BGAppRefreshTaskRequest` gilt nur für einen
    /// Lauf; nach jedem Start muss die nächste neu angemeldet werden, sonst läuft die Aufgabe nur einmal.
    /// Fehler (etwa Hintergrundaktualisierung vom Nutzer abgeschaltet) sind folgenlos: Der Abruf beim
    /// Öffnen bleibt.
    static func schedule(after now: Date = Date(), calendar: Calendar = .current) {
      let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
      request.earliestBeginDate = MorningRefreshPolicy.nextBackgroundBeginDate(
        after: now, calendar: calendar)
      try? BGTaskScheduler.shared.submit(request)
    }
  #endif
}
