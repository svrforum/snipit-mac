import Carbon.HIToolbox
import SwiftUI

struct HotkeySettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    @State private var recordingBinding: HotkeyBinding?

    var body: some View {
        Form {
            Section {
                hotkeyRow(
                    label: "전체 화면 캡처",
                    binding: .fullScreen
                )
                hotkeyRow(
                    label: "영역 선택 캡처",
                    binding: .region
                )
                hotkeyRow(
                    label: "활성 창 캡처",
                    binding: .window
                )
                hotkeyRow(
                    label: "스크롤 캡처",
                    binding: .scroll
                )
            } header: {
                Text("캡처")
            }

            Section {
                hotkeyRow(
                    label: "GIF 녹화",
                    binding: .gif
                )
                hotkeyRow(
                    label: "MP4 녹화",
                    binding: .mp4
                )
            } header: {
                Text("녹화")
            }

            Section {
                Button("기본값으로 복원") {
                    viewModel.settings.hotkeyFullScreen = .fullScreenCapture
                    viewModel.settings.hotkeyRegion = .regionCapture
                    viewModel.settings.hotkeyWindow = .windowCapture
                    viewModel.settings.hotkeyScroll = .scrollCapture
                    viewModel.settings.hotkeyGif = .gifRecording
                    viewModel.settings.hotkeyMp4 = .mp4Recording
                    viewModel.save()
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Hotkey Binding Enum

    private enum HotkeyBinding: Equatable {
        case fullScreen, region, window, scroll, gif, mp4
    }

    private func config(for binding: HotkeyBinding) -> HotkeyConfig {
        switch binding {
        case .fullScreen: viewModel.settings.hotkeyFullScreen
        case .region: viewModel.settings.hotkeyRegion
        case .window: viewModel.settings.hotkeyWindow
        case .scroll: viewModel.settings.hotkeyScroll
        case .gif: viewModel.settings.hotkeyGif
        case .mp4: viewModel.settings.hotkeyMp4
        }
    }

    private func setConfig(_ config: HotkeyConfig, for binding: HotkeyBinding) {
        switch binding {
        case .fullScreen: viewModel.settings.hotkeyFullScreen = config
        case .region: viewModel.settings.hotkeyRegion = config
        case .window: viewModel.settings.hotkeyWindow = config
        case .scroll: viewModel.settings.hotkeyScroll = config
        case .gif: viewModel.settings.hotkeyGif = config
        case .mp4: viewModel.settings.hotkeyMp4 = config
        }
        viewModel.save()
    }

    // MARK: - Hotkey Row

    private func hotkeyRow(label: String, binding: HotkeyBinding) -> some View {
        HStack {
            Text(label)
            Spacer()

            if recordingBinding == binding {
                HotkeyRecorderButton(
                    isRecording: true,
                    displayText: "키 입력 대기중..."
                ) {
                    recordingBinding = nil
                } onKeyCapture: { keyCode, modifiers in
                    setConfig(HotkeyConfig(keyCode: keyCode, modifiers: modifiers), for: binding)
                    recordingBinding = nil
                }
            } else {
                let cfg = config(for: binding)
                Button {
                    recordingBinding = binding
                } label: {
                    Text(KeyCodeMapping.displayString(
                        keyCode: cfg.keyCode,
                        modifiers: cfg.modifiers
                    ))
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - HotkeyRecorderButton

struct HotkeyRecorderButton: NSViewRepresentable {
    let isRecording: Bool
    let displayText: String
    let onCancel: () -> Void
    let onKeyCapture: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onCancel = onCancel
        view.onKeyCapture = onKeyCapture
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.onCancel = onCancel
        nsView.onKeyCapture = onKeyCapture
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class HotkeyRecorderNSView: NSView {
    var onCancel: (() -> Void)?
    var onKeyCapture: ((UInt32, UInt32) -> Void)?

    private let label = NSTextField(labelWithString: "키 입력 대기중...")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemOrange
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let keyCode = UInt32(event.keyCode)

        // ESC cancels
        if keyCode == 53 {
            onCancel?()
            return
        }

        // Require at least one modifier (cmd/ctrl/opt/shift)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.isEmpty else { return }

        var carbonMods: UInt32 = 0
        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }

        // Only accept if there's a non-modifier key
        if KeyCodeMapping.codeToName[keyCode] != nil {
            onKeyCapture?(keyCode, carbonMods)
        }
    }
}
