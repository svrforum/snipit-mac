import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "scissors")
                    .foregroundStyle(.tint)
                Text("SnipIt")
                    .font(.headline)

                Spacer()

                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "gear")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Capture grid 2x2
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    captureButton(
                        title: "전체 화면",
                        icon: "rectangle.dashed",
                        shortcut: "⌃⌥A"
                    ) {
                        appState.showCaptureOverlay(mode: .fullScreen)
                    }

                    captureButton(
                        title: "영역 선택",
                        icon: "rectangle.dashed.badge.record",
                        shortcut: "⌘⇧C"
                    ) {
                        appState.showCaptureOverlay(mode: .region)
                    }
                }

                HStack(spacing: 2) {
                    captureButton(
                        title: "활성 창",
                        icon: "macwindow",
                        shortcut: "⌃⌥W"
                    ) {
                        appState.showCaptureOverlay(mode: .window)
                    }

                    captureButton(
                        title: "스크롤",
                        icon: "arrow.up.and.down.text.horizontal",
                        shortcut: "⌃⌥D"
                    ) {
                        appState.showCaptureOverlay(mode: .scroll)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            // Recording row 1x2
            HStack(spacing: 2) {
                captureButton(
                    title: "GIF 녹화",
                    icon: "record.circle",
                    shortcut: "⌃⌥G",
                    isActive: appState.recordingVM.isRecording && appState.recordingVM.recordingMode == .gif
                ) {
                    appState.toggleRecording(mode: .gif)
                }

                captureButton(
                    title: "MP4 녹화",
                    icon: "video",
                    shortcut: "⌃⌥V",
                    isActive: appState.recordingVM.isRecording && appState.recordingVM.recordingMode == .mp4
                ) {
                    appState.toggleRecording(mode: .mp4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            Divider()

            // Recent captures
            VStack(alignment: .leading, spacing: 6) {
                Text("최근 캡처")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                if appState.historyVM.items.isEmpty {
                    Text("캡처 내역 없음")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    HStack(spacing: 4) {
                        ForEach(appState.historyVM.items.prefix(4)) { item in
                            if let thumbnail = appState.historyVM.loadThumbnail(for: item) {
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 58, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        Spacer()
                    }
                }

                Button {
                    openWindow(id: "history")
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("전체보기")
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Footer
            Button {
                if let url = URL(string: "https://buymeacoffee.com/svrforum") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack {
                    Text("☕")
                    Text("후원하기")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.top, 8)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("종료")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
        .onAppear {
            if appState.shouldOpenSettings {
                appState.shouldOpenSettings = false
                openSettings()
            }
        }
    }

    // MARK: - Capture Button

    private func captureButton(
        title: String,
        icon: String,
        shortcut: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isActive ? Color.red : Color.accentColor)

                Text(title)
                    .font(.caption2)

                Text(shortcut)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.red.opacity(0.1) : Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}
