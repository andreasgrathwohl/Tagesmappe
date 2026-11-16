import FrontstageCore
import PencilKit
import PhotosUI
import SwiftUI

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Rückmeldung schreiben und senden (FR-17.3, FR-17.4): Art, Text, Bildschirmfotos, Geräteangaben und je nach
/// Ausstattung Hochladen, Mail oder Teilen. Die Ansicht kennt keine Plattformdetails außer über
/// `MailComposeView` und `MacMailComposer`.
struct FeedbackView: View {
  let model: FeedbackModel

  @Environment(\.dismiss) private var dismiss
  @ScaledMetric(relativeTo: .body) private var editorHeight: CGFloat = 160

  @State private var showConsent = false
  @State private var showDiscardConfirm = false
  @State private var showSent = false
  @State private var showFailed = false
  @State private var sentReference = ""
  /// „Lieber per Mail“ bzw. nach einem Ausfall: der Rückfallweg ersetzt das Hochladen für diese Sitzung.
  @State private var useFallback = false
  @State private var photoSelection: [PhotosPickerItem] = []
  @State private var editing: EditorTarget?
  @State private var shareURLs: [URL] = []
  @State private var shareFailed = false
  #if os(iOS)
    @State private var mailRequest: MailRequest?
  #else
    @State private var macComposer = MacMailComposer()
  #endif

  /// Was der Bildeditor gerade bearbeitet.
  private struct EditorTarget: Identifiable {
    let id: UUID
    let imageData: Data
    let model: MarkupEditorModel
  }

  #if os(iOS)
    private struct MailRequest: Identifiable {
      let id = UUID()
      let recipient: String
      let attachments: [(fileName: String, data: Data)]
    }
  #endif

  private var activeRoute: FeedbackRoute { useFallback ? model.fallbackRoute : model.route }

  private var isUploading: Bool {
    if case .uploading = model.uploadState { return true }
    return false
  }

  var body: some View {
    NavigationStack {
      Form {
        failureSection
        kindSection
        textSection
        attachmentsSection
        deviceInfoSection
        routeNoteSection
        progressSection
      }
      .formStyle(.grouped)
      .disabled(isUploading)
      .themedBackground()
      .navigationTitle(Text("feedback.title"))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar { toolbar }
    }
    .task(id: model.draft) {
      // Entprellt: erst 400 ms nach der letzten Änderung speichern. Ein abgebrochener Schlaf beendet die Aufgabe.
      do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
      model.persist()
    }
    .task(id: model.draft.attachments) { refreshShareFiles() }
    .onChange(of: photoSelection) { _, items in loadPhotos(items) }
    .onChange(of: useFallback) { refreshShareFiles() }
    .onChange(of: model.uploadState) { _, state in uploadStateChanged(state) }
    .sheet(isPresented: $showConsent) { consentSheet }
    #if os(iOS)
      .fullScreenCover(item: $editing, content: editorContent)
    #else
      .sheet(item: $editing, content: editorContent)
    #endif
    #if os(iOS)
      .sheet(item: $mailRequest) { request in
        MailComposeView(
          recipient: request.recipient, message: model.message, attachments: request.attachments
        ) { handedOver in
          mailRequest = nil
          if handedOver { completeHandover() }
        }
      }
    #endif
    .confirmationDialog(
      Text("feedback.discard.confirm"), isPresented: $showDiscardConfirm, titleVisibility: .visible
    ) {
      Button("feedback.discard", role: .destructive) {
        model.discard()
        dismiss()
      }
    }
    .alert(Text("feedback.sent"), isPresented: $showSent) {
      Button("feedback.sent.copyReference") {
        copyToPasteboard(sentReference)
        dismiss()
      }
      Button("feedback.ok", role: .cancel) { dismiss() }
    } message: {
      Text("feedback.sent.reference \(sentReference)")
    }
    .alert(Text("feedback.sendFailed"), isPresented: $showFailed) {
      Button("feedback.ok", role: .cancel) {}
    }
  }

  // MARK: Abschnitte

  @ViewBuilder private var failureSection: some View {
    if case .failed(let error) = model.uploadState {
      Section {
        Label {
          Text(reason(error))
        } icon: {
          Image(systemName: "exclamationmark.triangle")
        }
        if error != .rateLimited, !isRejected(error) {
          Button("feedback.upload.retry") { retry() }
        }
        Button {
          useFallback = true
          model.resetUploadState()
        } label: {
          switch model.fallbackRoute {
          case .mail: Text("feedback.upload.viaMail")
          default: Text("feedback.share")
          }
        }
      }
    }
  }

