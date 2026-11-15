import FrontstageCore
import SwiftUI
import UniformTypeIdentifiers

extension EnvironmentValues {
  /// Wechselt in den Bereich „Einrichten“ (z. B. um einen Ordner freizugeben). Setzt `RootView`.
  ///
  /// Swift-Hinweis: `@Entry` legt Schlüssel und Vorgabewert der Umgebung in einer Zeile an.
  @Entry var showSetup: @MainActor () -> Void = {}
}

/// Hinweis nach einer Aktion; ein Alert mit einer Taste (bei „außerhalb“ zusätzlich „Ordner freigeben“).
private enum DayNotice: Equatable {
  case openFailed
  case relinkSaveFailed
  case outsideGrantedFolders
  case noNextLesson
  case carryNotesFailed
  /// Der Ordner der Datei ist auf diesem Gerät nicht freigegeben – „Ordner freigeben“ statt „Neu verknüpfen“.
  case grantMissing
  /// Die Datei liegt nicht auf dem Gerät und es gibt kein Netz – Neu verknüpfen hilft hier nicht.
  case notDownloadedOffline

  var messageKey: LocalizedStringKey {
    switch self {
    case .openFailed: "dayView.openFailed"
    case .relinkSaveFailed: "dayView.relinkSaveFailed"
    case .outsideGrantedFolders: "dayView.outsideGrants"
    case .noNextLesson: "dayView.noNextLesson"
    case .carryNotesFailed: "lesson.relink.carryNotesFailed"
    case .grantMissing: "dayView.grantMissing"
    case .notDownloadedOffline: "dayView.notDownloadedOffline"
    }
  }
}

/// Ziel für `.fullScreenCover(item:)`: `UUID` selbst ist nicht `Identifiable`.
private struct ViewerTarget: Identifiable {
  let id: UUID
}

/// Angebot nach „Neu verknüpfen“: Stiftnotizen vom alten Ort mitnehmen (ADR-0011).
private struct CarryOffer {
  let old: MaterialReference
  let new: MaterialReference
  let count: Int
}

/// Legt das View-Modell der Tagesansicht an; es entsteht je Datenort neu (`DataScopedRoot`).
struct DayScreen: View {
  @Environment(AppEnvironment.self) private var environment

  var body: some View {
    DayViewHost(environment: environment)
  }
}

private struct DayViewHost: View {
  @State private var model: DayViewModel

  init(environment: AppEnvironment) {
    _model = State(initialValue: DayViewModel(environment: environment))
  }

  var body: some View { DayView(model: model) }
}

/// Tagesansicht (FR-4, UI-3): links die Liste der Stunden des Tages, rechts die gewählte Stunde mit Material,
/// Tafel und Aktionen. Teilplan 06 legt die Smartboard-Leiste per `.safeAreaInset(edge: .bottom)` darunter.
struct DayView: View {
  /// Swift-Hinweis: `@Bindable` erlaubt `$model.selection` für ein `@Observable`-Objekt, das als `let`
  /// übergeben wird.
  @Bindable var model: DayViewModel

