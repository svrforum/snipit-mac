import AppKit
import SwiftUI

func debugLog(_ msg: String) {
    #if DEBUG
    fputs("[SnipIt] \(msg)\n", stderr)
    #endif
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct SnipItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
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
                .environment(appState)
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

    // MARK: - Overlay (strong ref to prevent dealloc during capture)

    private var activeOverlay: CaptureOverlayWindow?

    // MARK: - Editor Window

    private var editorWindow: NSWindow?

    // MARK: - State

    var shouldOpenSettings = false

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
        DispatchQueue.main.async { [self] in
            applyTheme()
            checkFirstLaunch()
        }
    }

    // MARK: - First Launch

    private func checkFirstLaunch() {
        guard !hasCompletedOnboarding else { return }
        NSApp.activate(ignoringOtherApps: true)
        shouldOpenSettings = true
        hasCompletedOnboarding = true
    }

    // MARK: - Theme

    func applyTheme() {
        guard let app = NSApp else { return }
        switch settingsVM.settings.theme {
        case .system:
            app.appearance = nil
        case .dark:
            app.appearance = NSAppearance(named: .darkAqua)
        case .light:
            app.appearance = NSAppearance(named: .aqua)
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

    // MARK: - Capture

    func showCaptureOverlay(mode: CaptureMode = .region) {
        switch mode {
        case .fullScreen:
            Task { @MainActor in
                await captureVM.captureFullScreen()
                if settingsVM.settings.openEditorAfterCapture { openEditor() }
            }

        case .region, .window, .scroll:
            let overlay = CaptureOverlayWindow(
                captureVM: captureVM,
                dimmingOpacity: settingsVM.settings.dimmingOpacity
            )
            activeOverlay = overlay

            Task { @MainActor in
                let result = await overlay.show()
                activeOverlay = nil

                guard let result else { return }

                switch result {
                case .fullScreen:
                    await captureVM.captureFullScreen()
                case .window(let window):
                    await captureVM.captureWindow(window)
                case .region(let display, let rect):
                    await captureVM.captureRegion(display: display, rect: rect)
                }

                if settingsVM.settings.openEditorAfterCapture { openEditor() }
            }
        }
    }

    func openEditor() {
        openEditor(with: captureVM.capturedImage)
    }

    func openEditor(with image: NSImage?) {
        guard let image else { return }

        let vm = EditorViewModel(image: image)
        let editorView = EditorWindow(
            viewModel: vm,
            historyVM: historyVM,
            onOpenImage: { [weak self] img in
                self?.captureVM.capturedImage = img
                self?.openEditor(with: img)
            },
            onSaveToHistory: { [weak self] editedImage in
                guard let self else { return }
                Task {
                    try? await self.historyService.addCapture(
                        image: editedImage,
                        mode: .region
                    )
                }
            }
        )
        let hostingView = NSHostingView(rootView: editorView)

        if let existingWindow = editorWindow, existingWindow.isVisible {
            // Reuse window — only swap content, keep size & position
            existingWindow.contentView = hostingView
            existingWindow.makeKeyAndOrderFront(nil)
        } else {
            // First time — set a fixed comfortable size
            let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
            let w = min(screen.width * 0.75, 1100)
            let h = min(screen.height * 0.8, 780)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "SnipIt 편집기"
            window.contentView = hostingView
            window.center()
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            editorWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Recording

    private var recordingBorder = RecordingBorderWindow()
    private var countdownWindow: NSWindow?
    private var recordingControlWindow: NSWindow?
    private var recordingControlState: RecordingControlState?

    func toggleRecording(mode: RecordingMode) {
        debugLog("toggleRecording mode=\(mode.rawValue) isRecording=\(recordingVM.isRecording)")
        if recordingVM.isRecording {
            Task { @MainActor in
                recordingBorder.hide()
                hideRecordingControl()
                await recordingVM.stopRecording()
                // Show result in Finder
                if let url = recordingVM.outputURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        } else {
            // Show region selection overlay, then countdown, then record
            let overlay = CaptureOverlayWindow(
                captureVM: captureVM,
                dimmingOpacity: settingsVM.settings.dimmingOpacity
            )
            activeOverlay = overlay

            Task { @MainActor in
                let result = await overlay.show()
                activeOverlay = nil

                guard let result else { return }

                let captureService = ScreenCaptureService()
                do {
                    let content = try await captureService.getAvailableContent()
                    guard let display = content.displays.first else { return }

                    let region: CGRect
                    switch result {
                    case .fullScreen:
                        region = CGRect(x: 0, y: 0, width: CGFloat(display.width), height: CGFloat(display.height))
                    case .region(_, let rect):
                        region = rect
                    case .window(let window):
                        region = window.frame
                    }

                    // Show countdown 3, 2, 1
                    if settingsVM.settings.showCountdown {
                        await showCountdown()
                    }

                    // Show recording border
                    recordingBorder.show(around: region)

                    // Set up progress callback BEFORE starting
                    recordingVM.recordingService.onProgress = { [weak self] dur, frames in
                        DispatchQueue.main.async {
                            self?.recordingVM.duration = dur
                            self?.recordingVM.frameCount = frames
                            self?.recordingControlState?.duration = dur
                            self?.recordingControlState?.frameCount = frames
                        }
                    }

                    // Show floating stop control
                    showRecordingControl(below: region)

                    // Start recording
                    await recordingVM.startRecording(
                        mode: mode,
                        region: region,
                        display: display,
                        settings: settingsVM.settings
                    )
                } catch {
                    debugLog("Recording error: \(error)")
                }
            }
        }
    }

    @MainActor
    private func showCountdown() async {
        for count in (1...3).reversed() {
            let label = NSTextField(labelWithString: "\(count)")
            label.font = .systemFont(ofSize: 72, weight: .bold)
            label.textColor = .white
            label.alignment = .center
            label.sizeToFit()

            let size: CGFloat = 120
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false

            let bg = NSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
            bg.wantsLayer = true
            bg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
            bg.layer?.cornerRadius = 24

            label.frame = NSRect(x: 0, y: 20, width: size, height: size - 40)
            bg.addSubview(label)
            window.contentView = bg
            window.center()
            window.makeKeyAndOrderFront(nil)

            countdownWindow = window

            try? await Task.sleep(for: .seconds(1))

            window.orderOut(nil)
        }
        countdownWindow = nil
    }

    @MainActor
    private func showRecordingControl(below region: CGRect) {
        let state = RecordingControlState()
        state.onStop = { [weak self] in
            self?.toggleRecording(mode: self?.recordingVM.recordingMode ?? .gif)
        }
        state.onCancel = { [weak self] in
            guard let self else { return }
            self.recordingBorder.hide()
            self.hideRecordingControl()
            self.recordingVM.cancelRecording()
        }
        self.recordingControlState = state

        let controlView = RecordingControlView(state: state)
        let hostingView = NSHostingView(rootView: controlView)
        let controlW: CGFloat = 360
        let controlH: CGFloat = 56
        hostingView.frame = NSRect(x: 0, y: 0, width: controlW, height: controlH)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: controlW, height: controlH),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar + 1
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.contentView = hostingView

        if let screen = NSScreen.main {
            let x = (screen.frame.width - controlW) / 2
            window.setFrameOrigin(NSPoint(x: x, y: 60))
        }

        window.makeKeyAndOrderFront(nil)
        recordingControlWindow = window
    }

    @MainActor
    private func hideRecordingControl() {
        recordingControlWindow?.orderOut(nil)
        recordingControlWindow = nil
        recordingControlState = nil
    }
}
