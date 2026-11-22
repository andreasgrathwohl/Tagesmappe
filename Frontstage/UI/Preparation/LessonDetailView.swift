import FrontstageCore
import SwiftUI
import UniformTypeIdentifiers

/// Einzelheiten einer Stunde (FR-3, FR-7, FR-8, FR-13): Material ordnen, übernehmen, weiterreichen,
/// Ausfall, Stundenangaben. Teilplan 07 ergänzt „Tafel“: die Tafelbilder der Stunde ansehen und als PDF sichern
/// (FR-12.1, FR-12.4; bezahlt, daher hinter `PaidGate(.board)` wie in der Tagesansicht).
///
/// Das Material steht in einem `List`; `onMove` ordnet am Mac durch Ziehen, am iPad im Bearbeiten-Modus.
/// Systemstandard ohne eigene Palette oder Schrift; Gestaltung ist offen (DESIGN.md).
struct LessonDetailView: View {
  let key: LessonKey
  let model: PreparationViewModel

  @Environment(AppEnvironment.self) private var environment
  // Liegt außerhalb des datengebundenen Teilbaums (`RootView`) und kennt daher immer den aktuellen Store.
  @Environment(DataLocationController.self) private var dataLocation
  @Environment(\.scenePhase) private var scenePhase

  // Swift-Hinweis: `@State` an einer `@Observable`-Klasse hält die Instanz über Neuzeichnen hinweg;
  // `$editor.topic` liefert dann eine Bindung auf ihr Feld.
  @State private var editor: LessonInfoEditor
  @State private var isImporting = false
  @State private var showCopyPicker = false
  @State private var notice: PreparationNotice?
  /// Ablauf „Lösung hinzufügen“ (FR-6.3).
  @State private var solutionTarget: SolutionTarget?
  /// Stunde, deren Tafel gerade offen ist (Teilplan 07).
  @State private var boardTarget: BoardTarget?

  init(key: LessonKey, model: PreparationViewModel) {
    self.key = key
    self.model = model
    _editor = State(initialValue: LessonInfoEditor(key: key, store: model.actions.store))
  }

  private var actions: LessonActions { model.actions }

  /// Die Stunde aus der Woche; `nil`, wenn es sie nicht mehr gibt (z. B. nach einem Stundenplan-Abruf).
  private var lessonRow: LessonRow? {
    for day in model.days where day.date == key.date {
      if case .rows(let rows) = day.content {
        for case .lesson(let lesson) in rows where lesson.lesson.key == key { return lesson }
      }
    }
    return nil
  }

  /// Liest bei jedem Zeichnen neu; `store.revision` ist beobachtbar und löst das Neuzeichnen aus.
  private var materials: [MaterialLinkItem] {
    (try? actions.store.materialLinkItems(for: key)) ?? []
  }

  var body: some View {
    Group {
      if let row = lessonRow {
        content(row)
          // An der inneren Ansicht, nicht neben dem Sheet „Kopieren nach“: zwei Präsentationen am selben Knoten
          // stören sich (wie in der Tagesansicht).
          .boardPresentation($boardTarget)
      } else {
        ContentUnavailableView("preparation.lessonMissing", systemImage: "questionmark.folder")
      }
    }
    .modifier(
      MaterialDropTarget(key: key, actions: actions, onError: { notice = PreparationNotice($0) })
    )
    .preparationNotice($notice)
    .solutionPicking(target: $solutionTarget)
    .fileImporter(
      isPresented: $isImporting, allowedContentTypes: [.item], allowsMultipleSelection: true
    ) { result in
      guard case .success(let urls) = result else { return }
      Task {
        do throws(AssignError) {
          try await actions.assign(fileURLs: urls, to: key)
        } catch {
          notice = PreparationNotice(error)
        }
      }
    }
    .sheet(isPresented: $showCopyPicker) {
      CopyTargetPicker(source: key, actions: actions) { count in
        notice = .copied(count)
      }
    }
    // Speichern beim Verlassen der Stunde und beim Verlassen der App (nur bei echter Änderung und
    // nur, solange die Stunde noch existiert).
    .onDisappear { saveIfPresent() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background { saveIfPresent() }
    }
    // Änderungen eines anderen Geräts übernehmen, solange hier nichts bearbeitet wurde.
    .onChange(of: actions.store.revision) { editor.reloadIfUnedited() }
  }

  /// Speichert, solange die Stunde im aktuellen Datenort noch existiert.
  ///
  /// Geprüft wird über den Store, nicht über `lessonRow`: Beim Wochenwechsel lädt `PreparationViewModel`
  /// die neue Woche, **bevor** die Auswahl zurückgesetzt wird und dieses Detail verschwindet – `model.days`
  /// enthält die Stunde dann nicht mehr, und ungesicherter Text (am Mac ohne Return) ginge verloren.
  ///
  /// Nach einem Wechsel des Datenorts hält der Editor noch den alten Store; dorthin wird nicht mehr
  /// geschrieben (der Text gehörte zum alten Ort). Swift-Hinweis: `===` vergleicht Objektidentität und
  /// nimmt auch ein klassengebundenes Existential wie `any PreparationStore`.
  private func saveIfPresent() {
    guard actions.store === dataLocation.store else { return }
    guard let lessons = try? actions.store.lessons(on: key.date),
      lessons.contains(where: { $0.key == key })
    else { return }
    editor.save()
  }

