import SwiftUI

struct EditorWindow: View {
    @Bindable var viewModel: EditorViewModel
    var historyVM: HistoryViewModel?
    var onOpenImage: ((NSImage) -> Void)?
    var onSaveToHistory: ((NSImage) -> Void)?

    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIcon = "checkmark.circle"
    @State private var keyEventMonitor: Any?
    @State private var showHistory = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                // Main editor
                VStack(spacing: 0) {
                    // Canvas area
                    EditorCanvasView(viewModel: viewModel)
                        .padding(16)
                        .background(Color(nsColor: .controlBackgroundColor))

                    Divider()

                    // Drawing tools
                    FloatingToolbar(viewModel: viewModel)
                        .padding(.vertical, 6)

                    Divider()

                    // Action bar
                    ActionBar(
                        viewModel: viewModel,
                        onClose: closeEditor,
                        onPin: pinImage,
                        onOCR: performOCR,
                        onCopy: copyImage,
                        onSave: saveImage,
                        onDone: doneEditing
                    )
                }

                // History sidebar
                if showHistory, let historyVM {
                    Divider()
                    historySidebar(historyVM)
                }
            }

            // Toast overlay
            if showToast {
                ToastView(icon: toastIcon, message: toastMessage)
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            showTemporaryToast("클립보드에 복사됨", icon: "doc.on.doc")
            keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                guard !event.modifierFlags.contains(.command) else { return event }
                if let tool = EditorTool.fromKeyCode(event.keyCode) {
                    viewModel.currentTool = tool
                    return nil
                }
                if event.keyCode == 53 { // ESC
                    dismiss()
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = keyEventMonitor {
                NSEvent.removeMonitor(monitor)
                keyEventMonitor = nil
            }
        }
    }

    // MARK: - History Sidebar

    private func historySidebar(_ vm: HistoryViewModel) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("히스토리")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    withAnimation { showHistory = false }
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            if vm.items.isEmpty {
                VStack {
                    Spacer()
                    Text("캡처 내역 없음")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(vm.items) { item in
                            historyRow(item, vm: vm)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 180)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func historyRow(_ item: CaptureHistoryItem, vm: HistoryViewModel) -> some View {
        Button {
            if let image = vm.loadImage(for: item) {
                onOpenImage?(image)
            }
        } label: {
            HStack(spacing: 8) {
                // Thumbnail
                Group {
                    if let thumb = vm.loadThumbnail(for: item) {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(.quaternary)
                    }
                }
                .frame(width: 48, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(modeLabel(item.mode))
                        .font(.caption2)
                        .fontWeight(.medium)
                    Text("\(item.width)×\(item.height)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(item.timestamp, style: .relative)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(0.001))
        )
        .contextMenu {
            Button("편집기에서 열기") {
                if let image = vm.loadImage(for: item) {
                    onOpenImage?(image)
                }
            }
            Divider()
            Button("삭제", role: .destructive) {
                vm.delete(item)
            }
        }
    }

    private func modeLabel(_ mode: CaptureMode) -> String {
        switch mode {
        case .fullScreen: return "전체 화면"
        case .region: return "영역 선택"
        case .window: return "활성 창"
        case .scroll: return "스크롤"
        }
    }

    // MARK: - Actions

    private func closeEditor() {
        dismiss()
    }

    private func pinImage() {
        // TODO: Pin image to screen using PinWindowController
    }

    private func performOCR() {
        let ocrService = OCRService()
        Task {
            do {
                let result = try await ocrService.extractText(from: viewModel.image)
                if result.fullText.isEmpty {
                    await MainActor.run {
                        showTemporaryToast("텍스트를 찾을 수 없습니다", icon: "text.magnifyingglass")
                    }
                } else {
                    await MainActor.run {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(result.fullText, forType: .string)
                        showTemporaryToast("텍스트 복사됨 (\(result.lines.count)줄)", icon: "text.viewfinder")
                    }
                }
            } catch {
                await MainActor.run {
                    showTemporaryToast("OCR 실패", icon: "exclamationmark.triangle")
                }
            }
        }
    }

    private func copyImage() {
        let finalImage = viewModel.renderFinalImage()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([finalImage])
        showTemporaryToast("클립보드에 복사됨", icon: "doc.on.doc")
    }

    private func saveImage() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg, .pdf]
        panel.nameFieldStringValue = "SnipIt-\(formattedDate()).png"
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let finalImage = viewModel.renderFinalImage()

            guard let tiffData = finalImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else { return }

            let data: Data?
            switch url.pathExtension.lowercased() {
            case "jpg", "jpeg":
                data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
            case "pdf":
                data = finalImage.pdfRepresentation()
            default:
                data = bitmap.representation(using: .png, properties: [:])
            }

            if let data = data {
                try? data.write(to: url)
                showTemporaryToast("저장 완료", icon: "checkmark.circle")
            }
        }
    }

    private func doneEditing() {
        let finalImage = viewModel.renderFinalImage()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([finalImage])

        // Save edited image to history
        onSaveToHistory?(finalImage)

        showTemporaryToast("클립보드에 복사됨", icon: "doc.on.doc")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }

    // MARK: - Toast

    private func showTemporaryToast(_ message: String, icon: String = "checkmark.circle") {
        toastMessage = message
        toastIcon = icon

        withAnimation(.easeInOut(duration: 0.3)) {
            showToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showToast = false
            }
        }
    }

    // MARK: - Helpers

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - NSImage PDF Extension

private extension NSImage {
    func pdfRepresentation() -> Data? {
        guard let rep = NSBitmapImageRep(data: tiffRepresentation ?? Data()) else { return nil }
        let rect = NSRect(origin: .zero, size: size)

        let pdfData = NSMutableData()
        guard let context = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!,
                                      mediaBox: nil, nil) else { return nil }

        context.beginPDFPage(nil)
        context.draw(rep.cgImage!, in: rect)
        context.endPDFPage()
        context.closePDF()

        return pdfData as Data
    }
}
