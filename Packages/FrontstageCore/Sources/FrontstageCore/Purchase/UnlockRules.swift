import Foundation

/// Regeln der Freischaltung (FR-13). Reine Logik ohne StoreKit, damit sie ohne Mac testbar bleibt.
public enum UnlockRules {
  /// Schaltet diese Transaktion frei? Nur eine **verifizierte**, **nicht widerrufene** Transaktion
  /// des einen Freischalt-Produkts zählt; alles andere (unverifiziert, erstattet, fremdes Produkt) nie.
  public static func grantsUnlock(
    productID: String, isVerified: Bool, revocationDate: Date?, unlockProductID: String
  ) -> Bool {
    isVerified && revocationDate == nil && productID == unlockProductID
  }
}
