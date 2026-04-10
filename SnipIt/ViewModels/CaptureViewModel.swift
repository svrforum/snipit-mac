import AppKit
import ScreenCaptureKit
import SwiftUI

@Observable
final class CaptureViewModel {

    // MARK: - Dependencies

    private let captureService = ScreenCaptureService()
    private let permissionService: PermissionService
    private let historyService: HistoryService
    private let storageService: StorageService

    // MARK: - State

    var capturedImage: NSImage?
    var isCapturing = false
    var showEditor = false
    var errorMessage: String?

    private var _cachedSettings: AppSettings?
    private var settings: AppSettings {
        if let cached = _cachedSettings { return cached }
        let s = (try? storageService.loadSettings()) ?? AppSettings()
        _cachedSettings = s
        return s
    }

    // MARK: - Initialization

    init(
        permissionService: PermissionService,
        historyService: HistoryService,
        storageService: StorageService
    ) {
        self.permissionService = permissionService
        self.historyService = historyService
        self.storageService = storageService
    }

    // MARK: - Public Capture Methods

    func captureFullScreen() async {
        await performCapture(mode: .fullScreen) {
            try await self.captureService.captureFullScreen()
        }
    }

    func captureWindow(_ window: SCWindow) async {
        await performCapture(mode: .window) {
            try await self.captureService.captureWindow(window)
        }
    }

    func captureRegion(display: SCDisplay, rect: CGRect) async {
        await performCapture(mode: .region) {
            try await self.captureService.captureRegion(display: display, rect: rect)
        }
    }

    // MARK: - Clipboard

    func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    // MARK: - Save

    func saveImage(_ image: NSImage, format: ImageFormat? = nil) throws -> URL {
        let resolvedFormat = format ?? settings.defaultImageFormat
        return try storageService.saveImage(image, format: resolvedFormat)
    }

    // MARK: - Private

    private func performCapture(
        mode: CaptureMode,
        capture: () async throws -> NSImage
    ) async {
        isCapturing = true
        defer { isCapturing = false }

        do {
            let image = try await capture()
            capturedImage = image

            let currentSettings = settings

            if currentSettings.autoCopyToClipboard {
                copyToClipboard(image)
            }

            if currentSettings.playSound {
                NSSound(named: "Tink")?.play()
            }

            try await historyService.addCapture(image: image, mode: mode)

            if currentSettings.openEditorAfterCapture {
                showEditor = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
