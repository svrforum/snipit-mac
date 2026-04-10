import AppKit
import SwiftUI

@main
struct SnipItApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(systemName: "scissors")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsWindow(viewModel: appState.settingsVM)
        }

        Window("editor", id: "editor") {
            if let image = appState.captureVM.capturedImage {
                EditorWindow(viewModel: EditorViewModel(image: image))
            } else {
                Text("이미지가 없습니다")
                    .frame(width: 400, height: 300)
            }
        }

        Window("history", id: "history") {
            HistoryView(viewModel: appState.historyVM)
                .frame(minWidth: 500, minHeight: 400)
        }

        Window("onboarding", id: "onboarding") {
            OnboardingView()
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - AppState

@Observable
final class AppState {

    // MARK: - Services

    let storageService: StorageService
    let permissionService: PermissionService
    let historyService: HistoryService
    let updateService = UpdateService()

    // MARK: - View Models

    let captureVM: CaptureViewModel
    let recordingVM: RecordingViewModel
    let settingsVM: SettingsViewModel
    let historyVM: HistoryViewModel

    // MARK: - Controllers

    let pinController = PinWindowController()

    // MARK: - State

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    // MARK: - Initialization

    init() {
        let storage = StorageService()
        try? storage.ensureDirectories()

        let permission = PermissionService()
        let history = HistoryService(storageService: storage)

        self.storageService = storage
        self.permissionService = permission
        self.historyService = history

        self.captureVM = CaptureViewModel(
            permissionService: permission,
            historyService: history,
            storageService: storage
        )
        self.recordingVM = RecordingViewModel(storageService: storage)
        self.settingsVM = SettingsViewModel(storageService: storage)
        self.historyVM = HistoryViewModel(historyService: history)

        registerHotkeys()
        applyTheme()
    }

    // MARK: - Theme

    func applyTheme() {
        switch settingsVM.settings.theme {
        case .system:
            NSApp.appearance = nil
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        }
    }

    // MARK: - Hotkey Registration

    private func registerHotkeys() {
        let handlers = HotkeyHandlers(
            fullScreen: { [weak self] in self?.showCaptureOverlay(mode: .fullScreen) },
            region: { [weak self] in self?.showCaptureOverlay(mode: .region) },
            window: { [weak self] in self?.showCaptureOverlay(mode: .window) },
            scroll: { [weak self] in self?.showCaptureOverlay(mode: .scroll) },
            gifRecord: { [weak self] in self?.toggleRecording(mode: .gif) },
            mp4Record: { [weak self] in self?.toggleRecording(mode: .mp4) }
        )

        HotkeyService.shared.reregister(
            settings: settingsVM.settings,
            handlers: handlers
        )
    }

    // MARK: - Capture Overlay

    func showCaptureOverlay(mode: CaptureMode = .region) {
        let overlay = CaptureOverlayWindow(
            captureVM: captureVM,
            dimmingOpacity: settingsVM.settings.dimmingOpacity
        )

        Task { @MainActor in
            guard let result = await overlay.show() else { return }

            switch result {
            case .fullScreen:
                await captureVM.captureFullScreen()

            case .window(let window):
                await captureVM.captureWindow(window)

            case .region(let display, let rect):
                await captureVM.captureRegion(display: display, rect: rect)
            }
        }
    }

    // MARK: - Recording

    func toggleRecording(mode: RecordingMode) {
        if recordingVM.isRecording {
            Task {
                await recordingVM.stopRecording()
            }
        } else {
            Task {
                // Recording requires a region and display — for now start full screen
                let captureService = ScreenCaptureService()
                do {
                    let content = try await captureService.getAvailableContent()
                    guard let display = content.displays.first else { return }
                    let region = CGRect(
                        x: 0,
                        y: 0,
                        width: CGFloat(display.width),
                        height: CGFloat(display.height)
                    )
                    await recordingVM.startRecording(
                        mode: mode,
                        region: region,
                        display: display,
                        settings: settingsVM.settings
                    )
                } catch {
                    // Permission or availability error
                }
            }
        }
    }
}
