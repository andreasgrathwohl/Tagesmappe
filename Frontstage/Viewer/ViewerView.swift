import FrontstageCore
import OSLog
import PDFKit
import PencilKit
import SwiftUI

#if os(iOS)
  import UIKit
#endif

/// Anzeige eines Materials (PDF oder Bild) mit Stiftnotizen neben dem Dokument (FR-6, ADR-0011).
///
/// iPad: `PDFCanvasView` mit Zeichenfläche. Mac: `PDFDisplayView` ohne Zeichenfläche, nur Ansehen und Blättern.
/// `DataStore`, `StorageService` und `AppEnvironment` kommen aus der Umgebung (`DataScopedRoot`); die Anzeige legt
/// keine eigenen Dienste an. Geschrieben wird nur über `PenNoteStore`/`PenNoteFileService`, nie am Original.
struct ViewerView: View {
  let linkID: UUID

  @Environment(DataStore.self) private var dataStore
  @Environment(StorageService.self) private var storage
  @Environment(AppEnvironment.self) private var environment
  @Environment(\.dismiss) private var dismiss
  // Swift-Hinweis: `scenePhase` liefert den Lebenszyklus der Szene (aktiv, inaktiv, Hintergrund).
  @Environment(\.scenePhase) private var scenePhase

  @State private var model: ViewerModel?
  @State private var title = ""
  @State private var linkMissing = false
  @State private var isClosing = false
  @State private var didClose = false
  @State private var hideOutdatedNotice = false
  @State private var showMissingNotes = false

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "ViewerView")

  var body: some View {
    NavigationStack {
      content
        .navigationTitle(title)
        #if os(iOS)
          .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbar }
    }
    .task { await start() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background { flushInBackground() }
    }
    // Schließen ohne den „Fertig“-Knopf (z. B. Esc am Mac): trotzdem speichern und freigeben.
    .onDisappear {
      if let model, !didClose {
        didClose = true
        Task { await model.close() }
      }
    }
    .sheet(isPresented: $showMissingNotes) {
      if let model { MissingNotesSheet(model: model) }
    }
  }

  // MARK: Inhalt

  @ViewBuilder private var content: some View {
    if linkMissing {
      unavailable
    } else if let model {
      switch model.phase {
      case .loading:
        ProgressView()
      case .unavailable:
        unavailable
      case .ready:
        ready(model)
      }
    } else {
      ProgressView()
    }
  }

  private var unavailable: some View {
    ContentUnavailableView("viewer.unavailable", systemImage: "doc.questionmark")
  }

  private func ready(_ model: ViewerModel) -> some View {
    VStack(spacing: 0) {
      banners(for: model)
      document(model)
      #if os(iOS)
        SmartboardBar()
      #endif
    }
  }

  @ViewBuilder private func document(_ model: ViewerModel) -> some View {
    #if os(iOS)
      PDFCanvasView(model: model)
    #else
      if let data = model.documentData {
        PDFDisplayView(
          documentData: data, pageIndex: model.pageIndex, drawing: model.drawing(forPage: model.pageIndex),
          visibleRect: nil)
      }
    #endif
  }

  // MARK: Hinweise

  @ViewBuilder private func banners(for model: ViewerModel) -> some View {
    let outdated = model.outdatedPages
    let missing = model.missingPages
    VStack(spacing: 8) {
      if !outdated.isEmpty, !hideOutdatedNotice {
        Banner {
          VStack(alignment: .leading, spacing: 4) {
            Text("viewer.outdatedNotes.title").font(.headline)
            Text("viewer.outdatedNotes.body")
            Text("viewer.pages \(Self.pageList(outdated))").foregroundStyle(.secondary)
          }
          Button("viewer.outdatedNotes.hide") { hideOutdatedNotice = true }
        }
      }
      if !missing.isEmpty {
        Banner {
          VStack(alignment: .leading, spacing: 4) {
            Text("viewer.missingPages")
            Text("viewer.pages \(Self.pageList(missing))").foregroundStyle(.secondary)
          }
          Button("viewer.missingPages.show") { showMissingNotes = true }
        }
      }
      if let key = locationNoticeKey(for: model.notesLocation) {
        Banner { Text(key) }
      }
    }
    .padding(.horizontal)
    .padding(.top, 8)
  }

  /// Hinweis zum Ort der Notizen (ADR-0011); `nil`, wenn alles neben dem Dokument liegt.
  private func locationNoticeKey(for location: PenNoteLocation) -> LocalizedStringKey? {
    switch location {
    case .besideDocument: nil
    case .appDataFallback: "viewer.notesInAppData"
    case .blocked(.notDownloaded): "viewer.notesNotDownloaded"
    case .blocked(.unreadable): "viewer.notesUnreadable"
    case .blocked(.newerFormat): "viewer.notesNewerFormat"
    }
  }

  /// Seitenzahlen für Menschen (ab 1), z. B. „2, 5“.
  private static func pageList(_ indices: [Int]) -> String {
    indices.map { String($0 + 1) }.joined(separator: ", ")
  }

  // MARK: Leiste

  @ToolbarContentBuilder private var toolbar: some ToolbarContent {
    ToolbarItem(placement: .confirmationAction) {
      Button("viewer.done") { closeAndDismiss() }
        .disabled(isClosing)
    }
    if let model, model.phase == .ready, let count = model.document?.pageCount {
      ToolbarItemGroup(placement: .primaryAction) {
        Button("viewer.previousPage", systemImage: "chevron.left") { go(to: model.pageIndex - 1, model) }
          .disabled(model.pageIndex <= 0)
        Text("viewer.pageOfPages \(model.pageIndex + 1) \(count)")
          .monospacedDigit()
        Button("viewer.nextPage", systemImage: "chevron.right") { go(to: model.pageIndex + 1, model) }
          .disabled(model.pageIndex >= count - 1)
      }
    }
    ToolbarItem(placement: .primaryAction) { HelpButton(topic: .penNotes) }
  }

  private func go(to index: Int, _ model: ViewerModel) {
    guard let count = model.document?.pageCount, index >= 0, index < count else { return }
    Task { await model.pageChanged(to: index, visibleRect: nil) }
  }

  // MARK: Ablauf

  /// Holt die Zuordnung und baut das Modell; läuft einmal je Anzeige.
  private func start() async {
    guard model == nil, !linkMissing else { return }
    guard let link = try? dataStore.link(id: linkID) else {
      linkMissing = true
      return
    }
    title = link.displayName
    let files = StoragePenNoteFiles(storage: storage)
    let notes = PenNoteStore(link: link, files: files, fallback: dataStore)
    let environment = environment
    let created = ViewerModel(
      link: link, notes: notes, fileReader: ScopedFileReader(storage: storage), files: files,
      secondScreen: .shared, beforeLoad: { await environment.penNotes.retryPending() })
    model = created
    await created.load()
  }

  private func closeAndDismiss() {
    guard let model else {
      dismiss()
      return
    }
    guard !isClosing else { return }
    isClosing = true
    didClose = true
    Task {
      await model.close()
      dismiss()
    }
  }

  /// Beim Wechsel in den Hintergrund ausstehende Notizen sofort schreiben; unter iOS gibt `beginBackgroundTask`
  /// dem Schreiben in die Ablage Zeit, bevor die App angehalten wird.
  private func flushInBackground() {
    guard let model else { return }
    #if os(iOS)
      let token = BackgroundTaskToken()
      token.id = UIApplication.shared.beginBackgroundTask(withName: "flush-pen-notes") {
        MainActor.assumeIsolated { UIApplication.shared.endBackgroundTask(token.id) }
      }
      Task {
        await model.flushNow()
        UIApplication.shared.endBackgroundTask(token.id)
      }
    #else
      Task { await model.flushNow() }
    #endif
  }
}

