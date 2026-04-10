import SwiftUI

struct StorageSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            HStack {
                Text("저장 경로")
                Spacer()
                Text(viewModel.settings.savePath)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Button("변경") {
                    chooseSavePath()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                TextField("파일명 패턴", text: $viewModel.settings.fileNamePattern)

                Text("변수: {date} 날짜, {time} 시간, {mode} 캡처 모드")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.settings) {
            viewModel.save()
        }
    }

    // MARK: - Directory Chooser

    private func chooseSavePath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "선택"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.settings.savePath = url.path
            viewModel.save()
        }
    }
}
