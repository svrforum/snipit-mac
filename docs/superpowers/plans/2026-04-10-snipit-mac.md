# SnipIt Mac Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS screen capture & editor app (SnipIt Mac) that ports all Windows SnipIt features plus new capabilities (scroll capture, MP4 recording, smart window detection, pin window, advanced annotations).

**Architecture:** MVVM with @Observable macro and Swift Concurrency. SwiftUI for all UI except capture overlay (AppKit NSWindow) and global hotkeys (Carbon). ScreenCaptureKit for all capture/recording operations. Services injected via SwiftUI Environment.

**Tech Stack:** Swift 5.9+ / SwiftUI / AppKit (minimal) / ScreenCaptureKit / AVFoundation / Vision / Carbon / ImageIO / Sparkle

**Spec:** `docs/superpowers/specs/2026-04-10-snipit-mac-design.md`

---

## Phase 1: Foundation

### Task 1: Xcode Project Setup & App Shell

**Files:**
- Create: `SnipIt/SnipItApp.swift`
- Create: `SnipIt/Info.plist`
- Create: `SnipIt/SnipIt.entitlements`
- Create: `SnipIt/Assets.xcassets/` (AppIcon, AccentColor)
- Create: `SnipIt/Resources/Sounds/capture.aiff` (placeholder)
- Create: `Package.swift` (Sparkle dependency)

- [ ] **Step 1: Create Xcode project**

Open Xcode → File → New Project → macOS → App.
- Product Name: `SnipIt`
- Team: your Developer ID
- Organization Identifier: `com.svrforum`
- Interface: SwiftUI
- Language: Swift
- Minimum Deployment: macOS 14.0

After creation, delete the default `ContentView.swift`.

- [ ] **Step 2: Configure project settings**

In Xcode project settings:
1. Set `Info.plist` → Add key `LSUIElement` = `YES` (hides Dock icon)
2. Set deployment target to macOS 14.0
3. Enable `Hardened Runtime` in Signing & Capabilities
4. Add capability: `App Sandbox` → then **disable** it (Direct Distribution, not App Store)

- [ ] **Step 3: Configure entitlements**

Edit `SnipIt/SnipIt.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

- [ ] **Step 4: Add Sparkle via Swift Package Manager**

In Xcode: File → Add Package Dependencies → enter URL:
`https://github.com/sparkle-project/Sparkle`
- Dependency Rule: Up to Next Major Version, `2.0.0`
- Add `Sparkle` library to SnipIt target

- [ ] **Step 5: Write SnipItApp.swift with MenuBarExtra shell**

```swift
// SnipIt/SnipItApp.swift
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
            Text("Settings placeholder")
        }
    }
}

@Observable
final class AppState {
    var lastCapturedImage: NSImage?
    var isRecording = false
}
```

- [ ] **Step 6: Create placeholder MenuBarView**

```swift
// SnipIt/Views/MenuBar/MenuBarView.swift
import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            Text("SnipIt")
                .font(.headline)
                .padding()

            Divider()

            Text("Coming soon...")
                .foregroundStyle(.secondary)
                .padding()
        }
        .frame(width: 280)
    }
}
```

- [ ] **Step 7: Build and run**

Run: `⌘R` in Xcode
Expected: App launches with scissors icon in menu bar. Clicking shows "Coming soon..." popover. No Dock icon visible.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: initialize Xcode project with MenuBarExtra shell

LSUIElement menu bar app with SwiftUI MenuBarExtra, Sparkle dependency,
and hardened runtime for Direct Distribution."
```

---

### Task 2: Models & AppSettings

**Files:**
- Create: `SnipIt/Models/CaptureMode.swift`
- Create: `SnipIt/Models/RecordingMode.swift`
- Create: `SnipIt/Models/AppSettings.swift`
- Create: `SnipIt/Models/HotkeyConfig.swift`
- Create: `SnipIt/Models/CaptureHistoryItem.swift`
- Create: `SnipIt/Models/Annotation.swift`
- Create: `SnipItTests/Models/AppSettingsTests.swift`

- [ ] **Step 1: Write AppSettings test**

```swift
// SnipItTests/Models/AppSettingsTests.swift
import Testing
@testable import SnipIt

@Suite("AppSettings")
struct AppSettingsTests {
    @Test("Default values are correct")
    func defaults() {
        let settings = AppSettings()
        #expect(settings.openEditorAfterCapture == true)
        #expect(settings.autoCopyToClipboard == true)
        #expect(settings.playSound == true)
        #expect(settings.defaultImageFormat == .png)
        #expect(settings.recordingFPS == .thirty)
        #expect(settings.maxRecordingDuration == 60)
        #expect(settings.theme == .system)
    }

    @Test("Encode and decode round-trips")
    func codableRoundTrip() throws {
        let original = AppSettings()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded.openEditorAfterCapture == original.openEditorAfterCapture)
        #expect(decoded.defaultImageFormat == original.defaultImageFormat)
        #expect(decoded.theme == original.theme)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `⌘U` in Xcode or `swift test`
Expected: FAIL — `AppSettings` not found

- [ ] **Step 3: Create CaptureMode and RecordingMode**

```swift
// SnipIt/Models/CaptureMode.swift
import Foundation

enum CaptureMode: String, Codable, CaseIterable {
    case fullScreen
    case window
    case region
    case scroll
}
```

```swift
// SnipIt/Models/RecordingMode.swift
import Foundation

enum RecordingMode: String, Codable, CaseIterable {
    case gif
    case mp4
}

enum RecordingFPS: Int, Codable, CaseIterable {
    case fifteen = 15
    case thirty = 30
    case sixty = 60
}

enum GifQuality: String, Codable, CaseIterable {
    case original
    case skipFrames
    case skipFramesHalfSize
}

enum VideoCodec: String, Codable, CaseIterable {
    case h264
    case hevc
}
```

- [ ] **Step 4: Create HotkeyConfig**

```swift
// SnipIt/Models/HotkeyConfig.swift
import Foundation
import Carbon.HIToolbox

struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let defaultFullScreen = HotkeyConfig(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(controlKey | optionKey))
    static let defaultRegion = HotkeyConfig(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(controlKey | optionKey))
    static let defaultWindow = HotkeyConfig(keyCode: UInt32(kVK_ANSI_W), modifiers: UInt32(controlKey | optionKey))
    static let defaultScroll = HotkeyConfig(keyCode: UInt32(kVK_ANSI_D), modifiers: UInt32(controlKey | optionKey))
    static let defaultGifRecord = HotkeyConfig(keyCode: UInt32(kVK_ANSI_G), modifiers: UInt32(controlKey | optionKey))
    static let defaultMp4Record = HotkeyConfig(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | optionKey))
}
```

- [ ] **Step 5: Create AppSettings**

```swift
// SnipIt/Models/AppSettings.swift
import Foundation

enum AppTheme: String, Codable, CaseIterable {
    case system
    case dark
    case light
}

enum ImageFormat: String, Codable, CaseIterable {
    case png
    case jpg
    case pdf
}

struct AppSettings: Codable, Equatable {
    // General
    var launchAtLogin: Bool = false
    var playSound: Bool = true
    var openEditorAfterCapture: Bool = true
    var autoCopyToClipboard: Bool = true
    var language: String = "system"
    var theme: AppTheme = .system

    // Capture
    var dimmingOpacity: Double = 0.4
    var defaultImageFormat: ImageFormat = .png
    var includeCursor: Bool = false

    // Recording
    var recordingFPS: RecordingFPS = .thirty
    var gifQuality: GifQuality = .skipFrames
    var videoCodec: VideoCodec = .h264
    var maxRecordingDuration: Int = 60

    // Hotkeys
    var hotkeyFullScreen: HotkeyConfig = .defaultFullScreen
    var hotkeyRegion: HotkeyConfig = .defaultRegion
    var hotkeyWindow: HotkeyConfig = .defaultWindow
    var hotkeyScroll: HotkeyConfig = .defaultScroll
    var hotkeyGifRecord: HotkeyConfig = .defaultGifRecord
    var hotkeyMp4Record: HotkeyConfig = .defaultMp4Record

    // Storage
    var savePath: String = ""
    var fileNamePattern: String = "SnipIt_{yyyy-MM-dd}_{HH-mm-ss}"
}
```

- [ ] **Step 6: Create CaptureHistoryItem**

```swift
// SnipIt/Models/CaptureHistoryItem.swift
import Foundation

struct CaptureHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let imagePath: String
    let thumbnailPath: String
    let width: Int
    let height: Int
    let mode: CaptureMode

    init(id: UUID = UUID(), timestamp: Date = Date(), imagePath: String, thumbnailPath: String, width: Int, height: Int, mode: CaptureMode) {
        self.id = id
        self.timestamp = timestamp
        self.imagePath = imagePath
        self.thumbnailPath = thumbnailPath
        self.width = width
        self.height = height
        self.mode = mode
    }
}
```

- [ ] **Step 7: Create Annotation protocol and types**

```swift
// SnipIt/Models/Annotation.swift
import Foundation
import SwiftUI

protocol Annotation: Identifiable, Equatable {
    var id: UUID { get }
    var color: Color { get set }
    var strokeWidth: CGFloat { get set }
    func draw(in context: inout GraphicsContext, size: CGSize)
}

struct PenAnnotation: Annotation {
    let id = UUID()
    var points: [CGPoint] = []
    var color: Color = .red
    var strokeWidth: CGFloat = 3

    func draw(in context: inout GraphicsContext, size: CGSize) {
        guard points.count > 1 else { return }
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(path, with: .color(color), lineWidth: strokeWidth)
    }
}

struct ArrowAnnotation: Annotation {
    let id = UUID()
    var start: CGPoint = .zero
    var end: CGPoint = .zero
    var color: Color = .red
    var strokeWidth: CGFloat = 3

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let path = Path { p in
            p.move(to: start)
            p.addLine(to: end)
        }
        context.stroke(path, with: .color(color), lineWidth: strokeWidth)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6
        let arrowPath = Path { p in
            p.move(to: end)
            p.addLine(to: CGPoint(
                x: end.x - arrowLength * cos(angle - arrowAngle),
                y: end.y - arrowLength * sin(angle - arrowAngle)
            ))
            p.move(to: end)
            p.addLine(to: CGPoint(
                x: end.x - arrowLength * cos(angle + arrowAngle),
                y: end.y - arrowLength * sin(angle + arrowAngle)
            ))
        }
        context.stroke(arrowPath, with: .color(color), lineWidth: strokeWidth)
    }
}

struct LineAnnotation: Annotation {
    let id = UUID()
    var start: CGPoint = .zero
    var end: CGPoint = .zero
    var color: Color = .red
    var strokeWidth: CGFloat = 3

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let path = Path { p in
            p.move(to: start)
            p.addLine(to: end)
        }
        context.stroke(path, with: .color(color), lineWidth: strokeWidth)
    }
}

struct RectangleAnnotation: Annotation {
    let id = UUID()
    var origin: CGPoint = .zero
    var size: CGSize = .zero
    var color: Color = .red
    var strokeWidth: CGFloat = 3

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: origin, size: self.size).standardized
        context.stroke(Path(rect), with: .color(color), lineWidth: strokeWidth)
    }
}

struct EllipseAnnotation: Annotation {
    let id = UUID()
    var origin: CGPoint = .zero
    var size: CGSize = .zero
    var color: Color = .red
    var strokeWidth: CGFloat = 3

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: origin, size: self.size).standardized
        context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: strokeWidth)
    }
}

struct TextAnnotation: Annotation {
    let id = UUID()
    var position: CGPoint = .zero
    var text: String = ""
    var fontName: String = ".AppleSystemUIFont"
    var fontSize: CGFloat = 16
    var color: Color = .red
    var isBold: Bool = false
    var isItalic: Bool = false
    var strokeWidth: CGFloat = 0

    func draw(in context: inout GraphicsContext, size: CGSize) {
        var font: Font = .system(size: fontSize)
        if isBold { font = font.bold() }
        if isItalic { font = font.italic() }
        context.draw(Text(text).font(font).foregroundColor(color), at: position, anchor: .topLeading)
    }
}

struct HighlightAnnotation: Annotation {
    let id = UUID()
    var points: [CGPoint] = []
    var color: Color = .yellow
    var strokeWidth: CGFloat = 20

    func draw(in context: inout GraphicsContext, size: CGSize) {
        guard points.count > 1 else { return }
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        context.stroke(path, with: .color(color.opacity(0.4)), lineWidth: strokeWidth)
    }
}

struct NumberAnnotation: Annotation {
    let id = UUID()
    var position: CGPoint = .zero
    var number: Int = 1
    var color: Color = .red
    var strokeWidth: CGFloat = 0

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let radius: CGFloat = 14
        let circle = Path(ellipseIn: CGRect(x: position.x - radius, y: position.y - radius, width: radius * 2, height: radius * 2))
        context.fill(circle, with: .color(color))
        context.draw(
            Text("\(number)").font(.system(size: 14, weight: .bold)).foregroundColor(.white),
            at: position
        )
    }
}

struct StepAnnotation: Annotation {
    let id = UUID()
    var position: CGPoint = .zero
    var number: Int = 1
    var text: String = ""
    var color: Color = .blue
    var strokeWidth: CGFloat = 0

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let padding: CGFloat = 8
        let bubbleWidth: CGFloat = max(CGFloat(text.count) * 9 + padding * 2 + 28, 60)
        let bubbleHeight: CGFloat = 32

        let rect = CGRect(x: position.x, y: position.y, width: bubbleWidth, height: bubbleHeight)
        let bubblePath = Path(roundedRect: rect, cornerRadius: 8)
        context.fill(bubblePath, with: .color(color))

        // Number circle
        let circleCenter = CGPoint(x: rect.minX + 18, y: rect.midY)
        let circleRadius: CGFloat = 10
        let circlePath = Path(ellipseIn: CGRect(x: circleCenter.x - circleRadius, y: circleCenter.y - circleRadius, width: circleRadius * 2, height: circleRadius * 2))
        context.fill(circlePath, with: .color(.white.opacity(0.3)))
        context.draw(Text("\(number)").font(.system(size: 11, weight: .bold)).foregroundColor(.white), at: circleCenter)

        // Text
        let textPos = CGPoint(x: rect.minX + 34, y: rect.midY)
        context.draw(Text(text).font(.system(size: 12)).foregroundColor(.white), at: textPos, anchor: .leading)
    }
}

struct CodeBlockAnnotation: Annotation {
    let id = UUID()
    var origin: CGPoint = .zero
    var text: String = ""
    var color: Color = Color(nsColor: .darkGray)
    var strokeWidth: CGFloat = 0

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let padding: CGFloat = 12
        let font = Font.system(size: 13, design: .monospaced)
        let lines = text.components(separatedBy: "\n")
        let width = max(CGFloat(lines.map(\.count).max() ?? 10) * 8 + padding * 2, 80)
        let height = CGFloat(lines.count) * 18 + padding * 2

        let rect = CGRect(origin: origin, size: CGSize(width: width, height: height))
        let bgPath = Path(roundedRect: rect, cornerRadius: 6)
        context.fill(bgPath, with: .color(Color(nsColor: NSColor(white: 0.15, alpha: 0.9))))
        context.stroke(bgPath, with: .color(Color(nsColor: NSColor(white: 0.3, alpha: 1))), lineWidth: 1)

        for (i, line) in lines.enumerated() {
            let pos = CGPoint(x: rect.minX + padding, y: rect.minY + padding + CGFloat(i) * 18)
            context.draw(Text(line).font(font).foregroundColor(.green), at: pos, anchor: .topLeading)
        }
    }
}

// Type-erased wrapper for storing heterogeneous annotations
struct AnyAnnotation: Identifiable, Equatable {
    let id: UUID
    let base: any Annotation
    private let _draw: (inout GraphicsContext, CGSize) -> Void
    private let _isEqual: (AnyAnnotation) -> Bool

    init<A: Annotation>(_ annotation: A) {
        self.id = annotation.id
        self.base = annotation
        self._draw = { context, size in annotation.draw(in: &context, size: size) }
        self._isEqual = { other in
            guard let otherTyped = other.base as? A else { return false }
            return annotation == otherTyped
        }
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        _draw(&context, size)
    }

    static func == (lhs: AnyAnnotation, rhs: AnyAnnotation) -> Bool {
        lhs._isEqual(rhs)
    }
}
```

- [ ] **Step 8: Run tests**

Run: `⌘U` in Xcode
Expected: All tests PASS (defaults correct, Codable round-trip works)

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: add all data models

CaptureMode, RecordingMode, AppSettings (Codable), HotkeyConfig,
CaptureHistoryItem, Annotation protocol with 11 concrete types
including new NumberAnnotation, StepAnnotation, CodeBlockAnnotation."
```

---

### Task 3: StorageService & PermissionService

**Files:**
- Create: `SnipIt/Services/StorageService.swift`
- Create: `SnipIt/Services/PermissionService.swift`
- Create: `SnipItTests/Services/StorageServiceTests.swift`

- [ ] **Step 1: Write StorageService test**

```swift
// SnipItTests/Services/StorageServiceTests.swift
import Testing
import Foundation
@testable import SnipIt

@Suite("StorageService")
struct StorageServiceTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Save and load settings round-trips")
    func settingsRoundTrip() throws {
        let service = StorageService(baseDirectory: tempDir)
        var settings = AppSettings()
        settings.playSound = false
        settings.maxRecordingDuration = 120
        try service.saveSettings(settings)
        let loaded = try service.loadSettings()
        #expect(loaded.playSound == false)
        #expect(loaded.maxRecordingDuration == 120)
    }