  private var kindSection: some View {
    Section {
      Picker(
        "feedback.title",
        selection: Binding(get: { model.draft.kind }, set: { model.setKind($0) })
      ) {
        Text("feedback.kind.idea").tag(FeedbackKind.idea)
        Text("feedback.kind.issue").tag(FeedbackKind.issue)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
    }
  }

  private var textSection: some View {
    Section {
      TextEditor(text: Binding(get: { model.draft.text }, set: { model.setText($0) }))
        .frame(minHeight: editorHeight)
        .overlay(alignment: .topLeading) {
          if model.draft.text.isEmpty {
            Text(
              model.draft.kind == .idea ? "feedback.text.placeholder.idea" : "feedback.text.placeholder.issue"
            )
            .foregroundStyle(.secondary)
            .padding(.top, 8)
            .padding(.leading, 5)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
          }
        }
    } footer: {
      if let topic = model.draft.topic, let article = HelpLibrary.shared.article(for: topic) {
        Text("feedback.aboutTopic \(article.title)")
      }
    }
  }

  private var attachmentsSection: some View {
    Section {
      if !model.draft.attachments.isEmpty {
        AttachmentStrip(model: model, onEdit: openEditor)
          .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
      }
      if model.remainingSlots > 0 {
        PhotosPicker(selection: $photoSelection, maxSelectionCount: model.remainingSlots, matching: .images) {
          Label("feedback.attachments.add", systemImage: "photo.badge.plus")
        }
      }
    } header: {
      Text("feedback.attachments.title \(model.draft.attachments.count)")
    } footer: {
      Text("feedback.attachments.privacyHint")
    }
  }

  private var deviceInfoSection: some View {
    Section {
      Toggle(
        "feedback.deviceInfo",
        isOn: Binding(get: { model.draft.includesDeviceInfo }, set: { model.setIncludesDeviceInfo($0) }))
      DisclosureGroup("feedback.deviceInfo.what") {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(model.deviceInfoPreview, id: \.self) { line in
            Text(line)
          }
          Text("feedback.deviceInfo.note").foregroundStyle(.secondary)
        }
        .scaledFont(.detailMeta)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
      }
    }
  }

  @ViewBuilder private var routeNoteSection: some View {
    switch activeRoute {
    case .share(.noRecipient):
      Section { EmptyView() } footer: { Text("feedback.share.noRecipient") }
    case .share(.noMailAccount):
      Section { EmptyView() } footer: { Text("feedback.share.noMailAccount") }
    default:
      if model.saveFailed {
        Section { EmptyView() } footer: { Text("feedback.saveFailed") }
      }
    }
  }

