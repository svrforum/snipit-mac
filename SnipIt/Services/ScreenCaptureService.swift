import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

// MARK: - CaptureError

enum CaptureError: Error, LocalizedError {
    case noDisplayFound
    case permissionDenied
    case regionInvalid

    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No display found for screen capture."
        case .permissionDenied:
            return "Screen recording permission has not been granted."
        case .regionInvalid:
            return "The specified capture region is invalid."
        }
    }
}

// MARK: - ScreenCaptureService

actor ScreenCaptureService {

    // MARK: - Full Screen Capture

    func captureFullScreen() async throws -> NSImage {
        let content = try await getAvailableContent()

        guard let display = content.displays.first else {
            throw CaptureError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let configuration = SCStreamConfiguration()
        configuration.width = Int(display.width) * 2
        configuration.height = Int(display.height) * 2
        configuration.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )

        return NSImage(cgImage: image, size: NSSize(width: display.width, height: display.height))
    }

    // MARK: - Window Capture

    func captureWindow(_ window: SCWindow) async throws -> NSImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)

        let configuration = SCStreamConfiguration()
        configuration.width = Int(window.frame.width) * 2
        configuration.height = Int(window.frame.height) * 2
        configuration.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )

        return NSImage(
            cgImage: image,
            size: NSSize(width: window.frame.width, height: window.frame.height)
        )
    }

    // MARK: - Region Capture

    func captureRegion(display: SCDisplay, rect: CGRect) async throws -> NSImage {
        guard rect.width > 0, rect.height > 0 else {
            throw CaptureError.regionInvalid
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let configuration = SCStreamConfiguration()
        configuration.sourceRect = rect
        configuration.width = Int(rect.width) * 2
        configuration.height = Int(rect.height) * 2
        configuration.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )

        return NSImage(cgImage: image, size: NSSize(width: rect.width, height: rect.height))
    }

    // MARK: - Available Content

    func getAvailableContent() async throws -> SCShareableContent {
        do {
            return try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            if (error as NSError).domain == "com.apple.ScreenCaptureKit"
                && (error as NSError).code == -3801
            {
                throw CaptureError.permissionDenied
            }
            throw error
        }
    }

    // MARK: - Window Detection

    func findWindow(at point: CGPoint) async throws -> SCWindow? {
        let content = try await getAvailableContent()

        guard let mainDisplay = content.displays.first else {
            throw CaptureError.noDisplayFound
        }

        // Flip Y coordinate: CGPoint screen coords use bottom-left origin,
        // but SCWindow frames use top-left origin (like Core Graphics display coords).
        let flippedY = CGFloat(mainDisplay.height) - point.y

        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.svrforum.SnipIt"

        return content.windows.first { window in
            guard window.isOnScreen else { return false }
            guard window.owningApplication?.bundleIdentifier != bundleIdentifier else {
                return false
            }
            return window.frame.contains(CGPoint(x: point.x, y: flippedY))
        }
    }
}
