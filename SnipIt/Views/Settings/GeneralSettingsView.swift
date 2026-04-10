import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Toggle("로그인 시 자동 실행", isOn: Binding(
                get: { viewModel.settings.launchAtLogin },
                set: { viewModel.setLaunchAtLogin($0) }
            ))

            Toggle("캡처 사운드 재생", isOn: $viewModel.settings.playSound)

            Toggle("캡처 후 편집기 열기", isOn: $viewModel.settings.openEditorAfterCapture)

            Toggle("클립보드에 자동 복사", isOn: $viewModel.settings.autoCopyToClipboard)

            Picker("언어", selection: $viewModel.settings.language) {
                Text("시스템").tag("system")
                Text("한국어").tag("ko")
                Text("English").tag("en")
            }
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.settings) {
            viewModel.save()
        }
    }
}
