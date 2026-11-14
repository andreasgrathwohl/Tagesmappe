import FrontstageCore
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Eine für die Auswahl bereitgestellte Quelle: eine lokale, temporäre Kopie der PDF- oder Bilddatei.
/// Die Kopie lebt nur, solange der Dialog offen ist; das Original in der Ablage wird nur gelesen (FR-12.6).
private struct PreparedTemplate: Equatable, Sendable {
  enum Kind: Sendable { case pdf, image }

  let url: URL
  /// Der Ordner der Kopie; wird beim Schließen gelöscht.
  let directory: URL
  let kind: Kind
  let pageCount: Int
}

/// Dateiarbeit abseits des Hauptthreads.
///
/// Swift-Hinweis: Eine SwiftUI-`View` ist in Swift 6 an den Hauptakteur gebunden, und damit auch ihre Methoden. Alles,
/// was in `Task.detached` oder in einem `@Sendable`-Abschluss läuft, steht deshalb in diesem Typ ohne Akteur-Bindung.
private enum TemplateSourceFiles {
  /// Legt einen neuen, leeren Ordner für die Kopie an.
  static func makeDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("template-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// Kopiert eine lesbare Datei in den Ordner (der Name wird neutral, die Endung bleibt).
  static func copy(_ source: URL, into directory: URL, fileExtension: String) throws -> URL {
    let name = fileExtension.isEmpty ? "source" : "source.\(fileExtension)"
    let target = directory.appendingPathComponent(name)
    try FileManager.default.copyItem(at: source, to: target)
    return target
  }

  /// Aus der Ablage gewählte Datei: Zugriff nur für das Kopieren öffnen und danach in jedem Fall beenden.
  static func importPicked(_ url: URL, into directory: URL) throws -> URL {
    let accessing = url.startAccessingSecurityScopedResource()
    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
    return try copy(url, into: directory, fileExtension: url.pathExtension.lowercased())
  }

  /// Bestimmt Art und Seitenzahl der Kopie; `nil`, wenn sie weder lesbares PDF noch Bild ist.
  static func prepare(_ url: URL, in directory: URL) -> PreparedTemplate? {
    switch MaterialFileKind(fileExtension: url.pathExtension) {
    case .pdf:
      guard let count = TemplateRenderer.pageCount(ofPDFAt: url), count > 0 else { return nil }
      return PreparedTemplate(url: url, directory: directory, kind: .pdf, pageCount: count)
    case .image:
      return PreparedTemplate(url: url, directory: directory, kind: .image, pageCount: 1)
    default:
      return nil
    }
  }

  /// Vorschau (JPEG-Daten) einer Seite bzw. des Bildes.
  static func preview(of template: PreparedTemplate, pageIndex: Int, maxSide: Int) -> Data? {
    switch template.kind {
    case .pdf: try? TemplateRenderer.previewPDFPage(at: template.url, pageIndex: pageIndex, maxSide: maxSide)
    case .image: try? TemplateRenderer.previewImage(at: template.url, maxSide: maxSide)
    }
  }

  static func render(_ template: PreparedTemplate, pageIndex: Int, crop: CGRect?) throws -> Data {
    switch template.kind {
    case .pdf: try TemplateRenderer.renderPDFPage(at: template.url, pageIndex: pageIndex, crop: crop)
    case .image: try TemplateRenderer.renderImage(at: template.url, crop: crop)
    }
  }

  static func remove(_ directory: URL) {
    try? FileManager.default.removeItem(at: directory)
  }
}

/// Vorlage für eine neue Tafelseite: Material der Unterrichtsstunde oder Datei aus der Ablage, bei PDF mit
/// Seitenwahl, danach optional ein Ausschnitt per Ziehrechteck (FR-12.6). „Übernehmen“ legt eine Seite mit dem
/// gerenderten Bild als Hintergrund an. Systemstandard-Bedienelemente (Design-Kategorien offen).
struct TemplatePicker: View {
  let lessonKey: LessonKey
  let session: BoardSession

  @Environment(\.dismiss) private var dismiss
  @Environment(DataStore.self) private var store: DataStore?
  @Environment(StorageService.self) private var storage: StorageService?

