import SwiftUI

struct ActionBar: View {
    @Bindable var viewModel: EditorViewModel

    var onClose: () -> Void = {}
    var onPin: () -> Void = {}
    var onOCR: () -> Void = {}
    var onCopy: () -> Void = {}
    var onSave: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some View {
        HStack {
            // Left group
            HStack(spacing: 8) {
                Button(action: onClose) {
                    Label("닫기", systemImage: "xmark")
                }
                .keyboardShortcut(.escape, modifiers: [])
                .help("닫기 (ESC)")

                Divider()
                    .frame(height: 20)

                Button(action: { viewModel.undo() }) {
                    Label("실행 취소", systemImage: "arrow.uturn.backward")
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!viewModel.canUndo)
                .help("실행 취소 (⌘Z)")

                Button(action: { viewModel.redo() }) {
                    Label("다시 실행", systemImage: "arrow.uturn.forward")
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!viewModel.canRedo)
                .help("다시 실행 (⌘⇧Z)")
            }

            Spacer()

            // Right group
            HStack(spacing: 8) {
                Button(action: onPin) {
                    Label("고정", systemImage: "pin")
                }
                .help("화면 고정")

                Button(action: onOCR) {
                    Label("OCR", systemImage: "text.viewfinder")
                }
                .help("텍스트 인식")

                Divider()
                    .frame(height: 20)

                Button(action: onCopy) {
                    Label("복사", systemImage: "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: .command)
                .help("클립보드에 복사 (⌘C)")

                Button(action: onSave) {
                    Label("저장", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .help("파일로 저장 (⌘S)")

                // Done button (blue pill)
                Button(action: onDone) {
                    Text("완료")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
                .help("완료 (⌘⏎)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .buttonStyle(.borderless)
    }
}