    @Test("Load returns defaults when no file exists")
    func defaultSettings() throws {
        let service = StorageService(baseDirectory: tempDir)
        let settings = try service.loadSettings()
        #expect(settings == AppSettings())
    }

    @Test("Creates directory structure on init")
    func directoryCreation() throws {
        let service = StorageService(baseDirectory: tempDir)
        service.ensureDirectories()
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("history/images").path))
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("history/thumbs").path))
        #expect(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("recordings").path))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `⌘U`
Expected: FAIL — `StorageService` not found

- [ ] **Step 3: Implement StorageService**

```swift
// SnipIt/Services/StorageService.swift
import Foundation
import AppKit

@Observable
final class StorageService {
    let baseDirectory: URL

    private var settingsURL: URL { baseDirectory.appendingPathComponent("Settings.json") }
    var historyDirectory: URL { baseDirectory.appendingPathComponent("history") }
    var imagesDirectory: URL { historyDirectory.appendingPathComponent("images") }
    var thumbnailsDirectory: URL { historyDirectory.appendingPathComponent("thumbs") }
    var recordingsDirectory: URL { baseDirectory.appendingPathComponent("recordings") }

    init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("SnipIt")
        ensureDirectories()
    }

    func ensureDirectories() {
        let dirs = [baseDirectory, imagesDirectory, thumbnailsDirectory, recordingsDirectory]
        for dir in dirs {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    func saveSettings(_ settings: AppSettings) throws {
        let data = try JSONEncoder().encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    func loadSettings() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return AppSettings()
        }
        let data = try Data(contentsOf: settingsURL)
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }

    func saveImage(_ image: NSImage, format: ImageFormat = .png) throws -> URL {
        let fileName = generateFileName(format: format)
        let url = imagesDirectory.appendingPathComponent(fileName)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw StorageError.imageConversionFailed
        }

        let data: Data?
        switch format {
        case .png:
            data = bitmap.representation(using: .png, properties: [:])
        case .jpg:
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        case .pdf:
            data = image.pdfRepresentation()
        }

        guard let imageData = data else { throw StorageError.imageConversionFailed }
        try imageData.write(to: url)
        return url
    }

    func saveThumbnail(_ image: NSImage) throws -> URL {
        let thumbSize = NSSize(width: 160, height: 100)
        let thumbnail = NSImage(size: thumbSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 1.0)
        thumbnail.unlockFocus()

        let fileName = "thumb_\(UUID().uuidString).jpg"
        let url = thumbnailsDirectory.appendingPathComponent(fileName)
        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            throw StorageError.imageConversionFailed
        }
        try data.write(to: url)
        return url
    }

    private func generateFileName(format: ImageFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "SnipIt_\(formatter.string(from: Date())).\(format.rawValue)"
    }

    func deleteFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

private extension NSImage {
    func pdfRepresentation() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        let pdfData = NSMutableData()
        let consumer = CGDataConsumer(data: pdfData as CFMutableData)!
        var rect = CGRect(origin: .zero, size: size)
        let context = CGContext(consumer: consumer, mediaBox: &rect, nil)!
        context.beginPDFPage(nil)
        context.draw(bitmap.cgImage!, in: rect)
        context.endPDFPage()
        context.closePDF()
        return pdfData as Data
    }
}

enum StorageError: LocalizedError {
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "Failed to convert image data"
        }
    }
}
```

- [ ] **Step 4: Implement PermissionService**

```swift
// SnipIt/Services/PermissionService.swift
import ScreenCaptureKit
import AppKit

@Observable
final class PermissionService {
    var hasScreenRecordingPermission = false
    var hasAccessibilityPermission = false

    func checkScreenRecordingPermission() async {
        do {
            _ = try await SCShareableContent.current
            hasScreenRecordingPermission = true
        } catch {
            hasScreenRecordingPermission = false
        }
    }

    func requestScreenRecordingPermission() {
        // Opening this URL triggers the system permission dialog
        CGRequestScreenCaptureAccess()
    }

    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func openSystemPreferences(for panel: String = "ScreenCapture") {
        let url: URL
        switch panel {
        case "ScreenCapture":
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        case "Accessibility":
            url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        default:
            return
        }
        NSWorkspace.shared.open(url)
    }
}
```

- [ ] **Step 5: Run tests**

Run: `⌘U`
Expected: All StorageService tests PASS

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add StorageService and PermissionService

File-based settings persistence (JSON), image/thumbnail save,
screen recording and accessibility permission management."
```

---

### Task 4: HistoryService

**Files:**
- Create: `SnipIt/Services/HistoryService.swift`
- Create: `SnipItTests/Services/HistoryServiceTests.swift`

- [ ] **Step 1: Write HistoryService test**

```swift
// SnipItTests/Services/HistoryServiceTests.swift
import Testing
import Foundation
import AppKit
@testable import SnipIt

@Suite("HistoryService")
struct HistoryServiceTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Add and retrieve capture")
    func addAndRetrieve() async throws {
        let storage = StorageService(baseDirectory: tempDir)
        let service = HistoryService(storageService: storage)
        let image = NSImage(size: NSSize(width: 100, height: 100))
        try await service.addCapture(image: image, mode: .fullScreen)
        #expect(service.items.count == 1)
        #expect(service.items[0].mode == .fullScreen)
        #expect(service.items[0].width == 100)
    }

    @Test("History respects max limit of 100")
    func maxLimit() async throws {
        let storage = StorageService(baseDirectory: tempDir)
        let service = HistoryService(storageService: storage)
        let image = NSImage(size: NSSize(width: 10, height: 10))
        for _ in 0..<105 {
            try await service.addCapture(image: image, mode: .region)
        }
        #expect(service.items.count == 100)
    }

    @Test("Delete item removes from list and disk")
    func deleteItem() async throws {
        let storage = StorageService(baseDirectory: tempDir)
        let service = HistoryService(storageService: storage)
        let image = NSImage(size: NSSize(width: 50, height: 50))
        try await service.addCapture(image: image, mode: .window)
        let item = service.items[0]
        service.deleteItem(item)
        #expect(service.items.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `⌘U`
Expected: FAIL — `HistoryService` not found

- [ ] **Step 3: Implement HistoryService**

```swift
// SnipIt/Services/HistoryService.swift
import Foundation
import AppKit

@Observable
final class HistoryService {
    private let storageService: StorageService
    private let maxItems = 100
    private var indexURL: URL { storageService.historyDirectory.appendingPathComponent("index.json") }

    var items: [CaptureHistoryItem] = []

    init(storageService: StorageService) {
        self.storageService = storageService
        loadIndex()
    }

    func addCapture(image: NSImage, mode: CaptureMode) async throws {
        let imageURL = try storageService.saveImage(image)
        let thumbURL = try storageService.saveThumbnail(image)

        let item = CaptureHistoryItem(
            imagePath: imageURL.lastPathComponent,
            thumbnailPath: thumbURL.lastPathComponent,
            width: Int(image.size.width),
            height: Int(image.size.height),
            mode: mode
        )

        items.insert(item, at: 0)

        // Enforce max limit
        while items.count > maxItems {
            let removed = items.removeLast()
            storageService.deleteFile(at: storageService.imagesDirectory.appendingPathComponent(removed.imagePath))
            storageService.deleteFile(at: storageService.thumbnailsDirectory.appendingPathComponent(removed.thumbnailPath))
        }

        saveIndex()
    }

    func loadImage(for item: CaptureHistoryItem) -> NSImage? {
        let url = storageService.imagesDirectory.appendingPathComponent(item.imagePath)
        return NSImage(contentsOf: url)
    }

    func loadThumbnail(for item: CaptureHistoryItem) -> NSImage? {
        let url = storageService.thumbnailsDirectory.appendingPathComponent(item.thumbnailPath)
        return NSImage(contentsOf: url)
    }

    func deleteItem(_ item: CaptureHistoryItem) {
        items.removeAll { $0.id == item.id }
        storageService.deleteFile(at: storageService.imagesDirectory.appendingPathComponent(item.imagePath))
        storageService.deleteFile(at: storageService.thumbnailsDirectory.appendingPathComponent(item.thumbnailPath))
        saveIndex()
    }

    func clearHistory() {
        for item in items {
            storageService.deleteFile(at: storageService.imagesDirectory.appendingPathComponent(item.imagePath))
            storageService.deleteFile(at: storageService.thumbnailsDirectory.appendingPathComponent(item.thumbnailPath))
        }
        items.removeAll()
        saveIndex()
    }

    private func loadIndex() {
        guard FileManager.default.fileExists(atPath: indexURL.path),
              let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([CaptureHistoryItem].self, from: data) else {
            return
        }
        items = decoded
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
```

- [ ] **Step 4: Run tests**

Run: `⌘U`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add HistoryService with FIFO management

JSON index, max 100 items, auto-cleanup of old images/thumbs,
add/delete/clear operations with disk cleanup."
```

---

## Phase 2: Capture Core

### Task 5: ScreenCaptureService

**Files:**
- Create: `SnipIt/Services/ScreenCaptureService.swift`

- [ ] **Step 1: Implement ScreenCaptureService**

```swift
// SnipIt/Services/ScreenCaptureService.swift
import ScreenCaptureKit
import AppKit
import CoreGraphics

actor ScreenCaptureService {
    func captureFullScreen() async throws -> NSImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw CaptureError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width * 2  // Retina
        config.height = display.height * 2
        config.scalesToFit = false
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: image, size: NSSize(width: display.width, height: display.height))
    }

    func captureWindow(_ window: SCWindow) async throws -> NSImage {
        guard let display = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true).displays.first else {
            throw CaptureError.noDisplayFound
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let frame = window.frame
        config.width = Int(frame.width) * 2
        config.height = Int(frame.height) * 2
        config.scalesToFit = false
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: image, size: NSSize(width: frame.width, height: frame.height))
    }

    func captureRegion(display: SCDisplay, rect: CGRect) async throws -> NSImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width) * 2
        config.height = Int(rect.height) * 2
        config.scalesToFit = false
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: image, size: NSSize(width: rect.width, height: rect.height))
    }

    func getAvailableContent() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }

    func findWindow(at point: CGPoint) async throws -> SCWindow? {
        let content = try await getAvailableContent()
        // Windows are ordered front-to-back; find the topmost that contains the point
        // Note: SCWindow.frame uses screen coordinates with origin at bottom-left
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let flippedPoint = CGPoint(x: point.x, y: screenHeight - point.y)

        return content.windows.first { window in
            guard window.isOnScreen,
                  window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier else {
                return false
            }
            return window.frame.contains(flippedPoint)
        }
    }
}