  @Environment(AppEnvironment.self) private var environment
  @Environment(SecondScreenState.self) private var secondScreen
  @Environment(TimetableSourceCoordinator.self) private var coordinator
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.showSetup) private var showSetup
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif

  @State private var relinkTarget: MaterialRow?
  @State private var isImporting = false
  @State private var notice: DayNotice?
  @State private var carryOffer: CarryOffer?
  @State private var autoSaveOffer: MaterialReference?
  @State private var assignTarget: MaterialLinkItem?
  /// Zuordnung, die gerade im Betrachter offen ist (Teilplan 06).
  @State private var viewerTarget: ViewerTarget?
  /// Stunde, deren Tafel gerade offen ist (Teilplan 07).
  @State private var boardTarget: BoardTarget?
  /// Anker der zuletzt geöffneten Zeile – für „ohne AutoSpeichern öffnen“ nach der Rückkehr.
  @State private var lastAnchor = HandOffAnchor()
  /// Verbindet die Material-Kachel mit dem Betrachter (Zoom-Übergang, UI-14).
  @Namespace private var zoomNamespace

  var body: some View {
    NavigationSplitView {
      list
    } detail: {
      detail
    }
    // Smartboard-Leiste unter beiden Spalten (Teilplan 06).
    #if os(iOS)
      .safeAreaInset(edge: .bottom, spacing: 0) { SmartboardBar() }
    #endif
    // Neuer Stand von diesem oder dem anderen Gerät → neu lesen.
    .onChange(of: environment.store.revision) { model.reload() }
    // Zurück in der App: nach einer Cloud-Übergabe „ohne AutoSpeichern öffnen“ anbieten, Uhrzeit und Tag nachführen.
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        autoSaveOffer = environment.storage.offerOpenWithoutAutoSave(now: .now)
        model.sceneDidBecomeActive()
      }
    }
    // Takt für Automatik und „Jetzt“; kein automatisches Scrollen (UI-14). Endet mit dem Tageswechsel.
    .task(id: model.day) {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(30))
        model.tick()
      }
    }
    // „Am Smartboard“ ansagen (UI-12): die Kapsel allein erreicht VoiceOver beim Wechsel nicht.
    .onChange(of: secondScreen.shownMaterialLinkID) { _, linkID in
      guard let linkID, let name = materialName(for: linkID) else { return }
      AccessibilityNotification.Announcement(
        String(localized: "dayView.onSmartboard.announcement \(name)")
      ).post()
    }
    #if os(iOS)
      .sensoryFeedback(.selection, trigger: secondScreen.shownMaterialLinkID)
    #endif
    .fileImporter(isPresented: $isImporting, allowedContentTypes: [.item]) { result in
      guard let target = relinkTarget else { return }
      relinkTarget = nil
      if case .success(let url) = result {
        Task { await relink(target, to: url) }
      }
    }
    .alert(
      Text(notice?.messageKey ?? ""), isPresented: isPresent($notice), presenting: notice
    ) { notice in
      if notice == .outsideGrantedFolders || notice == .grantMissing {
        Button("dayView.grantFolder") { showSetup() }
      }
      Button("dayView.ok", role: .cancel) {}
    }
    .confirmationDialog(
      Text("lesson.relink.carryNotes \(carryOffer?.count ?? 0)"), isPresented: isPresent($carryOffer),
      titleVisibility: .visible, presenting: carryOffer
    ) { offer in
      Button("lesson.relink.carryNotes.yes") { Task { await carryNotes(offer) } }
      Button("lesson.relink.carryNotes.no", role: .cancel) {}
    }
    .confirmationDialog(
      Text("dayView.openWithoutAutoSave.title"), isPresented: isPresent($autoSaveOffer),
      titleVisibility: .visible, presenting: autoSaveOffer
    ) { reference in
      Button("dayView.openWithoutAutoSave") {
        let anchor = lastAnchor
        Task { handle(await environment.storage.openWithoutAutoSave(reference, anchor: anchor), reference) }
      }
      Button("dayView.ok", role: .cancel) {}
    }
    #if os(iOS)
      .fullScreenCover(item: $viewerTarget) { target in
        ViewerView(linkID: target.id)
          .modifier(ZoomTransition(sourceID: target.id, namespace: zoomNamespace, isEnabled: !reduceMotion))
      }
    #else
      .sheet(item: $viewerTarget) { target in
        ViewerView(linkID: target.id).frame(minWidth: 720, minHeight: 560)
      }
    #endif
    .sheet(item: $assignTarget) { item in
      AssignLessonSheet(item: item, lessons: model.assignableLessons()) { lesson in
        model.actions.move(linkID: item.id, to: lesson.key)
        model.reload()
      }
    }
  }

  // MARK: Listenspalte

  private var dayTitle: String {
    let day = model.day
    let date = Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day))
    return (date ?? .now).formatted(.dateTime.weekday(.wide).day().month(.wide).year())
  }

  @ToolbarContentBuilder private var toolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .primaryAction) {
      Button("dayView.previous", systemImage: "chevron.left") { model.showPreviousDay() }
      Button("dayView.today") { model.showToday() }
      Button("dayView.next", systemImage: "chevron.right") { model.showNextDay() }
    }
  }

  /// Die Stunden des Tages (UI-3, UI-4); darunter nur „Material ohne Stunde“, wenn es welches gibt (UI-13).
  private var list: some View {
    List(selection: $model.selection) {
      if case .rows(let rows) = model.content {
        ForEach(rows) { row in
          switch row {
          case .lesson(let lesson):
            DayListRow(
              row: lesson, line: lesson.listLine(availability: liveAvailability),
              isRunning: model.runningLessonKey == lesson.lesson.key
            )
            .tag(lesson.lesson.key)
            .modifier(SelectionRowBackground(isSelected: model.selection == lesson.lesson.key))
          case .noLesson(let period, let time):
            DayGapRow(period: period, time: time, day: model.day)
              .selectionDisabled()
              .modifier(SelectionRowBackground(isSelected: false))
          }
        }
      }
      if !model.materialsWithoutLesson.isEmpty {
        Section {
          ForEach(model.materialsWithoutLesson) { item in
            OrphanMaterialRow(
              row: MaterialRow(
                item: item, availability: environment.storage.availability[item.reference.locationKey]),
              isOpening: model.openingLinkIDs.contains(item.id), actions: rowActions
            )
            .selectionDisabled()
            .modifier(SelectionRowBackground(isSelected: false))
          }
        } header: {
          Text("dayView.withoutLesson")
        }
      }
    }
    .listStyle(.plain)
    .listRowSeparator(.hidden)
    #if os(iOS)
      .listRowSpacing(DayViewLayout.rowSpacing)
    #endif
    .modifier(ThemedSurface(hidesListBackground: true))
    .safeAreaInset(edge: .top, spacing: 0) {
      SourceStatusBar()
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    .overlay { compactEmptyState }
    .navigationTitle(Text(dayTitle))
    .toolbar { toolbar }
  }

  /// Zustand der Quelle und des Tages zur Renderzeit; `nil`, solange es Zeilen gibt.
  private var emptyState: DayEmptyState? {
    // Mitlesen, damit ein Abgleich vom anderen Gerät (Quelle, Stand) neu zeichnet.
    _ = coordinator.repository.revision
    return DayEmptyState.make(
      content: model.content,
      sourceKind: (try? coordinator.repository.timetableSourceKind()) ?? .manual,
      fetchedAt: try? coordinator.repository.sourceFetchedAt(),
      lastError: coordinator.status.lastError)
  }

  /// Schmale Breite (z. B. Split View): Das Detail ist ohne Zeilen nicht erreichbar, also zeigt die Liste
  /// den Zustand selbst. Unter macOS gibt es keine `horizontalSizeClass`.
  @ViewBuilder private var compactEmptyState: some View {
    #if os(iOS)
      if horizontalSizeClass == .compact, let state = emptyState {
        emptyView(state)
      }
    #endif
  }

  // MARK: Detailspalte

  private var detail: some View {
    Group {
      if let state = emptyState {
        emptyView(state)
      } else if let row = model.selectedRow {
        DayLessonDetail(
          row: row, day: model.day, openingIDs: model.openingLinkIDs,
          shownLinkID: secondScreen.shownMaterialLinkID,
          isBoardShown: secondScreen.isBoardShown && secondScreen.boardLessonKey == row.lesson.key,
          actions: rowActions, zoomNamespace: zoomNamespace
        )
        .id(row.id)
        .transition(.opacity)
      } else {
        emptyView(.selectLesson)
      }
    }
    // Überblendung beim Stundenwechsel, kurz; sie bleibt auch bei „Bewegung reduzieren“ (UI-14).
    .animation(.smooth(duration: 0.2), value: model.selection)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .modifier(ThemedSurface(hidesListBackground: false))
    // Die Tafel hängt an der Detailspalte, nicht am Wurzelknoten: dort sitzt schon die Anzeige des Betrachters,
    // und zwei Präsentationen am selben Knoten stören sich.
    .boardPresentation($boardTarget)
  }

  /// Ruhige Aussage statt leerer Fläche (UI-13).
  @ViewBuilder private func emptyView(_ state: DayEmptyState) -> some View {
    switch state {
    case .noLessons:
      ContentUnavailableView("dayView.noLesson", systemImage: DayStatement.noLesson.symbolName)
    case .nonTeachingDay(let title):
      ContentUnavailableView(title, systemImage: "sun.max")
    case .sourceFailed(let error):
      ContentUnavailableView {
        Label("dayView.empty.sourceFailed", systemImage: "calendar.badge.exclamationmark")
      } description: {
        if case .server(let status) = error {
          Text("timetableSource.error.server \(status)")
        } else {
          Text(LocalizedStringKey(error.settingsMessageKey))
        }
      } actions: {
        Button("dayView.retry") { Task { await coordinator.refresh(.userRequest) } }
      }
    case .selectLesson:
      ContentUnavailableView("dayView.selectLesson", systemImage: "hand.tap")
    }
  }

  // MARK: Material

  /// Zustand zur Renderzeit aus der Ablage (beobachtet); die Zeile trägt nur den Stand des letzten Lesens.
  private func liveAvailability(_ row: MaterialRow) -> MaterialAvailability? {
    environment.storage.availability[row.item.reference.locationKey] ?? row.availability
  }

  /// Name des Materials, das am Zweitbildschirm erscheint (aus den Zeilen des Tages).
  private func materialName(for linkID: UUID) -> String? {
    if case .rows(let rows) = model.content {
      for case .lesson(let lesson) in rows {
        if let material = lesson.materials.first(where: { $0.id == linkID }) {
          return material.item.reference.displayName
        }
      }
    }
    return model.materialsWithoutLesson.first { $0.id == linkID }?.reference.displayName
  }

  // MARK: Aktionen

  private var rowActions: DayRowActions {
    DayRowActions(
      open: { row, anchor in open(row, anchor: anchor) },
      relink: { row in beginRelink(row) },
      moveToNext: { row in
        if model.actions.moveToNextLesson(linkID: row.id) == nil { notice = .noNextLesson }
        model.reload()
      },
      assign: { item in assignTarget = item },
      setCancelled: { key, cancelled in
        _ = model.actions.setCancelled(cancelled, key: key)
        model.reload()
      },
      passOn: { key in
        if model.actions.passOnAll(from: key) == nil { notice = .noNextLesson }
        model.reload()
      },
      openBoard: { key in boardTarget = BoardTarget(key: key) })
  }

  private func beginRelink(_ row: MaterialRow) {
    relinkTarget = row
    isImporting = true
  }

  private func open(_ row: MaterialRow, anchor: HandOffAnchor) {
    switch model.openAction(for: row) {
    case .unavailable:
      if case .unavailable(let reason)? = row.availability {
        offer(for: reason, row: row)
      } else {
        beginRelink(row)
      }
    case .viewer(let item):
      // Eigener Betrachter (Teilplan 06): liest die Datei selbst, ohne Übergabe an eine andere App.
      lastAnchor = anchor
      viewerTarget = ViewerTarget(id: item.id)
    case .open(let reference):
      start(reference, row: row, anchor: anchor)
    }
  }

  private func start(_ reference: MaterialReference, row: MaterialRow, anchor: HandOffAnchor) {
    lastAnchor = anchor
    Task { handle(await model.open(row, anchor: anchor), reference) }
  }

  /// Übersetzt das Ergebnis von `StorageService.open` in Anzeige oder Meldung.
  private func handle(_ outcome: OpenOutcome, _ reference: MaterialReference) {
    switch outcome {
    case .handedOff, .openedAsCloudDocument:
      break
    case .waitingForDownload:
      // Ein erster Aufruf wartet schon; er öffnet die Datei von selbst, der Ladezustand bleibt.
      break
    case .failed:
      notice = .openFailed
    case .unavailable(let reason):
      offer(for: reason, row: currentRow(for: reference))
    case .showInViewer(let file):
      // Der Betrachter liest die Datei selbst: Zugriff freigeben, dann anzeigen.
      file.close()
      if environment.viewerAvailable, let row = currentRow(for: reference) {
        viewerTarget = ViewerTarget(id: row.id)
      } else {
        // Ohne Betrachter oder ohne Zuordnung zum Verweis: an die zuständige App übergeben.
        Task { handle(await environment.storage.openWithoutAutoSave(reference, anchor: lastAnchor), reference) }
      }
    }
  }

  /// Angebot je Grund (Review-Schwerpunkt 3): fehlende Freigabe → „Ordner freigeben“, offline nicht geladen →
  /// Hinweis, sonst (Datei fehlt, Laden gescheitert) „Neu verknüpfen“.
  private func offer(for reason: UnavailableReason, row: MaterialRow?) {
    switch reason {
    case .grantMissing:
      notice = .grantMissing
    case .notDownloadedOffline:
      notice = .notDownloadedOffline
    case .fileMissing, .downloadFailed:
      if let row { beginRelink(row) } else { notice = .openFailed }
    }
  }

  /// Die Zeile zum Verweis (Zuordnung desselben Orts) – für „Neu verknüpfen“ nach `.unavailable`.
  private func currentRow(for reference: MaterialReference) -> MaterialRow? {
    var candidates: [MaterialRow] = []
    if case .rows(let rows) = model.content {
      for case .lesson(let lesson) in rows { candidates += lesson.materials }
    }
    candidates += model.materialsWithoutLesson.map {
      MaterialRow(item: $0, availability: environment.storage.availability[$0.reference.locationKey])
    }
    return candidates.first { $0.item.reference.locationKey == reference.locationKey }
  }

  private func relink(_ row: MaterialRow, to url: URL) async {
    let new: MaterialReference
    do throws(AssignError) {
      new = try model.actions.relink(row.item, fileURL: url)
    } catch {
      switch error {
      case .saveFailed: notice = .relinkSaveFailed
      case .outsideGrantedFolders: notice = .outsideGrantedFolders
      }
      return
    }
    model.reload()
    let count = await model.actions.notesToCarry(from: row.item.reference)
    if count > 0 { carryOffer = CarryOffer(old: row.item.reference, new: new, count: count) }
  }

  private func carryNotes(_ offer: CarryOffer) async {
    do {
      try await model.actions.carryNotes(from: offer.old, to: offer.new)
    } catch {
      notice = .carryNotesFailed
    }
  }

  /// `Bool`-Bindung für Dialoge, die an einem Optional hängen.
  private func isPresent<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
    Binding(
      get: { value.wrappedValue != nil },
      set: { if !$0 { value.wrappedValue = nil } })
  }
}

