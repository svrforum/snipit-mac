import AppKit
import Foundation
import ScreenCaptureKit

// MARK: - PermissionPanel

enum PermissionPanel: String {
    case screenRecording = "Privacy_ScreenCapture"
    case accessibility = "Privacy_Accessibility"
}

// MARK: - PermissionService

@Observable
final class PermissionService {

    // MARK: - Properties

    var hasScreenRecordingPermission: Bool = false
    var hasAccessibilityPermission: Bool = false

    // MARK: - Screen Recording

    func checkScreenRecordingPermission() async {
        hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
    }

    func requestScreenRecordingPermission() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
    }

    // MARK: - Accessibility

    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    }

    // MARK: - System Preferences

    func openSystemPreferences(for panel: PermissionPanel) {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?\(panel.rawValue)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