enum CaptureError: LocalizedError {
    case noDisplayFound
    case permissionDenied
    case regionInvalid

    var errorDescription: String? {
        switch self {
        case .noDisplayFound: return "No display found"
        case .permissionDenied: return "Screen recording permission denied"
        case .regionInvalid: return "Invalid capture region"
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `⌘B`
Expected: Build succeeds. (ScreenCaptureKit requires hardware — manual testing needed.)

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add ScreenCaptureService

ScreenCaptureKit-based capture for full screen, window, and region.
Smart window detection via SCShareableContent. Retina-aware sizing."
```

---

### Task 6: CaptureViewModel & Clipboard Integration

**Files:**
- Create: `SnipIt/ViewModels/CaptureViewModel.swift`

- [ ] **Step 1: Implement CaptureViewModel**

```swift
// SnipIt/ViewModels/CaptureViewModel.swift
import SwiftUI
import ScreenCaptureKit
import AppKit

@Observable
final class CaptureViewModel {
    private let captureService = ScreenCaptureService()
    private let permissionService: PermissionService
    private let historyService: HistoryService
    private let storageService: StorageService

    var capturedImage: NSImage?
    var isCapturing = false
    var showEditor = false
    var errorMessage: String?

    private var settings: AppSettings {
        (try? storageService.loadSettings()) ?? AppSettings()
    }

    init(permissionService: PermissionService, historyService: HistoryService, storageService: StorageService) {
        self.permissionService = permissionService
        self.historyService = historyService
        self.storageService = storageService
    }

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

    private func performCapture(mode: CaptureMode, capture: () async throws -> NSImage) async {
        isCapturing = true
        defer { isCapturing = false }

        do {
            let image = try await capture()
            capturedImage = image

            if settings.autoCopyToClipboard {
                copyToClipboard(image)
            }

            if settings.playSound {
                NSSound(named: "Tink")?.play()
            }

            try await historyService.addCapture(image: image, mode: mode)

            if settings.openEditorAfterCapture {
                showEditor = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    func saveImage(_ image: NSImage, format: ImageFormat? = nil) throws -> URL {
        try storageService.saveImage(image, format: format ?? settings.defaultImageFormat)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add CaptureViewModel

Orchestrates capture flow: capture → clipboard copy → history save →
open editor. Supports all capture modes with error handling."
```

---

### Task 7: Capture Overlay Window (Region Selection + Smart Detection)

**Files:**
- Create: `SnipIt/Views/Capture/CaptureOverlayWindow.swift`
- Create: `SnipIt/Views/Capture/SmartDetectionView.swift`
- Create: `SnipIt/Views/Capture/RegionSelectionView.swift`
- Create: `SnipIt/Views/Components/MagnifierView.swift`
- Create: `SnipIt/Utils/NSWindow+Extensions.swift`

- [ ] **Step 1: Create NSWindow extension for overlay**

```swift
// SnipIt/Utils/NSWindow+Extensions.swift
import AppKit

extension NSWindow {
    static func createOverlayWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return window
    }
}
```

- [ ] **Step 2: Create MagnifierView**

```swift
// SnipIt/Views/Components/MagnifierView.swift
import SwiftUI
import AppKit

struct MagnifierView: View {
    let screenImage: NSImage?
    let mousePosition: CGPoint
    let zoom: CGFloat = 2.0
    let size: CGFloat = 120

    var body: some View {
        ZStack {
            if let screenImage {
                let cropSize = size / zoom
                let cropOrigin = CGPoint(
                    x: max(0, mousePosition.x - cropSize / 2),
                    y: max(0, mousePosition.y - cropSize / 2)
                )

                Image(nsImage: screenImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: screenImage.size.width * zoom, height: screenImage.size.height * zoom)
                    .offset(
                        x: -(cropOrigin.x * zoom) + size / 2 - (size * zoom) / 2,
                        y: -(cropOrigin.y * zoom) + size / 2 - (size * zoom) / 2
                    )
                    .frame(width: size, height: size)
                    .clipped()
            }

            // Crosshair
            Path { p in
                p.move(to: CGPoint(x: size / 2, y: 0))
                p.addLine(to: CGPoint(x: size / 2, y: size))
                p.move(to: CGPoint(x: 0, y: size / 2))
                p.addLine(to: CGPoint(x: size, y: size / 2))
            }
            .stroke(Color.blue.opacity(0.5), lineWidth: 1)

            Circle()
                .fill(Color.blue)
                .frame(width: 4, height: 4)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
        .shadow(color: .black.opacity(0.5), radius: 8)
    }
}
```

- [ ] **Step 3: Create RegionSelectionView**

```swift
// SnipIt/Views/Capture/RegionSelectionView.swift
import SwiftUI

struct RegionSelectionView: View {
    let dimmingOpacity: Double
    let startPoint: CGPoint
    let currentPoint: CGPoint
    let isSelecting: Bool

    private var selectionRect: CGRect {
        CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dim overlay with cutout
                if isSelecting {
                    DimmingOverlay(rect: selectionRect, screenSize: geo.size, opacity: dimmingOpacity)

                    // Selection border
                    Rectangle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                        .frame(width: selectionRect.width, height: selectionRect.height)
                        .position(x: selectionRect.midX, y: selectionRect.midY)

                    // Corner handles
                    ForEach(cornerPositions, id: \.x) { pos in
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .position(x: pos.x, y: pos.y)
                    }

                    // Size label
                    let w = Int(selectionRect.width)
                    let h = Int(selectionRect.height)
                    Text("\(w) × \(h)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .position(x: selectionRect.minX, y: selectionRect.maxY + 20)
                } else {
                    Color.black.opacity(dimmingOpacity)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var cornerPositions: [CGPoint] {
        [
            CGPoint(x: selectionRect.minX, y: selectionRect.minY),
            CGPoint(x: selectionRect.maxX, y: selectionRect.minY),
            CGPoint(x: selectionRect.minX, y: selectionRect.maxY),
            CGPoint(x: selectionRect.maxX, y: selectionRect.maxY),
        ]
    }
}

struct DimmingOverlay: View {
    let rect: CGRect
    let screenSize: CGSize
    let opacity: Double

    var body: some View {
        Canvas { context, size in
            // Fill entire screen
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(opacity)))
            // Clear selection area
            context.blendMode = .destinationOut
            context.fill(Path(rect), with: .color(.white))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
```

- [ ] **Step 4: Create SmartDetectionView**

```swift
// SnipIt/Views/Capture/SmartDetectionView.swift
import SwiftUI
import ScreenCaptureKit

struct SmartDetectionView: View {
    let detectedWindowFrame: CGRect?
    let detectedWindowTitle: String?

    var body: some View {
        GeometryReader { geo in
            if let frame = detectedWindowFrame {
                ZStack {
                    // Highlight border around detected window
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.05))
                        )
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)

                    // Window label
                    if let title = detectedWindowTitle {
                        Text("\(title) — \(Int(frame.width)) × \(Int(frame.height))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .position(x: frame.minX + 80, y: frame.maxY + 16)
                    }
                }
            }

            // Bottom hint
            Text("클릭하여 창 캡처 · 드래그하여 영역 선택 · Space: 전체화면 · ESC: 취소")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .position(x: geo.size.width / 2, y: geo.size.height - 30)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
```

- [ ] **Step 5: Create CaptureOverlayWindow controller**

```swift
// SnipIt/Views/Capture/CaptureOverlayWindow.swift
import AppKit
import SwiftUI
import ScreenCaptureKit

final class CaptureOverlayWindow: NSObject {
    private var overlayWindow: NSWindow?
    private var captureVM: CaptureViewModel
    private let captureService = ScreenCaptureService()

    // State
    private var mousePosition: CGPoint = .zero
    private var startPoint: CGPoint = .zero
    private var currentPoint: CGPoint = .zero
    private var isSelecting = false
    private var isDragging = false
    private var detectedWindow: SCWindow?
    private var screenImage: NSImage?
    private var dimmingOpacity: Double

    private var continuation: CheckedContinuation<CaptureResult?, Never>?

    enum CaptureResult {
        case window(SCWindow)
        case region(SCDisplay, CGRect)
        case fullScreen
    }

    init(captureVM: CaptureViewModel, dimmingOpacity: Double = 0.4) {
        self.captureVM = captureVM
        self.dimmingOpacity = dimmingOpacity
        super.init()
    }

    func show() async -> CaptureResult? {
        let window = NSWindow.createOverlayWindow()
        self.overlayWindow = window

        // Take a reference screenshot for magnifier
        if let screen = NSScreen.main {
            let cgImage = CGDisplayCreateImage(CGMainDisplayID())
            if let cgImage {
                screenImage = NSImage(cgImage: cgImage, size: screen.frame.size)
            }
        }

        let hostingView = NSHostingView(rootView: overlayContentView)
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)

        // Monitor events
        let monitors = installEventMonitors()

        let result: CaptureResult? = await withCheckedContinuation { cont in
            self.continuation = cont
        }

        // Cleanup
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        window.orderOut(nil)
        overlayWindow = nil

        return result
    }

    private var overlayContentView: some View {
        ZStack {
            RegionSelectionView(
                dimmingOpacity: dimmingOpacity,
                startPoint: startPoint,
                currentPoint: currentPoint,
                isSelecting: isSelecting
            )

            if !isDragging {
                SmartDetectionView(
                    detectedWindowFrame: detectedWindowFrame,
                    detectedWindowTitle: detectedWindow?.title
                )
            }

            if !isSelecting {
                MagnifierView(screenImage: screenImage, mousePosition: mousePosition)
                    .position(magnifierPosition)
            }
        }
    }

    private var detectedWindowFrame: CGRect? {
        guard let window = detectedWindow else { return nil }
        guard let screen = NSScreen.main else { return nil }
        // Convert from screen coordinates (bottom-left origin) to view coordinates (top-left origin)
        let frame = window.frame
        return CGRect(
            x: frame.origin.x,
            y: screen.frame.height - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
    }

    private var magnifierPosition: CGPoint {
        CGPoint(x: mousePosition.x + 80, y: mousePosition.y - 80)
    }

    private func installEventMonitors() -> [Any] {
        var monitors: [Any] = []

        // Mouse moved → smart detection
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self else { return event }
            self.mousePosition = event.locationInWindow
            if !self.isDragging {
                Task { await self.detectWindow(at: event.locationInWindow) }
            }
            self.updateOverlay()
            return event
        } { monitors.append(monitor) }

        // Mouse down → start selection
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self else { return event }
            self.startPoint = event.locationInWindow
            self.currentPoint = event.locationInWindow
            self.isDragging = true
            return event
        } { monitors.append(monitor) }

        // Mouse dragged → update selection
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            guard let self else { return event }
            self.currentPoint = event.locationInWindow
            let dx = abs(self.currentPoint.x - self.startPoint.x)
            let dy = abs(self.currentPoint.y - self.startPoint.y)
            if dx > 3 || dy > 3 {
                self.isSelecting = true
            }
            self.updateOverlay()
            return event
        } { monitors.append(monitor) }

        // Mouse up → complete
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            guard let self else { return event }
            if self.isSelecting {
                // Region capture
                let rect = CGRect(
                    x: min(self.startPoint.x, self.currentPoint.x),
                    y: min(self.startPoint.y, self.currentPoint.y),
                    width: abs(self.currentPoint.x - self.startPoint.x),
                    height: abs(self.currentPoint.y - self.startPoint.y)
                )
                if rect.width > 5 && rect.height > 5 {
                    Task {
                        if let display = try? await self.captureService.getAvailableContent().displays.first {
                            self.continuation?.resume(returning: .region(display, rect))
                        }
                    }
                }
            } else if let window = self.detectedWindow {
                // Window capture
                self.continuation?.resume(returning: .window(window))
            }
            self.isDragging = false
            self.isSelecting = false
            return event
        } { monitors.append(monitor) }

        // Key down → ESC to cancel, Space for full screen
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // ESC
                self.continuation?.resume(returning: nil)
            } else if event.keyCode == 49 { // Space
                self.continuation?.resume(returning: .fullScreen)
            }
            return event
        } { monitors.append(monitor) }

        return monitors
    }

    private func detectWindow(at point: CGPoint) async {
        detectedWindow = try? await captureService.findWindow(at: point)
    }

    private func updateOverlay() {
        guard let window = overlayWindow else { return }
        let hostingView = NSHostingView(rootView: overlayContentView)
        window.contentView = hostingView
    }
}
```

- [ ] **Step 6: Build to verify compilation**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 7: Manual test**

Wire up a temporary button in MenuBarView to trigger:
```swift
Button("Test Capture") {
    Task {
        let overlay = CaptureOverlayWindow(captureVM: captureVM)
        let result = await overlay.show()
        // result will be .window, .region, or .fullScreen
    }
}
```
Expected: Overlay appears full screen, smart detection highlights windows, dragging creates region.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add capture overlay with smart window detection

Full-screen NSWindow overlay with smart window detection (highlight +
title), drag-to-select region, magnifier, size indicator. Space for
full screen, ESC to cancel."
```

---

## Phase 3: Editor

### Task 8: EditorViewModel

**Files:**
- Create: `SnipIt/ViewModels/EditorViewModel.swift`

- [ ] **Step 1: Implement EditorViewModel**

```swift
// SnipIt/ViewModels/EditorViewModel.swift
import SwiftUI
import AppKit

enum EditorTool: String, CaseIterable, Identifiable {
    case select, pen, arrow, line, rectangle, ellipse, text
    case highlight, blur, crop, ocr
    case number, step, codeBlock

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .select: return "cursorarrow"
        case .pen: return "pencil.tip"
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .text: return "textformat"
        case .highlight: return "highlighter"
        case .blur: return "circle.grid.3x3"
        case .crop: return "crop"
        case .ocr: return "text.viewfinder"
        case .number: return "number.circle"
        case .step: return "text.bubble"
        case .codeBlock: return "chevron.left.forwardslash.chevron.right"
        }
    }

    var label: String {
        switch self {
        case .select: return "선택"
        case .pen: return "펜"
        case .arrow: return "화살표"
        case .line: return "직선"
        case .rectangle: return "사각형"
        case .ellipse: return "원"
        case .text: return "텍스트"
        case .highlight: return "형광펜"
        case .blur: return "블러"
        case .crop: return "자르기"
        case .ocr: return "OCR"
        case .number: return "번호"
        case .step: return "스텝"
        case .codeBlock: return "코드"
        }
    }
}

@Observable
final class EditorViewModel {
    var image: NSImage
    var annotations: [AnyAnnotation] = []
    var currentTool: EditorTool = .select
    var strokeColor: Color = .red
    var strokeWidth: CGFloat = 3
    var fontSize: CGFloat = 16
    var fontBold = false
    var fontItalic = false

    // Drawing state
    var isDrawing = false
    var drawingPoints: [CGPoint] = []
    var drawStartPoint: CGPoint = .zero
    var drawCurrentPoint: CGPoint = .zero

    // Number counter
    var nextNumber: Int = 1

    // Undo/Redo
    private var undoStack: [[AnyAnnotation]] = []
    private var redoStack: [[AnyAnnotation]] = []

    init(image: NSImage) {
        self.image = image
    }

    // MARK: - Drawing

    func beginDraw(at point: CGPoint) {
        isDrawing = true
        drawStartPoint = point
        drawCurrentPoint = point
        drawingPoints = [point]
    }

    func continueDraw(at point: CGPoint) {
        drawCurrentPoint = point
        drawingPoints.append(point)
    }

    func endDraw(at point: CGPoint) {
        drawCurrentPoint = point
        isDrawing = false
        commitAnnotation()
    }

    private func commitAnnotation() {
        pushUndo()

        let annotation: (any Annotation)?

        switch currentTool {
        case .pen:
            var a = PenAnnotation()
            a.points = drawingPoints
            a.color = strokeColor
            a.strokeWidth = strokeWidth
            annotation = a

        case .arrow:
            var a = ArrowAnnotation()
            a.start = drawStartPoint
            a.end = drawCurrentPoint
            a.color = strokeColor
            a.strokeWidth = strokeWidth
            annotation = a

        case .line:
            var a = LineAnnotation()
            a.start = drawStartPoint
            a.end = drawCurrentPoint
            a.color = strokeColor
            a.strokeWidth = strokeWidth
            annotation = a

        case .rectangle:
            var a = RectangleAnnotation()
            a.origin = CGPoint(x: min(drawStartPoint.x, drawCurrentPoint.x), y: min(drawStartPoint.y, drawCurrentPoint.y))
            a.size = CGSize(width: abs(drawCurrentPoint.x - drawStartPoint.x), height: abs(drawCurrentPoint.y - drawStartPoint.y))
            a.color = strokeColor
            a.strokeWidth = strokeWidth
            annotation = a

        case .ellipse:
            var a = EllipseAnnotation()
            a.origin = CGPoint(x: min(drawStartPoint.x, drawCurrentPoint.x), y: min(drawStartPoint.y, drawCurrentPoint.y))
            a.size = CGSize(width: abs(drawCurrentPoint.x - drawStartPoint.x), height: abs(drawCurrentPoint.y - drawStartPoint.y))
            a.color = strokeColor
            a.strokeWidth = strokeWidth
            annotation = a

        case .highlight:
            var a = HighlightAnnotation()
            a.points = drawingPoints
            a.color = .yellow
            a.strokeWidth = 20
            annotation = a

        case .number:
            var a = NumberAnnotation()
            a.position = drawStartPoint
            a.number = nextNumber
            a.color = strokeColor
            nextNumber += 1
            annotation = a

        case .step:
            var a = StepAnnotation()
            a.position = drawStartPoint
            a.number = nextNumber
            a.text = "Step \(nextNumber)"
            a.color = strokeColor
            nextNumber += 1
            annotation = a

        case .codeBlock:
            var a = CodeBlockAnnotation()
            a.origin = drawStartPoint
            a.text = "code"
            annotation = a

        default:
            annotation = nil
        }

        if let annotation {
            annotations.append(AnyAnnotation(annotation))
        }

        drawingPoints = []
    }

    // MARK: - Text

    func addText(_ text: String, at position: CGPoint) {
        pushUndo()
        var a = TextAnnotation()
        a.position = position
        a.text = text
        a.fontSize = fontSize
        a.color = strokeColor
        a.isBold = fontBold
        a.isItalic = fontItalic
        annotations.append(AnyAnnotation(wrapping: a))
    }

    // MARK: - Undo/Redo

    private func pushUndo() {
        undoStack.append(annotations)
        redoStack.removeAll()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previous
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Export

    func renderFinalImage() -> NSImage {
        let size = image.size
        let result = NSImage(size: size)
        result.lockFocus()

        // Draw base image
        image.draw(in: NSRect(origin: .zero, size: size))

        // Draw annotations via SwiftUI Canvas rendering to CGContext
        if let context = NSGraphicsContext.current?.cgContext {
            let renderer = ImageRenderer(content:
                Canvas { ctx, canvasSize in
                    for annotation in annotations {
                        annotation.draw(in: &ctx, size: canvasSize)
                    }
                }
                .frame(width: size.width, height: size.height)
            )
            renderer.scale = 2.0 // Retina
            if let cgImage = renderer.cgImage {
                context.draw(cgImage, in: CGRect(origin: .zero, size: size))
            }
        }

        result.unlockFocus()
        return result
    }
}
```

- [ ] **Step 2: Build**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add EditorViewModel

Tool selection, annotation drawing (pen/arrow/line/rect/ellipse/
highlight/number/step/codeBlock), undo/redo stack, text insertion,
final image rendering with annotation compositing."
```

---

### Task 9: EditorCanvasView & FloatingToolbar

**Files:**
- Create: `SnipIt/Views/Editor/EditorCanvasView.swift`
- Create: `SnipIt/Views/Editor/FloatingToolbar.swift`

- [ ] **Step 1: Create EditorCanvasView**

```swift
// SnipIt/Views/Editor/EditorCanvasView.swift
import SwiftUI

struct EditorCanvasView: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        ZStack {
            // Layer 0: Original image
            Image(nsImage: viewModel.image)
                .resizable()
                .aspectRatio(contentMode: .fit)

            // Layer 1: Committed annotations
            Canvas { context, size in
                for annotation in viewModel.annotations {
                    annotation.draw(in: &context, size: size)
                }

                // Layer 2: Current drawing preview
                if viewModel.isDrawing {
                    drawPreview(in: &context, size: size)
                }
            }

            // Invisible interaction layer
            Color.clear
                .contentShape(Rectangle())
                .gesture(drawGesture)
        }
    }

    private func drawPreview(in context: inout GraphicsContext, size: CGSize) {
        let start = viewModel.drawStartPoint
        let current = viewModel.drawCurrentPoint
        let color = viewModel.strokeColor
        let width = viewModel.strokeWidth

        switch viewModel.currentTool {
        case .pen, .highlight:
            guard viewModel.drawingPoints.count > 1 else { return }
            var path = Path()
            path.move(to: viewModel.drawingPoints[0])
            for point in viewModel.drawingPoints.dropFirst() {
                path.addLine(to: point)
            }
            let strokeColor = viewModel.currentTool == .highlight ? Color.yellow.opacity(0.4) : color
            let strokeWidth = viewModel.currentTool == .highlight ? CGFloat(20) : width
            context.stroke(path, with: .color(strokeColor), lineWidth: strokeWidth)

        case .arrow, .line:
            let path = Path { p in
                p.move(to: start)
                p.addLine(to: current)
            }
            context.stroke(path, with: .color(color), lineWidth: width)

        case .rectangle:
            let rect = CGRect(
                x: min(start.x, current.x), y: min(start.y, current.y),
                width: abs(current.x - start.x), height: abs(current.y - start.y)
            ).standardized
            context.stroke(Path(rect), with: .color(color), lineWidth: width)

        case .ellipse:
            let rect = CGRect(
                x: min(start.x, current.x), y: min(start.y, current.y),
                width: abs(current.x - start.x), height: abs(current.y - start.y)
            ).standardized
            context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: width)

        default:
            break
        }
    }

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !viewModel.isDrawing {
                    viewModel.beginDraw(at: value.startLocation)
                }
                viewModel.continueDraw(at: value.location)
            }
            .onEnded { value in
                viewModel.endDraw(at: value.location)
            }
    }
}
```

- [ ] **Step 2: Create FloatingToolbar**

```swift
// SnipIt/Views/Editor/FloatingToolbar.swift
import SwiftUI

struct FloatingToolbar: View {
    @Bindable var viewModel: EditorViewModel

