import Testing
import Foundation
@testable import SnipIt

@Suite("AppSettings Tests")
struct AppSettingsTests {

    @Test("Default values are correct")
    func defaultValues() {
        let settings = AppSettings()

        #expect(settings.launchAtLogin == false)
        #expect(settings.playSound == true)
        #expect(settings.openEditorAfterCapture == true)
        #expect(settings.autoCopyToClipboard == true)
        #expect(settings.language == "en")
        #expect(settings.theme == .system)
        #expect(settings.dimmingOpacity == 0.3)
        #expect(settings.defaultImageFormat == .png)
        #expect(settings.includeCursor == false)
        #expect(settings.recordingFPS == .thirty)
        #expect(settings.gifQuality == .original)
        #expect(settings.videoCodec == .h264)
        #expect(settings.maxRecordingDuration == 300)
        #expect(settings.hotkeyFullScreen == .fullScreenCapture)
        #expect(settings.hotkeyRegion == .regionCapture)
        #expect(settings.hotkeyWindow == .windowCapture)
        #expect(settings.hotkeyScroll == .scrollCapture)
        #expect(settings.hotkeyGif == .gifRecording)
        #expect(settings.hotkeyMp4 == .mp4Recording)
        #expect(settings.savePath == "~/Pictures/SnipIt")
        #expect(settings.fileNamePattern == "SnipIt_{date}_{time}")
    }

    @Test("Codable round-trip preserves values")
    func codableRoundTrip() throws {
        var settings = AppSettings()
        settings.launchAtLogin = true
        settings.playSound = false
        settings.theme = .dark
        settings.defaultImageFormat = .jpg
        settings.recordingFPS = .sixty
        settings.gifQuality = .skipFramesHalfSize
        settings.videoCodec = .hevc
        settings.maxRecordingDuration = 120
        settings.savePath = "/tmp/test"
        settings.fileNamePattern = "test_{date}"

        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSettings.self, from: data)

        #expect(decoded == settings)
    }
}
