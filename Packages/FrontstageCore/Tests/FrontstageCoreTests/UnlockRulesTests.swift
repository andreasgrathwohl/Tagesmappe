import Foundation
import Testing

@testable import FrontstageCore

@Suite struct UnlockRulesTests {
  @Test("Nur verifizierte, nicht widerrufene Transaktion des Produkts schaltet frei (AK-40)")
  func unverifiedOrRevokedNeverUnlocks() {
    let id = "frontstage.classroom"
    #expect(UnlockRules.grantsUnlock(productID: id, isVerified: true, revocationDate: nil, unlockProductID: id))
    #expect(!UnlockRules.grantsUnlock(productID: id, isVerified: false, revocationDate: nil, unlockProductID: id))
    #expect(!UnlockRules.grantsUnlock(productID: id, isVerified: true, revocationDate: Date(), unlockProductID: id))
    #expect(
      !UnlockRules.grantsUnlock(productID: "other", isVerified: true, revocationDate: nil, unlockProductID: id))
  }
}
