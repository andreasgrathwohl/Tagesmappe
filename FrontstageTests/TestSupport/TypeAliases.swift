import SwiftData

@testable import Frontstage

// Seit iOS 18 bringt SwiftData ein eigenes Protokoll `DataStore` mit. Importiert eine Testdatei
// sowohl `SwiftData` als auch das App-Modul `Frontstage` (unsere Klasse `DataStore`), ist der
// Name mehrdeutig: „'DataStore' is ambiguous for type lookup“. Ein Typalias auf Modulebene im
// Testmodul hat Vorrang vor beiden Importen und löst die Mehrdeutigkeit für alle Testdateien.
typealias DataStore = Frontstage.DataStore
