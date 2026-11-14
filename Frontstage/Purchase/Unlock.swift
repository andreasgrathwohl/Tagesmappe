import FrontstageCore
import Observation
import StoreKit

/// Freischaltung des Klassenbildschirms und der Tafel (FR-13): ein Einmalkauf, kein Abo.
///
/// Der Kaufstand kommt **nur** aus StoreKit (`Transaction.currentEntitlements`, `Transaction.updates`) und
/// wird nirgends gespeichert oder gespiegelt (NFR-2). Swift-Hinweis: `Transaction` ist hier StoreKits
/// Kauf-Beleg, nicht die Datenbank-Transaktion; `AsyncSequence`-Schleifen (`for await`) warten, bis der
/// nächste Beleg eintrifft.
@MainActor @Observable final class Unlock {
  /// Platzhalter-Produktkennung; die echte legt der App-Store-Eintrag fest.
  static let productID = "frontstage.classroom"

  /// Ist die Freischaltung gerade gültig? Vor dem ersten `refresh()` `false`.
  private(set) var isUnlocked = false

  /// `@ObservationIgnored`: reiner Halter, soll keine Ansicht neu zeichnen.
  @ObservationIgnored private var updatesTask: Task<Void, Never>?
  /// Zählt die gestarteten `refresh()`-Läufe; nur der zuletzt gestartete darf `isUnlocked` setzen.
  @ObservationIgnored private var refreshGeneration = 0

  /// `listenForUpdates`: auf `Transaction.updates` hören (Erstattung, Kauf auf anderem Gerät, ausstehende
  /// Käufe). Tests schalten es aus, damit sie nur ihre eigene Sitzung sehen.
  init(listenForUpdates: Bool) {
    guard listenForUpdates else { return }
    updatesTask = Task { [weak self] in
      for await result in Transaction.updates {
        guard let self else { return }
        await self.handle(result)
      }
    }
    Task { [weak self] in await self?.refresh() }
  }

  /// Liest die aktuellen Berechtigungen neu: frei, sobald irgendeine Transaktion die Regeln erfüllt.
  ///
  /// Laufen zwei Abfragen überlappend (die erste aus `init`, eine zweite nach einem Kauf), gewinnt die zuletzt
  /// gestartete; eine ältere, langsamere überschreibt ein frisches `true` sonst mit einem veralteten `false`.
  func refresh() async {
    refreshGeneration += 1
    let generation = refreshGeneration
    var granted = false
    for await result in Transaction.currentEntitlements {
      switch result {
      case .verified(let transaction):
        if Self.grants(transaction, isVerified: true) { granted = true }
      case .unverified(let transaction, _):
        if Self.grants(transaction, isVerified: false) { granted = true }
      }
    }
    guard generation == refreshGeneration else { return }
    isUnlocked = granted
  }

  /// Verarbeitet einen Beleg aus `Transaction.updates` oder aus dem Kaufdialog: verifizierte abschließen,
  /// danach neu lesen (ein Widerruf kommt so ebenfalls an).
  func handle(_ result: VerificationResult<Transaction>) async {
    if case .verified(let transaction) = result {
      await transaction.finish()
    }
    await refresh()
  }

  /// „Käufe wiederherstellen“: gleicht mit dem App Store ab und liest neu.
  func restore() async throws {
    try await AppStore.sync()
    await refresh()
  }

  private static func grants(_ transaction: Transaction, isVerified: Bool) -> Bool {
    UnlockRules.grantsUnlock(
      productID: transaction.productID, isVerified: isVerified,
      revocationDate: transaction.revocationDate, unlockProductID: productID)
  }
}