#if os(iOS)
  /// Hält die Kennung der Hintergrundaufgabe, damit die Ablauf-Closure und der Task dieselbe sehen.
  @MainActor private final class BackgroundTaskToken {
    var id: UIBackgroundTaskIdentifier = .invalid
  }
#endif

/// Hinweiszeile über der Anzeige: Text links, Knopf rechts; Systemmaterial, keine eigene Farbe.
private struct Banner<Content: View>: View {
  @ViewBuilder let content: () -> Content

  init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      content()
      Spacer(minLength: 0)
    }
    .padding(12)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }
}

/// Zeigt die Notizen zu Seiten, die es im Dokument nicht mehr gibt, als Bild (nur ansehen).
private struct MissingNotesSheet: View {
  let model: ViewerModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          ForEach(model.missingPages, id: \.self) { index in
            if let drawing = model.drawing(forPage: index), !drawing.strokes.isEmpty {
              VStack(alignment: .leading, spacing: 4) {
                Text("viewer.missingPages.page \(index + 1)").font(.headline)
                noteImage(drawing)
                  .resizable()
                  .scaledToFit()
                  .background(.white)
              }
            }
          }
        }
        .padding()
      }
      .navigationTitle(Text("viewer.missingPages"))
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("viewer.done") { dismiss() }
        }
      }
    }
  }

  private func noteImage(_ drawing: PKDrawing) -> Image {
    #if os(iOS)
      Image(uiImage: drawing.image(from: drawing.bounds, scale: 2))
    #else
      Image(nsImage: drawing.image(from: drawing.bounds, scale: 2))
    #endif
  }
}