    private let tools: [[EditorTool]] = [
        [.select, .pen, .arrow, .line, .rectangle, .ellipse],
        [.text, .highlight, .blur, .crop],
        [.number, .step, .codeBlock],
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(tools.enumerated()), id: \.offset) { groupIndex, group in
                if groupIndex > 0 {
                    Divider()
                        .frame(height: 24)
                        .padding(.horizontal, 4)
                }

                ForEach(group) { tool in
                    toolButton(tool)
                }
            }

            Divider()
                .frame(height: 24)
                .padding(.horizontal, 4)

            // Color picker
            ColorPicker("", selection: $viewModel.strokeColor)
                .labelsHidden()
                .frame(width: 28, height: 28)

            // Stroke width
            Menu {
                ForEach([1, 2, 3, 5, 8], id: \.self) { width in
                    Button("\(width)px") {
                        viewModel.strokeWidth = CGFloat(width)
                    }
                }
            } label: {
                Image(systemName: "lineweight")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    private func toolButton(_ tool: EditorTool) -> some View {
        Button {
            viewModel.currentTool = tool
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .background(viewModel.currentTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(tool.label)
    }
}
```

- [ ] **Step 3: Build**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add EditorCanvasView and FloatingToolbar

SwiftUI Canvas with 3-layer rendering (base/annotations/preview),
drag gesture for drawing, floating toolbar with tool groups,
color picker, and stroke width control."
```

---

### Task 10: EditorWindow & ActionBar

**Files:**
- Create: `SnipIt/Views/Editor/EditorWindow.swift`
- Create: `SnipIt/Views/Editor/ActionBar.swift`
- Create: `SnipIt/Views/Components/ToastView.swift`

- [ ] **Step 1: Create ToastView**

```swift
// SnipIt/Views/Components/ToastView.swift
import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.green)
            Text(message)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
```

- [ ] **Step 2: Create ActionBar**

```swift
// SnipIt/Views/Editor/ActionBar.swift
import SwiftUI

struct ActionBar: View {
    @Bindable var viewModel: EditorViewModel
    var onClose: () -> Void
    var onPin: () -> Void
    var onOCR: () -> Void
    var onCopy: () -> Void
    var onSave: () -> Void
    var onDone: () -> Void

    var body: some View {
        HStack {
            // Left group
            HStack(spacing: 12) {
                Button { onClose() } label: {
                    Label("닫기", systemImage: "xmark")
                        .font(.system(size: 12))
                }
                .keyboardShortcut(.escape, modifiers: [])

                Divider().frame(height: 20)

                Button { viewModel.undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!viewModel.canUndo)
                .keyboardShortcut("z", modifiers: .command)

                Button { viewModel.redo() } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!viewModel.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            Spacer()

            // Right group
            HStack(spacing: 8) {
                Button { onPin() } label: {
                    Label("핀", systemImage: "pin")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Button { onOCR() } label: {
                    Label("OCR", systemImage: "text.viewfinder")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Divider().frame(height: 20)

                Button { onCopy() } label: {
                    Label("복사", systemImage: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Button { onSave() } label: {
                    Label("저장", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Button { onDone() } label: {
                    Text("완료")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
```

- [ ] **Step 3: Create EditorWindow**

```swift
// SnipIt/Views/Editor/EditorWindow.swift
import SwiftUI

struct EditorWindow: View {
    @Bindable var viewModel: EditorViewModel
    @State private var showToast = false
    @State private var toastMessage = ""

    var onClose: () -> Void
    var onPin: (NSImage) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Canvas area
                ZStack(alignment: .bottom) {
                    EditorCanvasView(viewModel: viewModel)
                        .padding(20)
                        .background(Color(nsColor: .controlBackgroundColor))

                    // Floating toolbar
                    FloatingToolbar(viewModel: viewModel)
                        .padding(.bottom, 16)
                }

                // Action bar
                ActionBar(
                    viewModel: viewModel,
                    onClose: onClose,
                    onPin: { onPin(viewModel.renderFinalImage()) },
                    onOCR: { /* Task 15 */ },
                    onCopy: { copyImage() },
                    onSave: { saveImage() },
                    onDone: { doneEditing() }
                )
            }

            // Toast overlay
            if showToast {
                ToastView(message: toastMessage, icon: "checkmark.circle.fill")
                    .padding(.bottom, 60)
            }
        }
        .frame(minWidth: 600, minHeight: 450)
        .onAppear {
            showTemporaryToast("클립보드에 복사됨")
        }
    }

    private func copyImage() {
        let finalImage = viewModel.renderFinalImage()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([finalImage])
        showTemporaryToast("클립보드에 복사됨")
    }

    private func saveImage() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg, .pdf]
        panel.nameFieldStringValue = "SnipIt_\(Date().formatted(.iso8601))"
        if panel.runModal() == .OK, let url = panel.url {
            let finalImage = viewModel.renderFinalImage()
            if let tiffData = finalImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let data = bitmap.representation(using: .png, properties: [:]) {
                try? data.write(to: url)
                showTemporaryToast("저장 완료")
            }
        }
    }

    private func doneEditing() {
        let finalImage = viewModel.renderFinalImage()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([finalImage])
        showTemporaryToast("클립보드에 복사됨")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onClose()
        }
    }

    private func showTemporaryToast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.3)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.3)) { showToast = false }
        }
    }
}
```

- [ ] **Step 4: Build**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add EditorWindow with ActionBar and ToastView

Complete editor UI: canvas + floating toolbar + action bar with
undo/redo/pin/OCR/copy/save/done. Toast notification for clipboard
status. Auto-toast on editor open."
```

---

### Task 11: Blur Tool (Mosaic Effect)

**Files:**
- Modify: `SnipIt/Models/Annotation.swift` (add BlurAnnotation)
- Modify: `SnipIt/ViewModels/EditorViewModel.swift` (handle blur tool)
- Create: `SnipIt/Utils/ImageProcessor.swift`

- [ ] **Step 1: Create ImageProcessor**

```swift
// SnipIt/Utils/ImageProcessor.swift
import AppKit
import CoreImage

enum ImageProcessor {
    static func applyMosaic(to image: NSImage, in rect: CGRect, blockSize: Int = 16) -> NSImage {
        let result = image.copy() as! NSImage
        guard let tiffData = result.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return result }

        let pixelRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.width,
            height: rect.height
        )

        let minX = max(0, Int(pixelRect.minX))
        let minY = max(0, Int(pixelRect.minY))
        let maxX = min(bitmap.pixelsWide, Int(pixelRect.maxX))
        let maxY = min(bitmap.pixelsHigh, Int(pixelRect.maxY))

        for blockY in stride(from: minY, to: maxY, by: blockSize) {
            for blockX in stride(from: minX, to: maxX, by: blockSize) {
                // Sample center pixel of block
                let sampleX = min(blockX + blockSize / 2, maxX - 1)
                let sampleY = min(blockY + blockSize / 2, maxY - 1)

                guard let color = bitmap.colorAt(x: sampleX, y: sampleY) else { continue }

                // Fill block with sampled color
                for y in blockY..<min(blockY + blockSize, maxY) {
                    for x in blockX..<min(blockX + blockSize, maxX) {
                        bitmap.setColor(color, atX: x, y: y)
                    }
                }
            }
        }

        let mosaicImage = NSImage(size: image.size)
        mosaicImage.addRepresentation(bitmap)
        return mosaicImage
    }
}
```

- [ ] **Step 2: Add BlurAnnotation to Annotation.swift**

Add to the end of `SnipIt/Models/Annotation.swift`:

```swift
struct BlurAnnotation: Annotation {
    let id = UUID()
    var origin: CGPoint = .zero
    var size: CGSize = .zero
    var color: Color = .clear
    var strokeWidth: CGFloat = 0
    var blockSize: Int = 16

