import AppKit
import SwiftUI

struct ThemeSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Picker("테마", selection: $viewModel.settings.theme) {
                Text("시스템").tag(AppTheme.system)
                Text("다크").tag(AppTheme.dark)
                Text("라이트").tag(AppTheme.light)
            }
            .pickerStyle(.segmented)
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.settings) {
            viewModel.save()
        }
        .onChange(of: viewModel.settings.theme) {
            switch viewModel.settings.theme {
            case .system:
                NSApp.appearance = nil
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            }
        }
    }
}