  @State private var materials: [MaterialReference] = []
  @State private var prepared: PreparedTemplate?
  @State private var isLoading = false
  @State private var isApplying = false
  @State private var isImporting = false
  @State private var failed = false
  @State private var pageIndex = 0
  /// Normierter Ausschnitt (0…1, Ursprung oben links); `nil` = ganze Seite.
  @State private var crop: CGRect?
  @State private var previewImage: CGImage?

  var body: some View {
    NavigationStack {
      Group {
        if let prepared {
          configure(prepared)
        } else {
          chooser
        }
      }
      .navigationTitle(Text("board.template"))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("board.cancel") { dismiss() }
        }
        if prepared != nil {
          ToolbarItem(placement: .confirmationAction) {
            Button("board.template.apply") { apply() }
              .disabled(isApplying)
          }
        }
      }
    }
    .task { loadMaterials() }
    .fileImporter(isPresented: $isImporting, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: false) {
      result in
      if case .success(let urls) = result, let url = urls.first {
        prepare { directory in try TemplateSourceFiles.importPicked(url, into: directory) }
      }
    }
    .alert(Text("board.template.failed"), isPresented: $failed) {
      Button("dayView.ok", role: .cancel) {}
    }
    // Die temporäre Kopie gehört nur zu diesem Dialog.
    .onDisappear {
      if let prepared { TemplateSourceFiles.remove(prepared.directory) }
    }
  }

  // MARK: Auswahl der Quelle

  private var chooser: some View {
    List {
      if !materials.isEmpty {
        Section("board.template.lessonMaterial") {
          ForEach(materials, id: \.self) { reference in
            materialRow(reference)
          }
        }
      }
      Section {
        Button("board.template.fromStorage", systemImage: "folder") { isImporting = true }
          .frame(minHeight: 44)
      }
      if isLoading {
        Section { ProgressView().frame(maxWidth: .infinity) }
      }
    }
    .disabled(isLoading)
  }

  @ViewBuilder private func materialRow(_ reference: MaterialReference) -> some View {
    let usable = reference.fileKind == .pdf || reference.fileKind == .image
    Button {
      choose(reference)
    } label: {
      VStack(alignment: .leading, spacing: 2) {
        Label(
          reference.displayName, systemImage: reference.fileKind == .pdf ? "doc.richtext" : "photo")
        if !usable {
          Text("board.template.onlyPdfImage").font(.caption).foregroundStyle(.secondary)
        }
      }
      .frame(minHeight: 44, alignment: .leading)
    }
    .disabled(!usable || storage == nil)
  }

  // MARK: Seite und Ausschnitt

  private func configure(_ template: PreparedTemplate) -> some View {
    VStack(spacing: 12) {
      if template.kind == .pdf, template.pageCount > 1 {
        pageStrip(template)
      }
      preview(template)
      Button {
        crop = nil
      } label: {
        if crop == nil {
          Label("board.template.wholePage", systemImage: "checkmark")
        } else {
          Text("board.template.wholePage")
        }
      }
      .buttonStyle(.bordered)
      .frame(minHeight: 44)
      Text("board.template.crop.hint").font(.footnote).foregroundStyle(.secondary)
    }
    .padding()
    .task(id: pageIndex) { await loadPreview(template) }
    .overlay { if isApplying { ProgressView() } }
  }

  /// Seitenwahl mit Vorschaubildern (nur bei PDF mit mehreren Seiten).
  private func pageStrip(_ template: PreparedTemplate) -> some View {
    ScrollView(.horizontal) {
      LazyHStack(spacing: 8) {
        ForEach(0..<template.pageCount, id: \.self) { index in
          Button {
            pageIndex = index
            crop = nil
          } label: {
            TemplatePageThumbnail(template: template, pageIndex: index, isSelected: index == pageIndex)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(Text("board.template.page \(index + 1)"))
          .accessibilityAddTraits(index == pageIndex ? .isSelected : [])
        }
      }
    }
    .frame(height: 110)
  }

  @ViewBuilder private func preview(_ template: PreparedTemplate) -> some View {
    if let previewImage {
      Image(decorative: previewImage, scale: 1)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .overlay { cropOverlay }
        .overlay(Rectangle().strokeBorder(.separator))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  /// Das Ziehrechteck über der Vorschau; die Fläche entspricht genau der Seite, die Werte sind normiert.
  private var cropOverlay: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        Color.clear.contentShape(Rectangle())
        if let crop {
          Rectangle()
            .strokeBorder(Color.accentColor, lineWidth: 2)
            .background(Color.accentColor.opacity(0.15))
            .frame(width: crop.width * proxy.size.width, height: crop.height * proxy.size.height)
            .offset(x: crop.minX * proxy.size.width, y: crop.minY * proxy.size.height)
        }
      }
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            crop = Self.cropRect(from: value.startLocation, to: value.location, in: proxy.size)
          }
      )
    }
  }

  /// Rechteck zwischen zwei Punkten, normiert und auf die Fläche begrenzt; zu klein (bloßes Tippen) = kein Ausschnitt.
  private static func cropRect(from start: CGPoint, to end: CGPoint, in size: CGSize) -> CGRect? {
    guard size.width > 0, size.height > 0 else { return nil }
    func unit(_ value: CGFloat, _ length: CGFloat) -> CGFloat { min(max(value / length, 0), 1) }
    let x1 = unit(start.x, size.width)
    let y1 = unit(start.y, size.height)
    let x2 = unit(end.x, size.width)
    let y2 = unit(end.y, size.height)
    let rect = CGRect(x: min(x1, x2), y: min(y1, y2), width: abs(x2 - x1), height: abs(y2 - y1))
    return rect.width >= 0.02 && rect.height >= 0.02 ? rect : nil
  }

  // MARK: Aktionen

  private func loadMaterials() {
    materials = (try? store?.links(for: lessonKey))?.map(\.reference) ?? []
  }

  private func choose(_ reference: MaterialReference) {
    guard let storage else { return }
    let ext = reference.fileExtension
    prepare { directory in
      try await storage.withFileURL(for: reference) { source in
        try TemplateSourceFiles.copy(source, into: directory, fileExtension: ext)
      }
    }
  }

  /// Besorgt die lokale Kopie (abseits des Hauptthreads) und wechselt zur Seiten- und Ausschnittwahl.
  private func prepare(_ copy: @escaping @Sendable (URL) async throws -> URL) {
    guard !isLoading else { return }
    isLoading = true
    Task {
      defer { isLoading = false }
      do {
        let directory = try TemplateSourceFiles.makeDirectory()
        do {
          let url = try await copy(directory)
          let result = await Task.detached { TemplateSourceFiles.prepare(url, in: directory) }.value
          guard let result else { throw TemplateRendererError.unreadable }
          pageIndex = 0
          crop = nil
          previewImage = nil
          prepared = result
        } catch {
          TemplateSourceFiles.remove(directory)
          throw error
        }
      } catch {
        failed = true
      }
    }
  }

  private func loadPreview(_ template: PreparedTemplate) async {
    let index = pageIndex
    let data = await Task.detached { TemplateSourceFiles.preview(of: template, pageIndex: index, maxSide: 1200) }.value
    guard !Task.isCancelled else { return }
    previewImage = data.flatMap { TemplateThumbnails.cgImage(from: $0) }
  }

  private func apply() {
    guard let template = prepared, !isApplying else { return }
    isApplying = true
    let index = pageIndex
    let area = crop
    Task {
      defer { isApplying = false }
      do {
        let data = try await Task.detached { try TemplateSourceFiles.render(template, pageIndex: index, crop: area) }
          .value
        try session.addPage(background: .image, imageData: data)
        dismiss()
      } catch {
        failed = true
      }
    }
  }
}

/// JPEG-Daten als `CGImage` lesen (Vorschauen).
enum TemplateThumbnails {
  static func cgImage(from data: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
  }
}

/// Vorschaubild einer PDF-Seite; lädt beim Erscheinen abseits des Hauptthreads.
private struct TemplatePageThumbnail: View {
  let template: PreparedTemplate
  let pageIndex: Int
  let isSelected: Bool

  @State private var image: CGImage?

  var body: some View {
    VStack(spacing: 2) {
      Group {
        if let image {
          Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
        } else {
          Color.secondary.opacity(0.1).aspectRatio(0.7, contentMode: .fit)
        }
      }
      .frame(height: 84)
      .overlay(Rectangle().strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: isSelected ? 3 : 1))
      Text(verbatim: "\(pageIndex + 1)").font(.caption)
    }
    .task {
      let data = await Task.detached { [template, pageIndex] in
        TemplateSourceFiles.preview(of: template, pageIndex: pageIndex, maxSide: 200)
      }.value
      image = data.flatMap { TemplateThumbnails.cgImage(from: $0) }
    }
  }
}