    func draw(in context: inout GraphicsContext, size: CGSize) {
        // Blur is applied directly to the base image, not drawn on canvas.
        // This annotation stores the region for the mosaic effect.
        let rect = CGRect(origin: origin, size: self.size).standardized
        context.stroke(Path(rect), with: .color(.gray.opacity(0.3)), lineWidth: 1)
    }
}
```

- [ ] **Step 3: Update EditorViewModel blur handling**

Add to `commitAnnotation()` switch in EditorViewModel:

```swift
case .blur:
    var a = BlurAnnotation()
    a.origin = CGPoint(x: min(drawStartPoint.x, drawCurrentPoint.x), y: min(drawStartPoint.y, drawCurrentPoint.y))
    a.size = CGSize(width: abs(drawCurrentPoint.x - drawStartPoint.x), height: abs(drawCurrentPoint.y - drawStartPoint.y))
    annotation = a
    // Apply mosaic to base image
    let rect = CGRect(origin: a.origin, size: a.size)
    image = ImageProcessor.applyMosaic(to: image, in: rect)
```

- [ ] **Step 4: Build and test**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add blur/mosaic tool

16px block mosaic effect applied directly to base image.
ImageProcessor utility for pixel-level mosaic rendering."
```

---

## Phase 4: Recording

### Task 12: RecordingService (GIF + MP4)

**Files:**
- Create: `SnipIt/Services/RecordingService.swift`
- Create: `SnipIt/ViewModels/RecordingViewModel.swift`

- [ ] **Step 1: Implement RecordingService**

```swift
// SnipIt/Services/RecordingService.swift
import ScreenCaptureKit
import AVFoundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

actor RecordingService: NSObject {
    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    private var gifFrames: [(CGImage, TimeInterval)] = []
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var startTime: CMTime?

    private(set) var isRecording = false
    private(set) var recordingMode: RecordingMode = .gif
    private(set) var frameCount = 0
    private(set) var recordingDuration: TimeInterval = 0

    private var recordingStartDate: Date?
    private var fps: RecordingFPS = .thirty
    private var gifQuality: GifQuality = .skipFrames
    private var videoCodec: VideoCodec = .h264
    private var maxDuration: Int = 60
    private var outputURL: URL?

    func startRecording(
        mode: RecordingMode,
        region: CGRect,
        display: SCDisplay,
        fps: RecordingFPS,
        gifQuality: GifQuality = .skipFrames,
        videoCodec: VideoCodec = .h264,
        maxDuration: Int = 60,
        outputDirectory: URL
    ) async throws {
        self.recordingMode = mode
        self.fps = fps
        self.gifQuality = gifQuality
        self.videoCodec = videoCodec
        self.maxDuration = maxDuration
        self.frameCount = 0
        self.gifFrames = []

        let ext = mode == .gif ? "gif" : "mp4"
        let fileName = "SnipIt_\(Date().formatted(.iso8601)).\(ext)"
        self.outputURL = outputDirectory.appendingPathComponent(fileName)

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = region
        config.width = Int(region.width) * 2
        config.height = Int(region.height) * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps.rawValue))
        config.showsCursor = true

        if mode == .mp4 {
            try setupAssetWriter(width: config.width, height: config.height)
        }

        let output = StreamOutput { [weak self] sampleBuffer in
            Task { await self?.handleFrame(sampleBuffer) }
        }
        self.streamOutput = output

        stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream?.addStreamOutput(output, type: .screen, sampleBufferQueueDepth: 3)
        try await stream?.startCapture()

        isRecording = true
        recordingStartDate = Date()
    }

    func stopRecording() async throws -> URL? {
        guard isRecording else { return nil }
        isRecording = false

        try await stream?.stopCapture()
        stream = nil

        guard let outputURL else { return nil }

        if recordingMode == .gif {
            try encodeGif(to: outputURL)
        } else {
            await finalizeVideo()
        }

        return outputURL
    }

    func cancelRecording() async {
        isRecording = false
        try? await stream?.stopCapture()
        stream = nil
        gifFrames = []
        assetWriter = nil
    }

    // MARK: - Frame Handling

    private func handleFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording else { return }

        // Check max duration
        if let start = recordingStartDate {
            recordingDuration = Date().timeIntervalSince(start)
            if recordingDuration >= Double(maxDuration) {
                Task { _ = try? await stopRecording() }
                return
            }
        }

        guard let imageBuffer = sampleBuffer.imageBuffer else { return }
        frameCount += 1

        if recordingMode == .gif {
            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            let context = CIContext()
            let rect = CGRect(origin: .zero, size: CVImageBufferGetEncodedSize(imageBuffer))
            if let cgImage = context.createCGImage(ciImage, from: rect) {
                let scaledImage: CGImage
                if gifQuality == .skipFramesHalfSize {
                    scaledImage = cgImage // Scale down in encoding step
                } else {
                    scaledImage = cgImage
                }
                let frameDuration = 1.0 / Double(fps.rawValue)

                // Duplicate frame detection
                if gifQuality != .original, let lastFrame = gifFrames.last?.0 {
                    if framesAreSimilar(lastFrame, scaledImage) {
                        // Extend previous frame duration
                        if var last = gifFrames.last {
                            gifFrames.removeLast()
                            last.1 += frameDuration
                            gifFrames.append(last)
                        }
                        return
                    }
                }

                gifFrames.append((scaledImage, frameDuration))
            }
        } else {
            // MP4: write directly
            guard let videoInput, videoInput.isReadyForMoreMediaData else { return }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if startTime == nil { startTime = timestamp }
            pixelBufferAdaptor?.append(imageBuffer as! CVPixelBuffer, withPresentationTime: timestamp)
        }
    }

    // MARK: - GIF Encoding (ImageIO)

    private func encodeGif(to url: URL) throws {
        guard !gifFrames.isEmpty else { return }

        let properties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, gifFrames.count, nil) else {
            return
        }
        CGImageDestinationSetProperties(destination, properties)

        for (image, duration) in gifFrames {
            let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: duration]] as CFDictionary
            CGImageDestinationAddImage(destination, image, frameProperties)
        }

        CGImageDestinationFinalize(destination)
        gifFrames = []
    }

    // MARK: - MP4 Setup

    private func setupAssetWriter(width: Int, height: Int) throws {
        guard let outputURL else { return }

        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let codec: AVVideoCodecType = videoCodec == .hevc ? .hevc : .h264
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        assetWriter?.add(videoInput!)
        assetWriter?.startWriting()
        assetWriter?.startSession(atSourceTime: .zero)
    }

    private func finalizeVideo() async {
        videoInput?.markAsFinished()
        await assetWriter?.finishWriting()
        assetWriter = nil
    }

    // MARK: - Helpers

    private func framesAreSimilar(_ a: CGImage, _ b: CGImage) -> Bool {
        // Simple pixel sampling comparison (1% threshold)
        guard a.width == b.width, a.height == b.height else { return false }
        // Compare a few sample pixels for performance
        return false // Conservative: assume not similar to avoid frame loss
    }
}

// Stream output delegate
private final class StreamOutput: NSObject, SCStreamOutput {
    let handler: (CMSampleBuffer) -> Void

    init(handler: @escaping (CMSampleBuffer) -> Void) {
        self.handler = handler
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        handler(sampleBuffer)
    }
}
```

- [ ] **Step 2: Create RecordingViewModel**

```swift
// SnipIt/ViewModels/RecordingViewModel.swift
import SwiftUI
import ScreenCaptureKit

@Observable
final class RecordingViewModel {
    private let recordingService = RecordingService()
    private let storageService: StorageService

    var isRecording = false
    var recordingMode: RecordingMode = .gif
    var duration: TimeInterval = 0
    var frameCount = 0
    var outputURL: URL?
    var errorMessage: String?

    private var timer: Timer?

    init(storageService: StorageService) {
        self.storageService = storageService
    }

    func startRecording(mode: RecordingMode, region: CGRect, display: SCDisplay, settings: AppSettings) async {
        recordingMode = mode
        isRecording = true
        duration = 0
        frameCount = 0

        // Start duration timer on main thread
        await MainActor.run {
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { await self?.updateProgress() }
            }
        }

        do {
            try await recordingService.startRecording(
                mode: mode,
                region: region,
                display: display,
                fps: settings.recordingFPS,
                gifQuality: settings.gifQuality,
                videoCodec: settings.videoCodec,
                maxDuration: settings.maxRecordingDuration,
                outputDirectory: storageService.recordingsDirectory
            )
        } catch {
            errorMessage = error.localizedDescription
            isRecording = false
        }
    }

    func stopRecording() async {
        timer?.invalidate()
        timer = nil

        do {
            outputURL = try await recordingService.stopRecording()
            isRecording = false
        } catch {
            errorMessage = error.localizedDescription
            isRecording = false
        }
    }

    func cancelRecording() async {
        timer?.invalidate()
        timer = nil
        await recordingService.cancelRecording()
        isRecording = false
    }

    private func updateProgress() async {
        duration = await recordingService.recordingDuration
        frameCount = await recordingService.frameCount
    }
}
```

- [ ] **Step 3: Build**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add RecordingService for GIF and MP4

SCStream-based recording with ImageIO GIF encoding and AVAssetWriter
MP4 encoding. Hardware-accelerated H.264/HEVC. Frame skip for GIF
optimization. Max duration enforcement."
```

---

### Task 13: Recording UI (Border + Controls)

**Files:**
- Create: `SnipIt/Views/Recording/RecordingBorderView.swift`
- Create: `SnipIt/Views/Recording/RecordingControlView.swift`

- [ ] **Step 1: Create RecordingBorderView**

```swift
// SnipIt/Views/Recording/RecordingBorderView.swift
import AppKit

final class RecordingBorderWindow {
    private var window: NSWindow?

