import SwiftUI

struct EditorWindow: View {
    @Bindable var viewModel: EditorViewModel

    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIcon = "checkmark.circle"

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Canvas area with floating toolbar overlay
                EditorCanvasView(viewModel: viewModel)
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .overlay(alignment: .bottom) {
                        FloatingToolbar(viewModel: viewModel)
                            .padding(.bottom, 16)
                    }

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

            // Toast overlay
            if showToast {
                ToastView(icon: toastIcon, message: toastMessage)
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            showTemporaryToast("클립보드에 복사됨", icon: "doc.on.doc")
        }
    }

    // MARK: - Actions

    private func closeEditor() {
        dismiss()
    }

    private func pinImage() {
        // Pin functionality - to be implemented with pin window
    }

    private func performOCR() {
        // OCR functionality - to be implemented
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
        let pdfData = NSMutableData()
        guard let rep = NSBitmapImageRep(data: tiffRepresentation ?? Data()) else { return nil }
        let rect = NSRect(origin: .zero, size: size)

        let pdfRep = NSMutableData()
        guard let context = CGContext(consumer: CGDataConsumer(data: pdfRep as CFMutableData)!,
                                      mediaBox: nil, nil) else { return nil }
        _ = pdfData // suppress warning

        context.beginPDFPage(nil)
        context.draw(rep.cgImage!, in: rect)
        context.endPDFPage()
        context.closePDF()

        return pdfRep as Data
    }
}
