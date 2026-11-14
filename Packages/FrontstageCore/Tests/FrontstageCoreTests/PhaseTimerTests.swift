import Foundation
import Testing
@testable import FrontstageCore

private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

@Suite struct PhaseTimerTests {
  @Test("AK-26: 5 Minuten starten zeigt 5:00, nach 1 Minute 4:00") func countsDownFromEndDate() {
    var t = PhaseTimer(); t.start(duration: 300, now: t0)
    #expect(PhaseTimer.format(t.remaining(at: t0)!) == "5:00")
    #expect(PhaseTimer.format(t.remaining(at: t0 + 60)!) == "4:00")
    #expect(PhaseTimer.format(t.remaining(at: t0 + 30.5)!) == "4:30")  // aufgerundet
  }
  @Test("AK-26: Anhalten bleibt bei 4:00 stehen") func pauseFreezesRemaining() {
    var t = PhaseTimer(); t.start(duration: 300, now: t0); t.pause(now: t0 + 60)
    #expect(PhaseTimer.format(t.remaining(at: t0 + 600)!) == "4:00")
    t.resume(now: t0 + 600)
    #expect(PhaseTimer.format(t.remaining(at: t0 + 660)!) == "3:00")
  }
  @Test("AK-26: Beenden zeigt keinen Timer mehr") func stopClearsTimer() {
    var t = PhaseTimer(); t.start(duration: 300, now: t0); t.stop()
    #expect(t.remaining(at: t0 + 1) == nil)
    #expect(t.state == .idle)
  }
  @Test("AK-26: Ablauf – Restzeit 0, abgelaufen, Signal fällig") func expiresAtEndDate() {
    var t = PhaseTimer(); t.start(duration: 300, now: t0)
    #expect(t.isExpired(at: t0 + 299) == false)
    #expect(t.isExpired(at: t0 + 300))
    #expect(t.remaining(at: t0 + 400) == 0)
    #expect(t.shouldPlaySignal(at: t0 + 300.5))
  }
  @Test("Review Focus 1: Ablauf liegt länger zurück – kein verspätetes Signal") func signalIsSkippedWhenExpiryLongPast() {
    var t = PhaseTimer(); t.start(duration: 300, now: t0)
    #expect(t.shouldPlaySignal(at: t0 + 303) == false)
    #expect(t.isExpired(at: t0 + 303))
  }
  @Test("Angehaltener Timer läuft nie ab") func pausedNeverExpires() {
    var t = PhaseTimer(); t.start(duration: 300, now: t0); t.pause(now: t0 + 10)
    #expect(t.isExpired(at: t0 + 10_000) == false)
  }
  @Test("Format über eine Stunde: 61:00") func formatsLongDurations() {
    #expect(PhaseTimer.format(3660) == "61:00")
  }
  @Test("Pause und Fortsetzen aus idle sind wirkungslos") func pauseResumeFromIdleDoNothing() {
    var t = PhaseTimer(); t.pause(now: t0); t.resume(now: t0)
    #expect(t.state == .idle)
  }
}
