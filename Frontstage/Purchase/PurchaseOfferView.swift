import StoreKit
import SwiftUI

/// Kaufangebot (FR-13). Systemdarstellung von StoreKit, kein eigenes Design; Wortlaut ist ein Platzhalter
/// (Gestaltungskategorie „Wortlaut“ offen).
struct PurchaseOfferView: View {
  @Environment(Unlock.self) private var unlock
  @State private var restoreFailed = false

  var body: some View {
    VStack(spacing: 16) {
      Text("purchase.offer.title")
        .font(.title2)
      Text("purchase.offer.note")
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      // Swift-Hinweis: `ProductView` holt Preis und Text vom App Store (in Tests aus der .storekit-Datei).
      // Der Closure-Parameter ist das Produkt, das Ergebnis trägt den Beleg; `async`, daher `await`.
      ProductView(id: Unlock.productID)
        .productViewStyle(.compact)
        .onInAppPurchaseCompletion { _, result in
          if case .success(.success(let verification)) = result {
            await unlock.handle(verification)
          }
        }
      Button("purchase.restore") {
        Task {
          do {
            try await unlock.restore()
            restoreFailed = false
          } catch {
            restoreFailed = true
          }
        }
      }
      if restoreFailed {
        Text("purchase.restore.failed")
          .foregroundStyle(.red)
      }
    }
    .padding()
  }
}