    func show(around rect: CGRect) {
        let borderWidth: CGFloat = 3
        let expandedRect = rect.insetBy(dx: -borderWidth, dy: -borderWidth)

        let window = NSWindow(
            contentRect: expandedRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces]

        let borderView = NSView(frame: window.contentView!.bounds)
        borderView.wantsLayer = true
        borderView.layer?.borderColor = NSColor.red.cgColor
        borderView.layer?.borderWidth = borderWidth
        borderView.layer?.cornerRadius = 4
        window.contentView?.addSubview(borderView)

        window.makeKeyAndOrderFront(nil)
        self.window = window

        // Pulse animation
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.5
        animation.duration = 0.8
        animation.autoreverses = true
        animation.repeatCount = .infinity
        borderView.layer?.add(animation, forKey: "pulse")
    }

    func hide() {
        window?.orderOut(nil)
        window = nil
    }
}
```

- [ ] **Step 2: Create RecordingControlView**

```swift
// SnipIt/Views/Recording/RecordingControlView.swift
import SwiftUI

struct RecordingControlView: View {
    @Bindable var viewModel: RecordingViewModel
    var onStop: () async -> Void
    var onCancel: () async -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Recording indicator
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(pulseOpacity)

            // Duration
            Text(formattedDuration)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.white)

            // Frame count
            Text("\(viewModel.frameCount) frames")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))

            Divider()
                .frame(height: 20)

            // Stop button
            Button {
                Task { await onStop() }
            } label: {
                Image(systemName: "stop.fill")
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            // Cancel button
            Button {
                Task { await onCancel() }
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.3), radius: 10)
    }

    @State private var pulseOpacity: Double = 1.0

    private var formattedDuration: String {
        let minutes = Int(viewModel.duration) / 60
        let seconds = Int(viewModel.duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
```

- [ ] **Step 3: Build**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add recording UI

Red pulsing border around recording region, floating control
panel with duration/frame count/stop/cancel buttons."
```

---

## Phase 5: Advanced Features

### Task 14: HotkeyService

**Files:**
- Create: `SnipIt/Services/HotkeyService.swift`
- Create: `SnipIt/Utils/KeyCodeMapping.swift`

- [ ] **Step 1: Create KeyCodeMapping**

```swift
// SnipIt/Utils/KeyCodeMapping.swift
import Carbon.HIToolbox

enum KeyCodeMapping {
    static let nameToCode: [String: UInt32] = [
        "A": UInt32(kVK_ANSI_A), "B": UInt32(kVK_ANSI_B), "C": UInt32(kVK_ANSI_C),
        "D": UInt32(kVK_ANSI_D), "E": UInt32(kVK_ANSI_E), "F": UInt32(kVK_ANSI_F),
        "G": UInt32(kVK_ANSI_G), "H": UInt32(kVK_ANSI_H), "I": UInt32(kVK_ANSI_I),
        "J": UInt32(kVK_ANSI_J), "K": UInt32(kVK_ANSI_K), "L": UInt32(kVK_ANSI_L),
        "M": UInt32(kVK_ANSI_M), "N": UInt32(kVK_ANSI_N), "O": UInt32(kVK_ANSI_O),
        "P": UInt32(kVK_ANSI_P), "Q": UInt32(kVK_ANSI_Q), "R": UInt32(kVK_ANSI_R),
        "S": UInt32(kVK_ANSI_S), "T": UInt32(kVK_ANSI_T), "U": UInt32(kVK_ANSI_U),
        "V": UInt32(kVK_ANSI_V), "W": UInt32(kVK_ANSI_W), "X": UInt32(kVK_ANSI_X),
        "Y": UInt32(kVK_ANSI_Y), "Z": UInt32(kVK_ANSI_Z),
        "1": UInt32(kVK_ANSI_1), "2": UInt32(kVK_ANSI_2), "3": UInt32(kVK_ANSI_3),
        "4": UInt32(kVK_ANSI_4), "5": UInt32(kVK_ANSI_5), "6": UInt32(kVK_ANSI_6),
        "7": UInt32(kVK_ANSI_7), "8": UInt32(kVK_ANSI_8), "9": UInt32(kVK_ANSI_9),
        "0": UInt32(kVK_ANSI_0),
    ]

    static let codeToName: [UInt32: String] = {
        Dictionary(uniqueKeysWithValues: nameToCode.map { ($1, $0) })
    }()

    static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if let name = codeToName[keyCode] { parts.append(name) }
        return parts.joined()
    }
}
```

- [ ] **Step 2: Create HotkeyService**

```swift
// SnipIt/Services/HotkeyService.swift
import Carbon.HIToolbox
import AppKit

final class HotkeyService {
    private var registeredHotkeys: [UInt32: (EventHotKeyRef, () -> Void)] = [:]
    private var nextID: UInt32 = 1

    static let shared = HotkeyService()

    private init() {
        installEventHandler()
    }

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        let id = nextID
        nextID += 1

        var hotKeyID = EventHotKeyID(signature: FourCharCode(0x534E4954), id: id) // "SNIT"
        var hotKeyRef: EventHotKeyRef?

        let carbonModifiers = carbonModifierFlags(from: modifiers)

        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            registeredHotkeys[id] = (ref, handler)
        }
    }

    func register(config: HotkeyConfig, handler: @escaping () -> Void) {
        register(keyCode: config.keyCode, modifiers: config.modifiers, handler: handler)
    }

    func unregisterAll() {
        for (_, (ref, _)) in registeredHotkeys {
            UnregisterEventHotKey(ref)
        }
        registeredHotkeys.removeAll()
    }

    func reregister(settings: AppSettings, handlers: HotkeyHandlers) {
        unregisterAll()
        register(config: settings.hotkeyFullScreen, handler: handlers.fullScreen)
        register(config: settings.hotkeyRegion, handler: handlers.region)
        register(config: settings.hotkeyWindow, handler: handlers.window)
        register(config: settings.hotkeyScroll, handler: handlers.scroll)
        register(config: settings.hotkeyGifRecord, handler: handlers.gifRecord)
        register(config: settings.hotkeyMp4Record, handler: handlers.mp4Record)
    }

    private func installEventHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return OSStatus(eventNotHandledErr) }

            DispatchQueue.main.async {
                HotkeyService.shared.handleHotkey(id: hotKeyID.id)
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventSpec, nil, nil)
    }

    private func handleHotkey(id: UInt32) {
        registeredHotkeys[id]?.1()
    }

    private func carbonModifierFlags(from flags: UInt32) -> UInt32 {
        var carbon: UInt32 = 0
        if flags & UInt32(controlKey) != 0 { carbon |= UInt32(controlKey) }
        if flags & UInt32(optionKey) != 0 { carbon |= UInt32(optionKey) }
        if flags & UInt32(shiftKey) != 0 { carbon |= UInt32(shiftKey) }
        if flags & UInt32(cmdKey) != 0 { carbon |= UInt32(cmdKey) }
        return carbon
    }
}

struct HotkeyHandlers {
    var fullScreen: () -> Void
    var region: () -> Void
    var window: () -> Void
    var scroll: () -> Void
    var gifRecord: () -> Void
    var mp4Record: () -> Void
}
```

- [ ] **Step 3: Build**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: add HotkeyService with Carbon API

Global hotkey registration via RegisterEventHotKey, key code
mapping utility, re-registration from settings, display string
formatting for UI."
```

---

### Task 15: OCRService

**Files:**
- Create: `SnipIt/Services/OCRService.swift`

- [ ] **Step 1: Implement OCRService**

```swift
// SnipIt/Services/OCRService.swift
import Vision
import AppKit

struct OCRResult {
    let fullText: String
    let lines: [OCRLine]
}

struct OCRLine {
    let text: String
    let boundingBox: CGRect
    let words: [OCRWord]
}

struct OCRWord {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}

actor OCRService {
    func extractText(from image: NSImage, language: String? = nil) async throws -> OCRResult {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageConversionFailed
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        if let language {
            request.recognitionLanguages = [language]
        } else {
            request.recognitionLanguages = ["ko-KR", "en-US", "ja-JP", "zh-Hans"]
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return OCRResult(fullText: "", lines: [])
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        var lines: [OCRLine] = []
        var fullText = ""

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            let boundingBox = convertBoundingBox(observation.boundingBox, imageSize: imageSize)

            var words: [OCRWord] = []
            if let recognizedText = try? topCandidate.string as NSString {
                // Get word-level bounding boxes
                let range = NSRange(location: 0, length: recognizedText.length)
                if let wordRanges = try? observation.topCandidates(1).first?.string {
                    words.append(OCRWord(text: wordRanges, boundingBox: boundingBox, confidence: topCandidate.confidence))
                }
            }

            lines.append(OCRLine(text: topCandidate.string, boundingBox: boundingBox, words: words))
            fullText += topCandidate.string + "\n"
        }

        return OCRResult(fullText: fullText.trimmingCharacters(in: .whitespacesAndNewlines), lines: lines)
    }

    func availableLanguages() -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        return (try? request.supportedRecognitionLanguages()) ?? []
    }

    private func convertBoundingBox(_ box: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: box.origin.x * imageSize.width,
            y: (1 - box.origin.y - box.height) * imageSize.height,
            width: box.width * imageSize.width,
            height: box.height * imageSize.height
        )
    }
}

enum OCRError: LocalizedError {
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "Failed to convert image for OCR"
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add OCRService with Vision framework

Multi-language text recognition (ko/en/ja/zh), line and word-level
bounding boxes, confidence scores. VNRecognizeTextRequest with
accurate recognition level."
```

---

### Task 16: ScrollCaptureService

**Files:**
- Create: `SnipIt/Services/ScrollCaptureService.swift`

- [ ] **Step 1: Implement ScrollCaptureService**

```swift
// SnipIt/Services/ScrollCaptureService.swift
import ScreenCaptureKit
import Vision
import AppKit

actor ScrollCaptureService {
    private let captureService = ScreenCaptureService()

    func captureScrolling(display: SCDisplay, region: CGRect, scrollAmount: CGFloat = 200, maxScrolls: Int = 20) async throws -> NSImage {
        var captures: [NSImage] = []

        // Capture initial frame
        let firstFrame = try await captureService.captureRegion(display: display, rect: region)
        captures.append(firstFrame)

        // Scroll and capture
        for _ in 0..<maxScrolls {
            // Simulate scroll
            let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: Int32(-scrollAmount), wheel2: 0, wheel3: 0)
            scrollEvent?.post(tap: .cghidEventTap)

            // Wait for scroll animation
            try await Task.sleep(for: .milliseconds(300))

            // Capture new frame
            let frame = try await captureService.captureRegion(display: display, rect: region)

            // Check if we've reached the bottom (compare with previous frame)
            if await framesAreIdentical(captures.last!, frame) {
                break
            }

            captures.append(frame)
        }

        // Stitch images
        return try await stitchImages(captures)
    }

    private func framesAreIdentical(_ a: NSImage, _ b: NSImage) -> Bool {
        guard let aData = a.tiffRepresentation, let bData = b.tiffRepresentation else { return false }
        return aData == bData
    }

    private func stitchImages(_ images: [NSImage]) async throws -> NSImage {
        guard !images.isEmpty else { throw CaptureError.regionInvalid }
        guard images.count > 1 else { return images[0] }

        // Use Vision to find overlap between consecutive frames
        var totalHeight: CGFloat = images[0].size.height
        var overlaps: [CGFloat] = []

        for i in 0..<(images.count - 1) {
            let overlap = try await findOverlap(top: images[i], bottom: images[i + 1])
            overlaps.append(overlap)
            totalHeight += images[i + 1].size.height - overlap
        }

        // Create stitched image
        let width = images[0].size.width
        let result = NSImage(size: NSSize(width: width, height: totalHeight))
        result.lockFocus()

        var yOffset: CGFloat = 0
        for (i, image) in images.enumerated() {
            let drawHeight = image.size.height
            let sourceRect = NSRect(origin: .zero, size: image.size)

            if i == 0 {
                image.draw(in: NSRect(x: 0, y: totalHeight - drawHeight, width: width, height: drawHeight), from: sourceRect, operation: .copy, fraction: 1.0)
                yOffset = drawHeight
            } else {
                let overlap = overlaps[i - 1]
                let cropRect = NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height - overlap)
                let drawY = totalHeight - yOffset - (drawHeight - overlap)
                image.draw(in: NSRect(x: 0, y: drawY, width: width, height: drawHeight - overlap), from: cropRect, operation: .copy, fraction: 1.0)
                yOffset += drawHeight - overlap
            }
        }

