import FrontstageCore
import PencilKit
import SwiftUI

/// Hinweis nach einer Aktion der Tafel.
private enum BoardNotice: Identifiable {
  case saveFailed, noPrevious, deleteFailed

  var id: Self { self }

  var messageKey: LocalizedStringKey {
    switch self {
    case .saveFailed, .deleteFailed: "board.save.failed"
    case .noPrevious: "board.previous.none"
    }
  }
}

/// Die Tafel am Tablet und am Mac (FR-12, FR-12.1–FR-12.3): Seitenleiste mit Blättern, Seiten hinzufügen, Hintergrund,
/// „Letztes Tafelbild“ und Löschen; auf der Fläche zeichnet die Lehrkraft (iPad, `PKToolPicker` mit Stift, Radierer
/// und Farben). Am Mac gibt es keine Zeichenfläche: dort nur Blättern, Löschen und das frühere Tafelbild.
///
/// Die Sitzung (`BoardSession`) kommt aus der Umgebung (`classroomEnvironment()`); diese Ansicht öffnet sie beim Erscheinen
/// und schließt sie beim Verlassen. Ohne Kauf blendet der Aufrufer das Kaufangebot davor (`PaidGate(.board)`).
struct BoardScreen: View {
  let lessonKey: LessonKey

  @Environment(BoardSession.self) private var session: BoardSession?
  @Environment(\.dismiss) private var dismiss
  // Swift-Hinweis: `scenePhase` liefert den Lebenszyklus der Szene (aktiv, inaktiv, Hintergrund).
  @Environment(\.scenePhase) private var scenePhase

  @State private var notice: BoardNotice?
  @State private var confirmDelete = false
  @State private var didClose = false
  @State private var isPickingTemplate = false

