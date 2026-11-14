import CoreImage
import CoreImage.CIFilterBuiltins
import FrontstageCore
import SwiftUI

/// QR-Bild aus Text: `CIFilter.qrCodeGenerator()`, Korrekturstufe "M", ganzzahlig skaliert, ohne Glättung.
enum QRCodeRenderer {
  /// Swift-Hinweis: `CIImage` ist nur eine Rechenvorschrift; erst `CIContext.createCGImage` erzeugt Pixel.
  /// `samplingNearest()` verhindert, dass beim Vergrößern Zwischenwerte entstehen (scharfe Module).
  static func image(for text: String, scale: CGFloat) -> CGImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(text.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage, scale >= 1 else { return nil }
    let scaled = output.samplingNearest().transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    return CIContext().createCGImage(scaled, from: scaled.extent)
  }
}

/// Zeigt den eigenen Code dieses Geräts.
struct PairingCodeView: View {
  let payload: PairingPayload

  var body: some View {
    VStack(spacing: 12) {
      if let image = QRCodeRenderer.image(for: payload.text, scale: 8) {
        Image(decorative: image, scale: 1)
          .interpolation(.none)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: 280, maxHeight: 280)
          .padding(12)
          // Weißer Grund bleibt auch im dunklen Modus, sonst lesen Kameras den Code schlecht.
          .background(Color.white, in: .rect(cornerRadius: 12))
          .accessibilityLabel(Text("pairing.title"))
      }
      Text("pairing.showCode.message")
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }
}