  @ViewBuilder private var progressSection: some View {
    if case .uploading(let progress) = model.uploadState {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          Text("feedback.upload.progress")
          ProgressView(value: progress)
          Text(progress, format: .percent.precision(.fractionLength(0)))
            .scaledFont(.detailMeta)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
      }
    }
  }

  // MARK: Leiste

  @ToolbarContentBuilder private var toolbar: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button("feedback.close") { dismiss() }
    }
    ToolbarItem(placement: .primaryAction) {
      moreMenu
    }
    ToolbarItem(placement: .confirmationAction) {
      confirmationButton
    }
  }

  private var moreMenu: some View {
    Menu {
      Button {
        copyToPasteboard(model.copyText())
        announce(String(localized: "feedback.copied"))
      } label: {
        Label("feedback.copy", systemImage: "doc.on.doc")
      }
      Button(role: .destructive) {
        showDiscardConfirm = true
      } label: {
        Label("feedback.discard", systemImage: "trash")
      }
    } label: {
      Label("feedback.more", systemImage: "ellipsis.circle")
    }
  }

  @ViewBuilder private var confirmationButton: some View {
    switch activeRoute {
    case .upload, .mail:
      Button("feedback.send") { send() }
        .disabled(!model.draft.canSend || isUploading)
    case .share:
      shareButton
    }
  }

  @ViewBuilder private var shareButton: some View {
    let message = model.message
    if shareURLs.isEmpty {
      ShareLink(item: model.copyText()) { Text("feedback.share") }
        .disabled(!model.draft.canSend)
    } else {
      ShareLink(items: shareURLs, subject: Text(message.subject), message: Text(message.body)) {
        Text("feedback.share")
      }
      .disabled(!model.draft.canSend)
    }
  }

  // MARK: Zustimmung

  private var consentSheet: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if case .upload(let endpoint) = model.route {
            Text("feedback.consent.body \(endpoint.baseURL.host() ?? "")")
            Link("feedback.consent.privacy", destination: endpoint.privacyURL)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
      }
      .navigationTitle(Text("feedback.consent.title"))
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: 8) {
          Button {
            model.giveConsent()
            showConsent = false
            startUpload()
          } label: {
            Text("feedback.consent.agree").frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .buttonBorderShape(.capsule)

          Button {
            showConsent = false
            useFallback = true
          } label: {
            Text("feedback.consent.mailInstead").frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .buttonBorderShape(.capsule)
        }
        .controlSize(.large)
        .padding()
      }
    }
    .presentationDetents([.medium])
    .fontDesign(.rounded)
  }

  // MARK: Bildeditor

  private func openEditor(_ attachment: FeedbackAttachment) {
    guard let data = model.imageData(for: attachment.id) else { return }
    let editor = MarkupEditorModel(
      pixelSize: CGSize(width: attachment.pixelWidth, height: attachment.pixelHeight),
      drawing: model.markup(for: attachment.id) ?? PKDrawing(),
      redactions: attachment.redactions)
    editing = EditorTarget(id: attachment.id, imageData: data, model: editor)
  }

  @ViewBuilder private func editorContent(_ target: EditorTarget) -> some View {
    NavigationStack {
      MarkupEditorView(imageData: target.imageData, model: target.model) { result in
        model.updateMarkup(for: target.id, drawing: result.drawing, redactions: result.redactions)
        editing = nil
      }
    }
    #if os(macOS)
      .frame(minWidth: 720, minHeight: 540)
    #endif
  }

  // MARK: Aktionen

  private func send() {
    switch activeRoute {
    case .upload:
      if model.needsConsent { showConsent = true } else { startUpload() }
    case .mail(let recipient):
      openMail(recipient: recipient)
    case .share:
      break
    }
  }

  private func startUpload() {
    Task { await model.upload() }
  }

  private func retry() {
    model.resetUploadState()
    startUpload()
  }

  private func openMail(recipient: String) {
    #if os(iOS)
      mailRequest = MailRequest(recipient: recipient, attachments: model.flattenedAttachments())
    #else
      do {
        let urls = try model.shareFiles()
        let opened = macComposer.compose(recipient: recipient, message: model.message, fileURLs: urls) {
          handedOver in
          if handedOver { completeHandover() }
        }
        if !opened { showFailed = true }
      } catch {
        showFailed = true
      }
    #endif
  }

  /// Mail abgegeben: Entwurf weg, Hinweis, Blatt zu.
  private func completeHandover() {
    model.didSend()
    announce(String(localized: "feedback.sent"))
    dismiss()
  }

  private func uploadStateChanged(_ state: FeedbackUploadState) {
    switch state {
    case .sent(let reference):
      sentReference = reference
      announce(String(localized: "feedback.sent"))
      showSent = true
    case .failed:
      showFailed = true
    case .idle, .uploading:
      break
    }
  }

  private func loadPhotos(_ items: [PhotosPickerItem]) {
    guard !items.isEmpty else { return }
    // Ein Auftrag lädt der Reihe nach; erst danach wird die Auswahl geleert (eine Kette, keine wartenden Tasks).
    Task {
      var datas: [Data] = []
      for item in items {
        if let data = try? await item.loadTransferable(type: Data.self) { datas.append(data) }
      }
      model.addPhotos(datas)
      photoSelection = []
    }
  }

  private func refreshShareFiles() {
    guard case .share = activeRoute, !model.draft.attachments.isEmpty else {
      shareURLs = []
      return
    }
    shareURLs = (try? model.shareFiles()) ?? []
  }

  // MARK: Hilfen

  private func isRejected(_ error: FeedbackUploadError) -> Bool {
    if case .rejected = error { return true }
    return false
  }

  private func reason(_ error: FeedbackUploadError) -> LocalizedStringKey {
    switch error {
    case .rateLimited: "feedback.upload.rateLimited"
    case .rejected: "feedback.upload.rejected"
    case .unavailable, .invalidResponse: "feedback.upload.unavailable"
    }
  }

  private func announce(_ text: String) {
    AccessibilityNotification.Announcement(text).post()
  }

  private func copyToPasteboard(_ text: String) {
    #if os(iOS)
      UIPasteboard.general.string = text
    #else
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(text, forType: .string)
    #endif
  }
}
