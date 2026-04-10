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
    var launchAtLogin: Bool = false
    var playSound: Bool = true
    var openEditorAfterCapture: Bool = true
    var autoCopyToClipboard: Bool = true
    var language: String = "ko"
    var theme: AppTheme = .system
    var dimmingOpacity: Double = 0.3
    var defaultImageFormat: ImageFormat = .png
    var includeCursor: Bool = false
    var recordingFPS: RecordingFPS = .thirty
    var gifQuality: GifQuality = .original
    var gifMaxWidth: GifMaxWidth = .w480
    var videoCodec: VideoCodec = .h264
    var maxRecordingDuration: TimeInterval = 30
    var showCountdown: Bool = true
    var showCursorInRecording: Bool = true
    var hotkeyFullScreen: HotkeyConfig = .fullScreenCapture
    var hotkeyRegion: HotkeyConfig = .regionCapture
    var hotkeyWindow: HotkeyConfig = .windowCapture
    var hotkeyScroll: HotkeyConfig = .scrollCapture
    var hotkeyGif: HotkeyConfig = .gifRecording
    var hotkeyMp4: HotkeyConfig = .mp4Recording
    var savePath: String = "~/Pictures/SnipIt"
    var fileNamePattern: String = "SnipIt_{date}_{time}"
}
