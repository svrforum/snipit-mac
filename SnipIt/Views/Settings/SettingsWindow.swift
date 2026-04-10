import SwiftUI

struct SettingsWindow: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            GeneralSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("일반", systemImage: "gear")
                }

            CaptureSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("캡처", systemImage: "camera")
                }

            RecordingSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("녹화", systemImage: "record.circle")
                }

            HotkeySettingsView(viewModel: viewModel)
                .tabItem {
                    Label("단축키", systemImage: "keyboard")
                }

            StorageSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("저장", systemImage: "folder")
                }

            ThemeSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("테마", systemImage: "paintbrush")
                }

            AboutSettingsView()
                .tabItem {
                    Label("정보", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 380)
    }
}