/// Auswahl einer Unterrichtsstunde der nächsten 14 Tage für „Material ohne Stunde“ (FR-7).
struct AssignLessonSheet: View {
  let item: MaterialLinkItem
  let lessons: [Lesson]
  let onPick: (Lesson) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        if lessons.isEmpty {
          Text("dayView.assign.empty").foregroundStyle(.secondary)
        }
        ForEach(lessons, id: \.key) { lesson in
          Button {
            onPick(lesson)
            dismiss()
          } label: {
            Text(
              "dayView.assign.lesson \(Self.dateText(lesson.key.date)) \(lesson.period) \(lesson.key.schoolClass.normalized) \(lesson.key.subject.display)"
            )
            .frame(minHeight: 44, alignment: .leading)
          }
        }
      }
      .navigationTitle(Text("dayView.assign.title"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("dayView.assign.cancel") { dismiss() }
        }
      }
    }
  }

  private static func dateText(_ day: CalendarDay) -> String {
    let date = Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day))
    return (date ?? .now).formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
  }
}

/// Hintergrund der Spalten in der gewählten Farbwelt (UI-8, UI-10). Beim Grundton „System“ bleibt alles beim
/// Systemstandard (Entscheidung 14).
private struct ThemedSurface: ViewModifier {
  let hidesListBackground: Bool
  @Environment(\.themeStyle) private var style

