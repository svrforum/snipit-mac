import SwiftUI

struct HotkeySettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            hotkeyRow(
                label: "전체 화면 캡처",
                config: viewModel.settings.hotkeyFullScreen
            )
            hotkeyRow(
                label: "영역 선택 캡처",
                config: viewModel.settings.hotkeyRegion
            )
            hotkeyRow(
                label: "활성 창 캡처",
                config: viewModel.settings.hotkeyWindow
            )
            hotkeyRow(
                label: "스크롤 캡처",
                config: viewModel.settings.hotkeyScroll
            )
            hotkeyRow(
                label: "GIF 녹화",
                config: viewModel.settings.hotkeyGif
            )
            hotkeyRow(
                label: "MP4 녹화",
                config: viewModel.settings.hotkeyMp4
            )
        }
        .formStyle(.grouped)
    }

    // MARK: - Hotkey Row

    private func hotkeyRow(label: String, config: HotkeyConfig) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(KeyCodeMapping.displayString(
                keyCode: config.keyCode,
                modifiers: config.modifiers
            ))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .font(.system(.body, design: .monospaced))
        }
    }
}