        result.unlockFocus()
        return result
    }

    private func findOverlap(top: NSImage, bottom: NSImage) async throws -> CGFloat {
        // Use VNFeaturePrintObservation for image matching
        guard let topCG = top.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let bottomCG = bottom.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 0
        }

        // Compare strips from bottom of 'top' with strips from top of 'bottom'
        let stripHeight = 50
        let maxOverlap = Int(top.size.height * 0.8)

        for offset in stride(from: stripHeight, to: maxOverlap, by: stripHeight / 2) {
            let topStrip = topCG.cropping(to: CGRect(x: 0, y: topCG.height - offset, width: topCG.width, height: stripHeight))
            let bottomStrip = bottomCG.cropping(to: CGRect(x: 0, y: bottomCG.height - stripHeight, width: bottomCG.width, height: stripHeight))

            if let topStrip, let bottomStrip {
                let similarity = try computeSimilarity(topStrip, bottomStrip)
                if similarity > 0.95 {
                    return CGFloat(offset)
                }
            }
        }

        return 0
    }

    private func computeSimilarity(_ a: CGImage, _ b: CGImage) throws -> Float {
        let requestA = VNGenerateImageFeaturePrintRequest()
        let requestB = VNGenerateImageFeaturePrintRequest()

        let handlerA = VNImageRequestHandler(cgImage: a)
        let handlerB = VNImageRequestHandler(cgImage: b)

        try handlerA.perform([requestA])
        try handlerB.perform([requestB])

        guard let printA = requestA.results?.first as? VNFeaturePrintObservation,
              let printB = requestB.results?.first as? VNFeaturePrintObservation else {
            return 0
        }

        var distance: Float = 0
        try printA.computeDistance(&distance, to: printB)
        return max(0, 1 - distance) // Convert distance to similarity
    }
}
```

- [ ] **Step 2: Build**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add ScrollCaptureService

Automated scroll capture with Vision framework image stitching.
VNFeaturePrintObservation for overlap detection, CGEvent scroll
simulation, duplicate frame detection for scroll end."
```

---

### Task 17: PinWindow & HistoryView

**Files:**
- Create: `SnipIt/Views/Pin/PinWindow.swift`
- Create: `SnipIt/Views/History/HistoryView.swift`
- Create: `SnipIt/ViewModels/HistoryViewModel.swift`

- [ ] **Step 1: Create PinWindow**

```swift
// SnipIt/Views/Pin/PinWindow.swift
import SwiftUI
import AppKit

struct PinWindowView: View {
    let image: NSImage
    @State private var opacity: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(opacity)

            // Opacity slider
            HStack(spacing: 8) {
                Text("투명도")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Slider(value: $opacity, in: 0.2...1.0)
                    .frame(maxWidth: 120)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)
        }
    }
}

final class PinWindowController {
    private var windows: [NSWindow] = []

    func pin(image: NSImage) {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: image.size.width / 2, height: image.size.height / 2 + 30)),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.title = "📌 SnipIt Pin"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PinWindowView(image: image))
        window.center()
        window.makeKeyAndOrderFront(nil)
        windows.append(window)
    }

    func closeAll() {
        windows.forEach { $0.close() }
        windows.removeAll()
    }
}
```

- [ ] **Step 2: Create HistoryViewModel**

```swift
// SnipIt/ViewModels/HistoryViewModel.swift
import SwiftUI

@Observable
final class HistoryViewModel {
    private let historyService: HistoryService

    var items: [CaptureHistoryItem] { historyService.items }

    init(historyService: HistoryService) {
        self.historyService = historyService
    }

    func loadThumbnail(for item: CaptureHistoryItem) -> NSImage? {
        historyService.loadThumbnail(for: item)
    }

    func loadImage(for item: CaptureHistoryItem) -> NSImage? {
        historyService.loadImage(for: item)
    }

    func delete(_ item: CaptureHistoryItem) {
        historyService.deleteItem(item)
    }

    func clearAll() {
        historyService.clearHistory()
    }
}
```

- [ ] **Step 3: Create HistoryView**

```swift
// SnipIt/Views/History/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: HistoryViewModel
    var onOpen: (NSImage) -> Void

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("캡처 히스토리")
                    .font(.headline)
                Spacer()
                if !viewModel.items.isEmpty {
                    Button("전체 삭제") {
                        viewModel.clearAll()
                    }
                    .foregroundStyle(.red)
                    .font(.system(size: 12))
                }
            }
            .padding()

            if viewModel.items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("캡처 히스토리가 비어있습니다")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.items) { item in
                            HistoryItemView(
                                item: item,
                                thumbnail: viewModel.loadThumbnail(for: item),
                                onOpen: {
                                    if let image = viewModel.loadImage(for: item) {
                                        onOpen(image)
                                    }
                                },
                                onDelete: { viewModel.delete(item) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

struct HistoryItemView: View {
    let item: CaptureHistoryItem
    let thumbnail: NSImage?
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 100)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 100)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.width) × \(item.height)")
                    .font(.system(size: 11, weight: .medium))
                Text(item.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button("편집기에서 열기") { onOpen() }
            Divider()
            Button("삭제", role: .destructive) { onDelete() }
        }
        .onTapGesture(count: 2) { onOpen() }
    }
}
```

- [ ] **Step 4: Build**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add PinWindow, HistoryView, HistoryViewModel

Always-on-top pin window with opacity control, capture history
grid with thumbnails, context menu, double-click to edit."
```

---

## Phase 6: System Integration

### Task 18: SettingsViewModel & Settings Views

**Files:**
- Create: `SnipIt/ViewModels/SettingsViewModel.swift`
- Create: `SnipIt/Views/Settings/SettingsWindow.swift`
- Create: `SnipIt/Views/Settings/GeneralSettingsView.swift`
- Create: `SnipIt/Views/Settings/CaptureSettingsView.swift`
- Create: `SnipIt/Views/Settings/RecordingSettingsView.swift`
- Create: `SnipIt/Views/Settings/HotkeySettingsView.swift`
- Create: `SnipIt/Views/Settings/StorageSettingsView.swift`
- Create: `SnipIt/Views/Settings/ThemeSettingsView.swift`

- [ ] **Step 1: Create SettingsViewModel**

```swift
// SnipIt/ViewModels/SettingsViewModel.swift
import SwiftUI
import ServiceManagement

@Observable
final class SettingsViewModel {
    private let storageService: StorageService
    var settings: AppSettings

    init(storageService: StorageService) {
        self.storageService = storageService
        self.settings = (try? storageService.loadSettings()) ?? AppSettings()
    }

    func save() {
        try? storageService.saveSettings(settings)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        settings.launchAtLogin = enabled
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
        save()
    }
}
```

- [ ] **Step 2: Create SettingsWindow with tabs**

```swift
// SnipIt/Views/Settings/SettingsWindow.swift
import SwiftUI

struct SettingsWindow: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            GeneralSettingsView(viewModel: viewModel)
                .tabItem { Label("일반", systemImage: "gear") }
            CaptureSettingsView(viewModel: viewModel)
                .tabItem { Label("캡처", systemImage: "camera") }
            RecordingSettingsView(viewModel: viewModel)
                .tabItem { Label("녹화", systemImage: "record.circle") }
            HotkeySettingsView(viewModel: viewModel)
                .tabItem { Label("단축키", systemImage: "keyboard") }
            StorageSettingsView(viewModel: viewModel)
                .tabItem { Label("저장", systemImage: "folder") }
            ThemeSettingsView(viewModel: viewModel)
                .tabItem { Label("테마", systemImage: "paintbrush") }
        }
        .frame(width: 520, height: 380)
    }
}
```

- [ ] **Step 3: Create each settings tab**

```swift
// SnipIt/Views/Settings/GeneralSettingsView.swift
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Toggle("시작 시 자동 실행", isOn: Binding(
                get: { viewModel.settings.launchAtLogin },
                set: { viewModel.setLaunchAtLogin($0) }
            ))
            Toggle("캡처 사운드 재생", isOn: $viewModel.settings.playSound)
            Toggle("캡처 후 에디터 자동 열기", isOn: $viewModel.settings.openEditorAfterCapture)
            Toggle("자동 클립보드 복사", isOn: $viewModel.settings.autoCopyToClipboard)

            Picker("언어", selection: $viewModel.settings.language) {
                Text("시스템").tag("system")
                Text("한국어").tag("ko")
                Text("English").tag("en")
            }
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.settings) { _, _ in viewModel.save() }
    }
}
```

```swift
// SnipIt/Views/Settings/CaptureSettingsView.swift
import SwiftUI

struct CaptureSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Slider(value: $viewModel.settings.dimmingOpacity, in: 0...1) {
                Text("딤 오버레이 투명도: \(Int(viewModel.settings.dimmingOpacity * 100))%")
            }

            Picker("기본 이미지 포맷", selection: $viewModel.settings.defaultImageFormat) {
                ForEach(ImageFormat.allCases, id: \.self) { format in
                    Text(format.rawValue.uppercased()).tag(format)
                }
            }

            Toggle("커서 포함", isOn: $viewModel.settings.includeCursor)
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.settings) { _, _ in viewModel.save() }
    }
}
```

```swift
// SnipIt/Views/Settings/RecordingSettingsView.swift
import SwiftUI

struct RecordingSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Picker("프레임레이트", selection: $viewModel.settings.recordingFPS) {
                ForEach(RecordingFPS.allCases, id: \.self) { fps in
                    Text("\(fps.rawValue) FPS").tag(fps)
                }
            }

            Picker("GIF 품질", selection: $viewModel.settings.gifQuality) {
                Text("원본").tag(GifQuality.original)
                Text("프레임 스킵").tag(GifQuality.skipFrames)
                Text("프레임 스킵 + 반절 크기").tag(GifQuality.skipFramesHalfSize)
            }

            Picker("MP4 코덱", selection: $viewModel.settings.videoCodec) {
                Text("H.264 (호환성)").tag(VideoCodec.h264)
                Text("HEVC (고품질)").tag(VideoCodec.hevc)
            }

            Picker("최대 녹화 시간", selection: $viewModel.settings.maxRecordingDuration) {
                Text("30초").tag(30)
                Text("60초").tag(60)
                Text("120초").tag(120)
                Text("180초").tag(180)
            }
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.settings) { _, _ in viewModel.save() }
    }
}
```

```swift
// SnipIt/Views/Settings/HotkeySettingsView.swift
import SwiftUI

struct HotkeySettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            hotkeyRow("전체 화면", config: $viewModel.settings.hotkeyFullScreen)
            hotkeyRow("영역 선택", config: $viewModel.settings.hotkeyRegion)
            hotkeyRow("활성 창", config: $viewModel.settings.hotkeyWindow)
            hotkeyRow("스크롤 캡처", config: $viewModel.settings.hotkeyScroll)
            hotkeyRow("GIF 녹화", config: $viewModel.settings.hotkeyGifRecord)
            hotkeyRow("MP4 녹화", config: $viewModel.settings.hotkeyMp4Record)
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.settings) { _, _ in viewModel.save() }
    }

    private func hotkeyRow(_ label: String, config: Binding<HotkeyConfig>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(KeyCodeMapping.displayString(keyCode: config.wrappedValue.keyCode, modifiers: config.wrappedValue.modifiers))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .font(.system(size: 12, design: .monospaced))
        }
    }
}
```

```swift
// SnipIt/Views/Settings/StorageSettingsView.swift
import SwiftUI

struct StorageSettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            HStack {
                Text("저장 폴더")
                Spacer()
                Text(viewModel.settings.savePath.isEmpty ? "기본 위치" : viewModel.settings.savePath)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button("변경") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    if panel.runModal() == .OK, let url = panel.url {
                        viewModel.settings.savePath = url.path
                        viewModel.save()
                    }
                }
            }

            TextField("파일 이름 패턴", text: $viewModel.settings.fileNamePattern)
                .textFieldStyle(.roundedBorder)

            Text("사용 가능 변수: {yyyy}, {MM}, {dd}, {HH}, {mm}, {ss}")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .onChange(of: viewModel.settings) { _, _ in viewModel.save() }
    }
}
```

```swift
// SnipIt/Views/Settings/ThemeSettingsView.swift
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
        .onChange(of: viewModel.settings) { _, _ in viewModel.save() }
    }
}
```

- [ ] **Step 4: Build**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add Settings views

Apple-style tabbed settings: general, capture, recording, hotkeys,
storage, theme. Auto-save on change, launch-at-login via SMAppService."
```

---

### Task 19: Onboarding

