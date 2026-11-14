import StoreKitTest
import Testing

@testable import Frontstage

/// `SKTestSession` teilt eine Umgebung, daher laufen die Tests seriell.
@Suite(.serialized) @MainActor struct UnlockTests {
  let session: SKTestSession

  init() throws {
    session = try SKTestSession(configurationFileNamed: "Frontstage")
    session.disableDialogs = true
    session.clearTransactions()
  }

  @Test("AK-40: ohne Kauf gesperrt")
  func lockedWithoutPurchase() async {
    let unlock = Unlock(listenForUpdates: false)
    await unlock.refresh()
    #expect(unlock.isUnlocked == false)
  }

  @Test("AK-40: nach dem Kauf frei, ohne Ablaufdatum")
  func unlockedAfterPurchase() async throws {
    let transaction = try await session.buyProduct(identifier: Unlock.productID, options: [])
    #expect(transaction.expirationDate == nil)
    let unlock = Unlock(listenForUpdates: false)
    await unlock.refresh()
    #expect(unlock.isUnlocked)
  }

  @Test("Review Focus 4: Erstattung sperrt wieder")
  func refundRelocks() async throws {
    let transaction = try await session.buyProduct(identifier: Unlock.productID, options: [])
    try session.refundTransaction(identifier: UInt(transaction.id))
    let unlock = Unlock(listenForUpdates: false)
    await unlock.refresh()
    #expect(unlock.isUnlocked == false)
  }
}