  func body(content: Content) -> some View {
    if style.usesSystemNeutrals {
      content
    } else if hidesListBackground {
      content.scrollContentBackground(.hidden).background(style.background)
    } else {
      content.background(style.background)
    }
  }
}

/// Zeilenfläche der Liste: gewählt mit gerundeter Auswahlfläche, sonst Grundfarbe; beim Grundton „System“
/// nichts davon.
private struct SelectionRowBackground: ViewModifier {
  let isSelected: Bool
  @Environment(\.themeStyle) private var style

  func body(content: Content) -> some View {
    if style.usesSystemNeutrals {
      content
    } else if isSelected {
      content.listRowBackground(
        RoundedRectangle(cornerRadius: DayViewLayout.selectionRadius, style: .continuous)
          .fill(style.selection))
    } else {
      content.listRowBackground(style.background)
    }
  }
}

#if os(iOS)
  /// Zoom-Übergang vom Material zum Betrachter; bei „Bewegung reduzieren“ die Systemdarstellung (UI-14).
  private struct ZoomTransition: ViewModifier {
    let sourceID: UUID
    let namespace: Namespace.ID
    let isEnabled: Bool

    func body(content: Content) -> some View {
      if isEnabled {
        content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
      } else {
        content
      }
    }
  }
#endif
