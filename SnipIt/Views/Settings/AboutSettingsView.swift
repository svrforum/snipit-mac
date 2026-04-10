import SwiftUI

struct AboutSettingsView: View {
    @Environment(AppState.self) private var appState

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        Form {
            // App info
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "scissors")
                        .font(.system(size: 36))
                        .foregroundStyle(.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("SnipIt")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("v\(appVersion) (\(buildNumber))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Links
            Section("링크") {
                Link(destination: URL(string: "https://github.com/svrforum/snipit-mac")!) {
                    Label("GitHub", systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/svrforum/snipit-mac/issues")!) {
                    Label("버그 리포트", systemImage: "ladybug")
                }
            }

            // Support
            Section("후원") {
                Link(destination: URL(string: "https://buymeacoffee.com/svrforum")!) {
                    HStack {
                        Text("☕")
                        Text("Buy Me a Coffee")
                    }
                }

                Text("SnipIt은 오픈소스 프로젝트입니다.\n후원은 개발을 지속하는 데 큰 힘이 됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // License
            Section {
                Text("MIT License © 2026 svrforum")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Update
            Section {
                Button("업데이트 확인") {
                    appState.updateService.checkForUpdates()
                }
                .disabled(!appState.updateService.canCheckForUpdates)
            }
        }
        .formStyle(.grouped)
    }
}