  var body: some View {
    NavigationStack {
      Group {
        if let session {
          content(session)
        } else {
          ContentUnavailableView("board.unavailable", systemImage: "pencil.slash")
        }
      }
      .navigationTitle(Text("board.title"))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("board.done") { finish() }
        }
      }
    }
    .task { open() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background { try? session?.flush() }
    }
    // Schließen ohne den „Fertig“-Knopf (z. B. Esc am Mac): trotzdem speichern.
    .onDisappear {
      if !didClose {
        didClose = true
        try? session?.close()
      }
    }
    // Vorlage aus Material oder Ablage (FR-12.6): legt eine neue Seite mit dem gerenderten Bild als Hintergrund an.
    .sheet(isPresented: $isPickingTemplate) {
      if let session { TemplatePicker(lessonKey: lessonKey, session: session) }
    }
    .alert(
      Text(notice?.messageKey ?? ""), isPresented: isPresent($notice), presenting: notice
    ) { _ in
      Button("dayView.ok", role: .cancel) {}
    }
    .confirmationDialog(
      Text("board.delete.confirm"), isPresented: $confirmDelete, titleVisibility: .visible
    ) {
      Button("board.delete", role: .destructive) { deleteBoard() }
      Button("board.cancel", role: .cancel) {}
    }
  }

  // MARK: Inhalt

  private func content(_ session: BoardSession) -> some View {
    HStack(spacing: 0) {
      sidebar(session)
        .frame(width: 220)
      Divider()
      VStack(spacing: 0) {
        if case .previous = session.mode { previousBanner(session) }
        stage(session)
      }
    }
  }

  @ViewBuilder private func stage(_ session: BoardSession) -> some View {
    if let page = session.currentPage {
      BoardPageSurface(
        page: page,
        drawing: Binding(get: { session.liveDrawing }, set: { session.drawingChanged($0) }),
        isEditable: canDraw(in: session), cover: session.cover, audience: .tablet
      )
      #if os(iOS)
        // Ziehgriff der Abdeckung, nur am Tablet und nur auf der eigenen Tafel.
        .overlay {
          if canDraw(in: session) {
            BoardCoverHandle(cover: Bindable(session).cover)
          }
        }
      #endif
      .overlay(Rectangle().strokeBorder(.separator))
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  /// Gezeichnet wird nur am iPad und nur auf der eigenen Tafel (ein früheres Tafelbild ist nur zum Ansehen).
  private func canDraw(in session: BoardSession) -> Bool {
    #if os(iOS)
      if case .own = session.mode { return true }
    #endif
    return false
  }

  private func previousBanner(_ session: BoardSession) -> some View {
    HStack(spacing: 12) {
      Label("board.previous", systemImage: "clock.arrow.circlepath")
        .font(.headline)
      Spacer(minLength: 0)
      Button("board.backToOwn") {
        do { try session.returnToOwnBoard() } catch { notice = .saveFailed }
      }
      .frame(minHeight: 44)
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .background(.bar)
  }

  // MARK: Seitenleiste

  private func sidebar(_ session: BoardSession) -> some View {
    let count = session.pages.count
    return ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("board.page \(session.pageIndex + 1) \(count)")
          .font(.headline)

        HStack(spacing: 8) {
          Button("board.previousPage", systemImage: "chevron.left") {
            session.goToPage(session.pageIndex - 1)
          }
          .disabled(session.pageIndex <= 0)
          Button("board.nextPage", systemImage: "chevron.right") {
            session.goToPage(session.pageIndex + 1)
          }
          .disabled(session.pageIndex >= count - 1)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.large)

        pageList(session)

        Divider()

        #if os(iOS)
          if case .own = session.mode {
            addPageMenu(session)
            backgroundMenu(session)
            Button("board.template", systemImage: "doc.on.doc") { isPickingTemplate = true }
              .frame(minHeight: 44)
          }
        #endif
        // Teilen-Dialog: liest die Seiten und erzeugt das PDF erst, wenn ein Ziel gewählt wird (FR-12.4).
        ShareLink(
          item: BoardDrawingPDF(pages: { [session] in session.exportPages }, fileName: pdfFileName(for: session)),
          preview: SharePreview(Text("board.sharePDF"))
        ) {
          Label("board.sharePDF", systemImage: "square.and.arrow.up")
            .frame(minHeight: 44)
        }
        // Abdecken: setzt eine ganz deckende Abdeckung, erneutes Tippen hebt sie auf (FR-12.7).
        Button(
          session.cover == nil ? LocalizedStringKey("board.cover") : LocalizedStringKey("board.uncover"),
          systemImage: session.cover == nil ? "rectangle.fill.on.rectangle.fill" : "rectangle.dashed"
        ) {
          session.cover = session.cover == nil ? BoardCover() : nil
        }
        .frame(minHeight: 44)
        if case .own = session.mode {
          Button("board.previous", systemImage: "clock.arrow.circlepath") { showPrevious(session) }
            .frame(minHeight: 44)
          Button("board.delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
            .frame(minHeight: 44)
        }

        if session.saveFailed {
          Label("board.save.failed", systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        }
      }
      .padding()
    }
  }

  /// Eine Taste je Seite; die gezeigte ist hervorgehoben.
  private func pageList(_ session: BoardSession) -> some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
      ForEach(session.pages.indices, id: \.self) { index in
        let isCurrent = index == session.pageIndex
        Button {
          session.goToPage(index)
        } label: {
          Text(verbatim: "\(index + 1)")
            .frame(minWidth: 36, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .tint(isCurrent ? Color.accentColor : Color.secondary)
        .accessibilityLabel(Text("board.page \(index + 1) \(session.pages.count)"))
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
      }
    }
  }

  #if os(iOS)
    private func addPageMenu(_ session: BoardSession) -> some View {
      Menu {
        ForEach(Self.choosableBackgrounds, id: \.self) { background in
          Button(Self.title(of: background)) { addPage(background, session) }
        }
      } label: {
        Label("board.addPage", systemImage: "plus.rectangle.on.rectangle")
          .frame(minHeight: 44)
      }
    }

    private func backgroundMenu(_ session: BoardSession) -> some View {
      Menu {
        ForEach(Self.choosableBackgrounds, id: \.self) { background in
          Button {
            do { try session.setBackground(background) } catch { notice = .saveFailed }
          } label: {
            if session.currentPage?.background == background {
              Label(Self.title(of: background), systemImage: "checkmark")
            } else {
              Text(Self.title(of: background))
            }
          }
        }
      } label: {
        Label("board.background", systemImage: "square.grid.3x3")
          .frame(minHeight: 44)
      }
    }
  #endif

  /// Wählbar sind Leer, Liniert, Kariert; ein Bild kommt aus der Kamera (Aufgabe 13).
  private static let choosableBackgrounds: [BoardBackground] = [.blank, .lined, .grid]

  private static func title(of background: BoardBackground) -> LocalizedStringKey {
    switch background {
    case .blank, .image: "board.background.blank"
    case .lined: "board.background.lined"
    case .grid: "board.background.grid"
    }
  }

  // MARK: Aktionen

  private func open() {
    guard let session else { return }
    do { try session.open(lessonKey) } catch { notice = .saveFailed }
  }

  /// „Tafelbild 8b Englisch 2026-11-17.pdf“ – für die gezeigte Stunde (bei „Letztes Tafelbild“ die frühere).
  private func pdfFileName(for session: BoardSession) -> String {
    let key: LessonKey
    switch session.mode {
    case .own(let own): key = own
    case .previous(_, let shown): key = shown
    case .closed: key = lessonKey
    }
    let name = String(
      localized: "board.pdf.fileName \(key.schoolClass.normalized) \(key.subject.display) \(key.date.storageText)")
    return name + ".pdf"
  }

  private func addPage(_ background: BoardBackground, _ session: BoardSession) {
    do { try session.addPage(background: background) } catch { notice = .saveFailed }
  }

  private func showPrevious(_ session: BoardSession) {
    do {
      try session.showPreviousBoardDrawing()
    } catch BoardSessionError.noPreviousBoardDrawing {
      notice = .noPrevious
    } catch {
      notice = .saveFailed
    }
  }

  private func deleteBoard() {
    do { try session?.deleteBoardDrawing() } catch { notice = .deleteFailed }
  }

  /// Speichert und schließt. Scheitert das Speichern, bleibt die Tafel offen, damit nichts verloren geht.
  private func finish() {
    guard let session else {
      dismiss()
      return
    }
    do {
      try session.close()
      didClose = true
      dismiss()
    } catch {
      notice = .saveFailed
    }
  }

  /// `Bool`-Bindung für Dialoge, die an einem Optional hängen.
  private func isPresent<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
    Binding(
      get: { value.wrappedValue != nil },
      set: { if !$0 { value.wrappedValue = nil } })
  }
}
