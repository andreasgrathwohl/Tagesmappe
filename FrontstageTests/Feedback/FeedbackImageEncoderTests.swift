import CoreGraphics
import Foundation
import FrontstageCore
import PencilKit
import Testing

@testable import Frontstage

@MainActor @Suite struct FeedbackImageEncoderTests {
  private func white(_ width: Int, _ height: Int) -> CGImage {
    TestImages.solid(gray: 1, width: width, height: height)
  }

  private func decoded(_ data: Data?) throws -> CGImage {
    let data = try #require(data)
    return try #require(TestImages.decode(data))
  }

  @Test("Längste Kante 2048")
  func downscalesTo2048() throws {
    let image = try decoded(FeedbackImageEncoder.preparedJPEG(from: white(2732, 2048)))
    #expect(image.width == 2048)
    #expect(image.height == 1535)
  }

  @Test("Review 2: Schwärzung deckt vollständig")
  func redactionCoversAreaCompletely() throws {
    let source = try #require(FeedbackImageEncoder.preparedJPEG(from: white(200, 200)))
    let rect = NormalizedRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
    let image = try decoded(FeedbackImageEncoder.flattened(imageData: source, markup: nil, redactions: [rect]))
    #expect(TestImages.gray(image, atX: 0.5, y: 0.5) <= 8)
    #expect(TestImages.gray(image, atX: 0.1, y: 0.1) >= 247)
  }

  @Test("Review 2: Schwärzung liegt über der Zeichnung")
  func redactionDrawnAboveMarkup() throws {
    let source = try #require(FeedbackImageEncoder.preparedJPEG(from: white(200, 200)))
    let points = [CGPoint(x: 0, y: 100), CGPoint(x: 200, y: 100)].enumerated().map { index, location in
      PKStrokePoint(
        location: location, timeOffset: Double(index), size: CGSize(width: 12, height: 12), opacity: 1, force: 1,
        azimuth: 0, altitude: .pi / 2)
    }
    let path = PKStrokePath(controlPoints: points, creationDate: Date())
    let drawing = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .red), path: path)])
    let rect = NormalizedRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)

    let withoutRedaction = try decoded(FeedbackImageEncoder.flattened(imageData: source, markup: drawing, redactions: []))
    #expect(TestImages.gray(withoutRedaction, atX: 0.5, y: 0.5) < 200)  // der Strich ist sichtbar

    let image = try decoded(FeedbackImageEncoder.flattened(imageData: source, markup: drawing, redactions: [rect]))
    #expect(TestImages.gray(image, atX: 0.5, y: 0.5) <= 8)
  }

  @Test("Review 2: Lage stimmt nach Verkleinern")
  func downscaleKeepsRedactionPosition() throws {
    // Eine 4096 × 2048 große Quelle wird auf 2048 × 1024 verkleinert; die Schwärzung liegt in Bildanteilen.
    let source = try #require(FeedbackImageEncoder.preparedJPEG(from: white(4096, 2048)))
    let rect = NormalizedRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
    let image = try decoded(FeedbackImageEncoder.flattened(imageData: source, markup: nil, redactions: [rect]))
    #expect(image.width == 2048)
    #expect(image.height == 1024)
    #expect(TestImages.gray(image, atX: 0.5, y: 0.5) <= 8)
    #expect(TestImages.gray(image, atX: 0.02, y: 0.02) >= 247)
  }

  @Test("Unlesbare Daten → nil")
  func invalidDataIsNil() {
    #expect(FeedbackImageEncoder.preparedJPEG(fromImageData: Data("kein Bild".utf8)) == nil)
    #expect(FeedbackImageEncoder.flattened(imageData: Data([0, 1, 2]), markup: nil, redactions: []) == nil)
  }
}
