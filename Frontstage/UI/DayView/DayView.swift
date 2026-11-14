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

/// Tagesansicht (FR-4): alle Stunden des Tages ohne Scrollen, Material als Knöpfe.
///
/// Teilplan 06 legt die Smartboard-Leiste per `.safeAreaInset(edge: .bottom)` darunter; die Höhe der Zeilen
/// folgt aus dem `GeometryReader` und passt sich damit an.
struct DayView: View {
  let model: DayViewModel

  @Environment(AppEnvironment.self) private var environment
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.showSetup) private var showSetup

  @State private var relinkTarget: MaterialRow?
  @State private var isImporting = false
  @State private var notice: DayNotice?
  @State private var carryOffer: CarryOffer?
  @State private var autoSaveOffer: MaterialReference?
  @State private var assignTarget: MaterialLinkItem?
  /// Anker der zuletzt geöffneten Zeile – für „ohne AutoSpeichern öffnen“ nach der Rückkehr.
  @State private var lastAnchor = HandOffAnchor()


  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        SourceStatusBar()
          .padding(.horizontal)
          .padding(.bottom, 8)
        GeometryReader { proxy in
          content(availableHeight: proxy.size.height)
        }
      }
      .navigationTitle(Text(dayTitle))
      .toolbar { toolbar }
    }
    // Neuer Stand von diesem oder dem anderen Gerät → neu lesen.
    .onChange(of: environment.store.revision) { model.reload() }
    // Zurück in der App nach einer Cloud-Übergabe: „ohne AutoSpeichern öffnen“ anbieten.
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        autoSaveOffer = environment.storage.offerOpenWithoutAutoSave(now: .now)
      }
    }
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
    .sheet(item: $assignTarget) { item in
      AssignLessonSheet(item: item, lessons: model.assignableLessons()) { lesson in
        model.actions.move(linkID: item.id, to: lesson.key)
        model.reload()
      }
    }
  }

  // MARK: Kopf

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

  // MARK: Inhalt

  @ViewBuilder private func content(availableHeight: CGFloat) -> some View {
    switch model.content {
    case .nonTeachingDay(let title):
      ScrollView {
        VStack(spacing: 16) {
          ContentUnavailableView(title, systemImage: "sun.max")
          orphanSection
        }
        .padding(.horizontal)
      }
    case .noLessons:
      ScrollView {
        VStack(spacing: 16) {
          ContentUnavailableView(
            "dayView.noLesson", systemImage: DayStatement.noLesson.symbolName)
          orphanSection
        }
        .padding(.horizontal)
      }
    case .rows(let rows):
      let reserve = DayViewLayout.orphanReserve(count: model.materialsWithoutLesson.count)
      // Höhe fest, solange selbst die Mindesthöhe passt; sonst `nil` → Scrollen.
      if let rowHeight = DayViewLayout.rowHeight(
        availableHeight: availableHeight - reserve, rowCount: rows.count)
      {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(rows) { row in
            DayRowView(row: row, openingIDs: model.openingLinkIDs, actions: rowActions)
              .frame(height: rowHeight)
          }
          // Eigener Scrollbereich mit Höchsthöhe: auch viele Einträge bleiben erreichbar (FR-7).
          ScrollView { orphanSection }
            .frame(maxHeight: reserve)
          Spacer(minLength: 0)
        }
        .padding(.horizontal)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(rows) { row in
              DayRowView(row: row, openingIDs: model.openingLinkIDs, actions: rowActions)
                .frame(minHeight: DayViewLayout.minRowHeight)
            }
            orphanSection
          }
          .padding(.horizontal)
        }
      }
    }
  }

  /// „Material ohne Stunde“ (FR-7): Zuordnungen dieses Tages, deren Stunde es heute nicht gibt.
  @ViewBuilder private var orphanSection: some View {
    if !model.materialsWithoutLesson.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Divider()
        Text("dayView.withoutLesson").font(.headline)
        ForEach(model.materialsWithoutLesson) { item in
          let row = MaterialRow(item: item, availability: environment.storage.availability[item.reference.locationKey])
          HStack {
            MaterialButton(
              row: row, isOpening: model.openingLinkIDs.contains(row.id), style: .full, inLesson: false,
              actions: rowActions)
            Button("dayView.assign") { assignTarget = item }
              .frame(minHeight: 44)
          }
        }
      }
    }
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
      })
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
      // Der eigene Betrachter kommt mit Teilplan 06; bis dahin verhält sich der Zweig wie `.open`.
      start(item.reference, row: row, anchor: anchor)
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
      // Teilplan 06 zeigt die Datei im Betrachter. Solange er fehlt: Zugriff freigeben und übergeben.
      file.close()
      if !environment.viewerAvailable {
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