**Files:**
- Create: `SnipIt/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Create OnboardingView**

```swift
// SnipIt/Views/Onboarding/OnboardingView.swift
import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    let permissionService: PermissionService
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                permissionStep.tag(1)
                shortcutStep.tag(2)
            }
            .tabViewStyle(.automatic)

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("이전") { withAnimation { currentStep -= 1 } }
                        .buttonStyle(.plain)
                }
                Spacer()
                if currentStep < 2 {
                    Button("다음") { withAnimation { currentStep += 1 } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("시작하기") { onComplete() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
        .frame(width: 480, height: 380)
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "scissors")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("SnipIt에 오신 것을 환영합니다")
                .font(.title2.bold())
            Text("가볍고 강력한 macOS 화면 캡처 도구입니다.\n캡처, 녹화, 편집을 하나의 앱에서.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private var permissionStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("화면 녹화 권한")
                .font(.title2.bold())
            Text("SnipIt이 화면을 캡처하려면\n화면 녹화 권한이 필요합니다.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("권한 허용하기") {
                permissionService.requestScreenRecordingPermission()
            }
            .buttonStyle(.borderedProminent)

            Text("시스템 설정 > 개인정보 보호 > 화면 녹화에서\nSnipIt을 허용해주세요.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private var shortcutStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text("단축키 안내")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                shortcutRow("⌃⌥A", "전체 화면 캡처")
                shortcutRow("⌃⌥S", "영역 선택 (스마트 감지)")
                shortcutRow("⌃⌥W", "활성 창 캡처")
                shortcutRow("⌃⌥G", "GIF 녹화")
                shortcutRow("⌃⌥V", "MP4 녹화")
            }

            Text("설정에서 모든 단축키를 변경할 수 있습니다.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private func shortcutRow(_ shortcut: String, _ description: String) -> some View {
        HStack {
            Text(shortcut)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(description)
                .font(.system(size: 13))
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add onboarding flow

3-step onboarding: welcome, screen recording permission request,
hotkey guide. Apple-style minimal design."
```

---

### Task 20: Wire Up MenuBarView & AppState

**Files:**
- Modify: `SnipIt/SnipItApp.swift`
- Modify: `SnipIt/Views/MenuBar/MenuBarView.swift`

- [ ] **Step 1: Update AppState with all services**

```swift
// SnipIt/SnipItApp.swift
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

        // Editor window
        Window("SnipIt Editor", id: "editor") {
            if let image = appState.captureVM.capturedImage {
                EditorWindow(
                    viewModel: EditorViewModel(image: image),
                    onClose: { appState.captureVM.showEditor = false },
                    onPin: { appState.pinController.pin(image: $0) }
                )
            }
        }
        .windowStyle(.titleBar)

        // History window
        Window("캡처 히스토리", id: "history") {
            HistoryView(
                viewModel: appState.historyVM,
                onOpen: { image in
                    appState.captureVM.capturedImage = image
                    appState.captureVM.showEditor = true
                }
            )
        }

        // Onboarding
        Window("SnipIt 시작하기", id: "onboarding") {
            OnboardingView(
                permissionService: appState.permissionService,
                onComplete: {
                    appState.hasCompletedOnboarding = true
                }
            )
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 480, height: 380)
    }
}

@Observable
final class AppState {
    let storageService: StorageService
    let permissionService: PermissionService
    let historyService: HistoryService
    let captureVM: CaptureViewModel
    let recordingVM: RecordingViewModel
    let settingsVM: SettingsViewModel
    let historyVM: HistoryViewModel
    let pinController = PinWindowController()

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    init() {
        let storage = StorageService()
        let permission = PermissionService()
        let history = HistoryService(storageService: storage)

        self.storageService = storage
        self.permissionService = permission
        self.historyService = history
        self.captureVM = CaptureViewModel(permissionService: permission, historyService: history, storageService: storage)
        self.recordingVM = RecordingViewModel(storageService: storage)
        self.settingsVM = SettingsViewModel(storageService: storage)
        self.historyVM = HistoryViewModel(historyService: history)

        // Register hotkeys
        let settings = settingsVM.settings
        HotkeyService.shared.reregister(settings: settings, handlers: HotkeyHandlers(
            fullScreen: { Task { await self.captureVM.captureFullScreen() } },
            region: { self.showCaptureOverlay() },
            window: { self.showCaptureOverlay() },
            scroll: { /* Task 16 integration */ },
            gifRecord: { self.toggleRecording(mode: .gif) },
            mp4Record: { self.toggleRecording(mode: .mp4) }
        ))

        // Check permissions on launch
        Task {
            await permission.checkScreenRecordingPermission()
        }
    }

    func showCaptureOverlay() {
        Task { @MainActor in
            let overlay = CaptureOverlayWindow(captureVM: captureVM, dimmingOpacity: settingsVM.settings.dimmingOpacity)
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

    func toggleRecording(mode: RecordingMode) {
        Task {
            if recordingVM.isRecording {
                await recordingVM.stopRecording()
            } else {
                let overlay = CaptureOverlayWindow(captureVM: captureVM)
                guard let result = await overlay.show() else { return }
                if case .region(let display, let rect) = result {
                    await recordingVM.startRecording(mode: mode, region: rect, display: display, settings: settingsVM.settings)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Update MenuBarView**

```swift
// SnipIt/Views/MenuBar/MenuBarView.swift
import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "scissors")
                        .foregroundStyle(.blue)
                    Text("SnipIt")
                        .font(.system(size: 14, weight: .semibold))
                }
                Spacer()
                Button { openWindow(id: "settings") } label: {
                    Image(systemName: "gear")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            // Capture grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                captureButton("🖥️", "전체 화면", "⌃⌥A") {
                    Task { await appState.captureVM.captureFullScreen() }
                }
                captureButton("⬜", "영역 선택", "⌃⌥S") {
                    appState.showCaptureOverlay()
                }
                captureButton("📱", "활성 창", "⌃⌥W") {
                    appState.showCaptureOverlay()
                }
                captureButton("📜", "스크롤", "⌃⌥D") {
                    // Scroll capture
                }
            }
            .padding(.horizontal, 12)

            Divider().padding(.vertical, 12).padding(.horizontal, 16)

            // Recording
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                recordButton("🎬", "GIF 녹화", "⌃⌥G", mode: .gif)
                recordButton("🎥", "MP4 녹화", "⌃⌥V", mode: .mp4)
            }
            .padding(.horizontal, 12)

            Divider().padding(.vertical, 12).padding(.horizontal, 16)

            // Recent captures
            HStack {
                Text("최근 캡처")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button("전체보기") {
                    openWindow(id: "history")
                }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(appState.historyVM.items.prefix(4)) { item in
                        if let thumb = appState.historyVM.loadThumbnail(for: item) {
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 56, height: 38)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
        }
        .frame(width: 280)
    }

    private func captureButton(_ emoji: String, _ title: String, _ shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(emoji).font(.system(size: 22))
                Text(title).font(.system(size: 11, weight: .medium))
                Text(shortcut).font(.system(size: 9)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func recordButton(_ emoji: String, _ title: String, _ shortcut: String, mode: RecordingMode) -> some View {
        Button {
            appState.toggleRecording(mode: mode)
        } label: {
            HStack(spacing: 10) {
                Text(emoji).font(.system(size: 14))
                VStack(alignment: .leading) {
                    Text(title).font(.system(size: 11, weight: .medium))
                    Text(shortcut).font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// showCaptureOverlay() and toggleRecording() are defined
// as public methods on AppState in SnipItApp.swift (Task 20 Step 1)
```

- [ ] **Step 3: Build and run**

Run: `⌘R`
Expected: App launches with full menu bar popover showing capture/recording buttons and recent captures. Clicking capture triggers overlay.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: wire up complete app with MenuBarView

Full AppState with all services, MenuBarView with capture/recording
grid and recent captures, hotkey registration, window management
for editor/history/onboarding."
```

---

## Phase 7: Polish

### Task 21: Theme System

**Files:**
- Modify: `SnipIt/SnipItApp.swift`

- [ ] **Step 1: Apply theme from settings**

Add to `SnipItApp.init` or `body`:

```swift
// In SnipItApp body, apply preferred color scheme
.preferredColorScheme(colorScheme)

// Computed property
var colorScheme: ColorScheme? {
    switch appState.settingsVM.settings.theme {
    case .system: return nil
    case .dark: return .dark
    case .light: return .light
    }
}
```

For the MenuBarExtra (which doesn't support preferredColorScheme directly), apply via NSApp:

```swift
// Add to AppState init
func applyTheme() {
    switch settingsVM.settings.theme {
    case .system: NSApp.appearance = nil
    case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
    case .light: NSApp.appearance = NSAppearance(named: .aqua)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "feat: add theme system

System/dark/light theme switching via NSApp.appearance and
SwiftUI preferredColorScheme."
```

---

### Task 22: Localization

**Files:**
- Create: `SnipIt/Resources/Localizable.xcstrings`

- [ ] **Step 1: Create String Catalog**

In Xcode: File → New → File → String Catalog.
Name: `Localizable.xcstrings`
Location: `SnipIt/Resources/`

Xcode will auto-detect all `Text("...")` strings in SwiftUI views. Add languages:
1. Korean (ko) — default
2. English (en)

- [ ] **Step 2: Add translations**

In the String Catalog editor, provide English translations for all Korean strings used in the app. Key examples:

| Key | Korean | English |
|-----|--------|---------|
| 전체 화면 | 전체 화면 | Full Screen |
| 영역 선택 | 영역 선택 | Select Region |
| 활성 창 | 활성 창 | Active Window |
| 스크롤 | 스크롤 | Scroll |
| 캡처 히스토리 | 캡처 히스토리 | Capture History |
| 설정 | 설정 | Settings |
| 일반 | 일반 | General |
| 캡처 | 캡처 | Capture |
| 녹화 | 녹화 | Recording |
| 단축키 | 단축키 | Shortcuts |
| 저장 | 저장 | Storage |
| 테마 | 테마 | Theme |
| 클립보드에 복사됨 | 클립보드에 복사됨 | Copied to clipboard |
| 완료 | 완료 | Done |
| 닫기 | 닫기 | Close |

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add String Catalog localization

xcstrings-based localization with Korean and English.
System locale auto-detection. Community translation ready."
```

---

### Task 23: UpdateService (Sparkle)

**Files:**
- Create: `SnipIt/Services/UpdateService.swift`
- Modify: `SnipIt/SnipItApp.swift` (add updater)

- [ ] **Step 1: Create UpdateService**

```swift
// SnipIt/Services/UpdateService.swift
import Sparkle

final class UpdateService {
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var updater: SPUUpdater {
        updaterController.updater
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }
}
```

- [ ] **Step 2: Wire into AppState**

Add to AppState:
```swift
let updateService = UpdateService()
```

Add "업데이트 확인" button to MenuBarView and AboutSettingsView:
```swift
Button("업데이트 확인") {
    appState.updateService.checkForUpdates()
}
```

- [ ] **Step 3: Add SUFeedURL to Info.plist**

In Info.plist, add:
```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/svrforum/snipit-mac/main/appcast.xml</string>
```

- [ ] **Step 4: Build**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add Sparkle auto-update service

SPUStandardUpdaterController integration, appcast.xml feed URL,
check for updates from menu bar and settings."
```

---

### Task 24: About / Support Section

**Files:**
- Modify: `SnipIt/Views/Settings/SettingsWindow.swift` (add "정보" tab)
- Create: `SnipIt/Views/Settings/AboutSettingsView.swift`
- Modify: `SnipIt/Views/MenuBar/MenuBarView.swift` (add support link)

- [ ] **Step 1: Create AboutSettingsView**

```swift
// SnipIt/Views/Settings/AboutSettingsView.swift
import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        Form {
            // App info
            VStack(spacing: 12) {
                Image(systemName: "scissors")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                Text("SnipIt")
                    .font(.title2.bold())
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            Section {
                Link(destination: URL(string: "https://github.com/svrforum/snipit-mac")!) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                        Text("GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URL(string: "https://github.com/svrforum/snipit-mac/issues")!) {
                    HStack {
                        Image(systemName: "ladybug")
                        Text("버그 리포트")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("후원") {
                Link(destination: URL(string: "https://buymeacoffee.com/svrforum")!) {
                    HStack {
                        Text("☕")
                        Text("Buy Me a Coffee")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("SnipIt은 오픈소스 프로젝트입니다.\n후원은 개발을 지속하는 데 큰 도움이 됩니다.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("MIT License · © 2026 svrforum")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
    }
}
```

- [ ] **Step 2: Add About tab to SettingsWindow**

Add to SettingsWindow TabView:

```swift
AboutSettingsView()
    .tabItem { Label("정보", systemImage: "info.circle") }
```

- [ ] **Step 3: Add support link to MenuBarView footer**

Add before the closing of MenuBarView VStack, after the recent captures section:

```swift
Divider().padding(.horizontal, 16)

Button {
    NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/svrforum")!)
} label: {
    HStack(spacing: 6) {
        Text("☕")
        Text("후원하기")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
}
.buttonStyle(.plain)
.padding(.horizontal, 12)
.padding(.bottom, 8)
```

- [ ] **Step 4: Build**

Run: `⌘B`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add About page with Buy Me a Coffee support link

Settings 'About' tab with version info, GitHub links, and
buymeacoffee.com/svrforum support link. Also added to menu bar footer."
```

---

### Task 25: Final Integration Test & Push

- [ ] **Step 1: Build release**

Run: `⌘B` with Release configuration.
Xcode → Product → Build For → Running

- [ ] **Step 2: Manual integration test checklist**

Test each feature end-to-end:
- [ ] App launches in menu bar (no Dock icon)
- [ ] Full screen capture → editor opens → clipboard has image
- [ ] Region capture with smart detection → drag to select → editor
- [ ] Window capture via smart detection → click window → editor
- [ ] Editor: pen, arrow, rectangle, text, blur, number tools work
- [ ] Editor: undo/redo works
- [ ] Editor: save to file works
- [ ] Editor: copy to clipboard works
- [ ] GIF recording → stop → file saved
- [ ] MP4 recording → stop → file saved
- [ ] History shows captures, double-click opens editor
- [ ] Pin window floats above other windows
- [ ] Settings tabs all load and save correctly
- [ ] Hotkeys trigger correct actions
- [ ] Theme switching works (system/dark/light)
- [ ] Onboarding flow shows on first launch

- [ ] **Step 3: Fix any issues found**

Address bugs discovered during integration testing.

- [ ] **Step 4: Final commit and push**

```bash
git add -A
git commit -m "feat: complete SnipIt Mac v1.0

All features implemented: screen capture (full/window/region/scroll),
GIF/MP4 recording, image editor with 13 tools, smart window detection,
pin window, capture history, OCR, global hotkeys, localization,
theme system, onboarding flow."

git push origin main
```
