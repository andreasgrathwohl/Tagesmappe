import AVFoundation

/// Signalton am Ende der Phase (FR-11.2).
///
/// Der Ton wird selbst erzeugt (Sinus 880 Hz, drei Töne zu je 0,3 s mit 0,2 s Pause) – keine Tondatei im
/// Repo. Wert ist ein Platzhalter; der Signalton ist eine offene Gestaltungskategorie.
@MainActor final class TimerSignalPlayer {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private var buffer: AVAudioPCMBuffer?
  private var isPrepared = false

  init() {}

  /// Spielt das Signal. Schlägt etwas fehl (kein Audiogerät, Sitzung nicht aktivierbar), bleibt es still:
  /// Der Timer-Ablauf ist auch ohne Ton am Bildschirm sichtbar.
  func play() {
    #if os(iOS)
      // .playback: Ton auch bei Stummschalter und über AirPlay zum Bildschirm im Klassenraum.
      let session = AVAudioSession.sharedInstance()
      try? session.setCategory(.playback)
      try? session.setActive(true)
    #endif
    guard prepare() else { return }
    if !engine.isRunning {
      do { try engine.start() } catch { return }
    }
    guard let buffer else { return }
    player.stop()
    player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    player.play()
  }

  /// Baut Puffer und Graph einmal auf.
  private func prepare() -> Bool {
    if isPrepared { return buffer != nil }
    isPrepared = true
    guard let made = Self.makeSignalBuffer() else { return false }
    buffer = made
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: made.format)
    return true
  }

  /// Drei Sinustöne mit kurzer Ein-/Ausblendung gegen Knacksen.
  static func makeSignalBuffer(
    sampleRate: Double = 44_100, frequency: Double = 880, toneSeconds: Double = 0.3,
    pauseSeconds: Double = 0.2, tones: Int = 3
  ) -> AVAudioPCMBuffer? {
    guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
      return nil
    }
    let toneFrames = Int(sampleRate * toneSeconds)
    let pauseFrames = Int(sampleRate * pauseSeconds)
    let total = tones * toneFrames + (tones - 1) * pauseFrames
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)),
      let samples = buffer.floatChannelData?[0]
    else { return nil }
    buffer.frameLength = AVAudioFrameCount(total)
    let fade = Int(sampleRate * 0.01)
    for index in 0..<total { samples[index] = 0 }
    for tone in 0..<tones {
      let start = tone * (toneFrames + pauseFrames)
      for frame in 0..<toneFrames {
        let envelope = min(1, Float(frame) / Float(fade), Float(toneFrames - frame) / Float(fade))
        let value = sin(2 * Double.pi * frequency * Double(frame) / sampleRate)
        samples[start + frame] = Float(value) * 0.5 * envelope
      }
    }
    return buffer
  }
}
