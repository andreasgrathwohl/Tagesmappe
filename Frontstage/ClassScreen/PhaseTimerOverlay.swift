import FrontstageCore
import SwiftUI

/// Restzeit des Phasen-Timers, oben rechts über dem Zweitbildschirm (FR-11.2).
///
/// Bei `idle` erscheint nichts. Läuft der Timer ab, steht neben `0:00` ein Text „Zeit ist um“ –
/// der Ablauf darf nicht nur an Bewegung oder Farbe erkennbar sein (DESIGN.md „Wiederkehrende Fallen“).
struct PhaseTimerOverlay: View {
  @Environment(LessonSessionState.self) private var session

  var body: some View {
    if session.timer.state != .idle {
      // Eigene Sekundentaktung; die Restzeit rechnet aus dem Endzeitpunkt, nicht aus Ticks.
      TimelineView(.periodic(from: .now, by: 1)) { context in
        let remaining = session.timer.remaining(at: context.date) ?? 0
        let expired = session.timer.isExpired(at: context.date)
        VStack(alignment: .trailing, spacing: 4) {
          Text(PhaseTimer.format(remaining))
            .font(.system(.largeTitle, design: .rounded)).bold()
            .monospacedDigit()
          if expired {
            Text("timer.expired").font(.title2)
          }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(32)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
  }
}