  // MARK: Inhalt

  private func content(_ row: LessonRow) -> some View {
    let items = materials
    return List {
      infoSection
      materialSection(items)
      actionSection(row, hasMaterial: !items.isEmpty)
    }
    .themedBackground()
    .navigationTitle(
      Text(verbatim: "\(row.lesson.key.schoolClass.normalized) · \(row.lesson.key.subject.display)")
    )
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { EditButton() }
    #endif
  }

  private var infoSection: some View {
    Section("lesson.info") {
      TextField("lesson.topic", text: $editor.topic)
        .onSubmit { editor.save() }
      TextField("lesson.toPrepare", text: $editor.toPrepare)
        .onSubmit { editor.save() }
      TextField("lesson.homework", text: $editor.homework)
        .onSubmit { editor.save() }
      // Vorschlag aus dem Jahresplan (FR-15.5): wird nie automatisch übernommen.
      if let planned = lessonRow?.planHint?.plannedTopic, planned != editor.topic {
        HStack {
          Text("planHint.suggestion \(planned)")
            .foregroundStyle(.secondary)
          Spacer(minLength: 8)
          Button("planHint.useTopic") {
            editor.topic = planned
            editor.save()
          }
          .frame(minHeight: 44)
        }
      }
    }
  }

  private func materialSection(_ items: [MaterialLinkItem]) -> some View {
    Section("lesson.material") {
      if items.isEmpty {
        Text("lesson.noMaterial").foregroundStyle(.secondary)
      }
      ForEach(items) { item in
        HStack {
          Text(verbatim: item.reference.displayName)
            .lineLimit(1)
            .truncationMode(.middle)
          if environment.storage.availability[item.reference.locationKey].isUnavailable {
            Image(systemName: DayStatement.materialUnavailable.symbolName)
              .accessibilityLabel(Text(LocalizedStringKey(DayStatement.materialUnavailable.labelKey)))
          }
          if item.solution != nil {
            Image(systemName: "checkmark.seal")
              .foregroundStyle(.secondary)
              .accessibilityLabel(Text("solution.withSolution"))
          }
          Spacer(minLength: 8)
          Menu {
            Button("lesson.moveToNext", systemImage: "arrow.right") { moveToNext(item) }
            if item.reference.fileKind.opensInViewer {
              if item.solution == nil {
                Button("solution.add", systemImage: "doc.badge.plus") {
                  solutionTarget = SolutionTarget(linkID: item.id, sheet: item.reference)
                }
              } else {
                Button("solution.replace", systemImage: "arrow.triangle.2.circlepath") {
                  solutionTarget = SolutionTarget(linkID: item.id, sheet: item.reference)
                }
                Button("solution.remove", systemImage: "trash", role: .destructive) {
                  if (try? actions.store.setSolution(nil, forLinkID: item.id)) == nil { notice = .saveFailed }
                }
              }
            }
            Button("lesson.remove", systemImage: "trash", role: .destructive) {
              actions.remove(linkID: item.id)
            }
          } label: {
            Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44)
          }
          .accessibilityLabel(Text("lesson.moreActions"))
        }
        .frame(minHeight: 44)
      }
      .onMove { offsets, destination in
        actions.reorder(key, fromOffsets: offsets, toOffset: destination)
      }
      .onDelete { offsets in
        for index in offsets where items.indices.contains(index) {
          actions.remove(linkID: items[index].id)
        }
      }
      Button("preparation.addMaterial", systemImage: "plus") { isImporting = true }
        .frame(minHeight: 44)
    }
  }

  private func actionSection(_ row: LessonRow, hasMaterial: Bool) -> some View {
    Section {
      Button("lesson.copyTo", systemImage: "doc.on.doc") { showCopyPicker = true }
        .disabled(!hasMaterial)
        .frame(minHeight: 44)
      Button("lesson.passOn", systemImage: "arrow.right.circle") {
        if actions.passOnAll(from: key) == nil { notice = .noNextLesson }
        model.reload()
      }
      .disabled(!hasMaterial)
      .frame(minHeight: 44)
      Toggle("lesson.cancel", isOn: cancelBinding(row))
        .frame(minHeight: 44)
      // Tafelbilder der Stunde ansehen und als PDF sichern; der Export sitzt in `BoardScreen` (Aufgabe 10).
      Button("board.title", systemImage: "pencil.and.scribble") { boardTarget = BoardTarget(key: key, mirror: false) }
        .frame(minHeight: 44)
    }
  }

  // MARK: Aktionen

  private func moveToNext(_ item: MaterialLinkItem) {
    if actions.moveToNextLesson(linkID: item.id) == nil { notice = .noNextLesson }
    model.reload()
  }

  /// Umschalter „Ausfall“. Ein Ausfall aus der Stundenplan-Quelle lässt sich nicht aufheben: Der
  /// Schalter springt zurück (Neuzeichnen) und ein Hinweis sagt warum.
  private func cancelBinding(_ row: LessonRow) -> Binding<Bool> {
    Binding(
      get: {
        if case .cancelled = row.status { return true }
        return false
      },
      set: { cancelled in
        let result = actions.setCancelled(cancelled, key: key)
        if result == .blockedBySource { notice = .blockedBySource }
        model.reload()
      })
  }
}
