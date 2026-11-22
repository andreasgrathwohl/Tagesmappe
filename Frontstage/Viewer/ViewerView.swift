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
  /// Lösung neben dem Blatt (FR-6.3, UI-17); `nil` = keine Lösung an der Zuordnung.
  @State private var solution: SolutionPaneModel?
  /// Verweis des Blatts (für „Lösung hinzufügen“).
  @State private var sheetReference: MaterialReference?
  @State private var solutionTarget: SolutionTarget?
  /// Das System nimmt das Tablet-Bild auf bzw. spiegelt es; `nil` = noch unbekannt. Auf dem Mac gibt es keine
  /// Erkennung, dort gilt „nicht gespiegelt“.
  #if os(iOS)
    @State private var isCaptured: Bool?
  #else
    @State private var isCaptured: Bool? = false
  #endif
  private var visibility: SolutionVisibility { .shared }
  private var secondScreen: SecondScreenState { .shared }

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
    .environment(visibility)
    // Gekoppeltes Blättern: Seitenwechsel im Blatt (Pfeile oder Wischen) zieht die Lösung nach.
    .onChange(of: model?.pageIndex) { _, page in
      if let page { solution?.sheetPageChanged(to: page) }
    }
    .onDisappear { visibility.viewerClosed() }
    .solutionPicking(target: $solutionTarget) { reloadSolution() }
    #if os(iOS)
      .background { ScreenCaptureReader(isCaptured: $isCaptured) }
    #endif
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
      sheetAndSolution(model)
      #if os(iOS)
        SmartboardBar()
      #endif
    }
  }

  /// Gespiegelt heißt: das System nimmt das Tablet-Bild auf, ohne dass eine eigene Szene am Bildschirm hängt.
  private var isMirrored: Bool? { isCaptured.map { $0 && !secondScreen.isConnected } }

  /// Blatt allein oder Blatt und Lösung (UI-17): breit nebeneinander je halbe Breite, schmal übereinander.
  ///
  /// Immer dieselbe Struktur (GeometryReader → Layout → Blatt): Nur die Spalte kommt und geht. So behält die
  /// Zeichenfläche des Blatts beim Ein- und Ausblenden ihre Identität, samt Zoom – auch am Zweitbildschirm.
  private func sheetAndSolution(_ model: ViewerModel) -> some View {
    GeometryReader { proxy in
      let sideBySide = proxy.size.width >= Self.sideBySideMinWidth
      let layout = sideBySide ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
      layout {
        document(model)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        if let solution, visibility.isShownByUser {
          Divider()
          SolutionPane(
            model: solution, sheetPage: model.pageIndex, isMirrored: isMirrored,
            pickOther: { beginSolutionPick() }
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
  }

  /// Ab dieser Breite stehen Blatt und Lösung nebeneinander (iPad quer); darunter übereinander.
  private static let sideBySideMinWidth: CGFloat = 700

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
    if let model, model.phase == .ready {
      ToolbarItem(placement: .primaryAction) { solutionButton }
    }
    ToolbarItem(placement: .primaryAction) { HelpButton(topic: .penNotes) }
  }

  /// „Lösung“ blendet die Spalte ein und aus; ohne Lösung „Lösung hinzufügen“ (nur PDF und Bild).
  @ViewBuilder private var solutionButton: some View {
    if solution != nil {
      Toggle(isOn: Binding(get: { visibility.isShownByUser }, set: { visibility.isShownByUser = $0 })) {
        Label("viewer.solution", systemImage: "sidebar.right")
      }
      .toggleStyle(.button)
    } else if let sheetReference, sheetReference.fileKind.opensInViewer {
      Button("viewer.addSolution", systemImage: "doc.badge.plus") { beginSolutionPick() }
    }
  }

  private func beginSolutionPick() {
    guard let sheetReference else { return }
    solutionTarget = SolutionTarget(linkID: linkID, sheet: sheetReference)
  }

  /// Nach „Lösung hinzufügen“: Lösung neu lesen und die Spalte zeigen.
  private func reloadSolution() {
    guard let link = try? dataStore.link(id: linkID) else { return }
    loadSolution(link.solution)
    visibility.isShownByUser = true
  }

  private func loadSolution(_ reference: MaterialReference?) {
    guard let reference else {
      solution = nil
      return
    }
    let pane = SolutionPaneModel(reference: reference, fileReader: ScopedFileReader(storage: storage))
    solution = pane
    pane.sheetPageChanged(to: model?.pageIndex ?? 0)
    // Seitenwechsel während des Ladens merkt sich das Modell selbst (`lastSheetPage`).
    Task { await pane.load() }
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
    sheetReference = link.reference
    loadSolution(link.solution)
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
