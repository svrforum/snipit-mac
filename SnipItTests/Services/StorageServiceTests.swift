import Testing
import Foundation
@testable import SnipIt

@Suite("StorageService Tests")
struct StorageServiceTests {

    private func makeTempDirectory() throws -> URL {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnipItTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temp,
            withIntermediateDirectories: true
        )
        return temp
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("Settings round-trip preserves values")
    func settingsRoundTrip() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanup(tempDir) }

        let service = StorageService(baseDirectory: tempDir)
        try service.ensureDirectories()

        var settings = AppSettings()
        settings.launchAtLogin = true
        settings.playSound = false
        settings.theme = .dark
        settings.defaultImageFormat = .jpg
        settings.dimmingOpacity = 0.5
        settings.savePath = "/tmp/custom"

        try service.saveSettings(settings)
        let loaded = try service.loadSettings()

        #expect(loaded == settings)
        #expect(loaded.launchAtLogin == true)
        #expect(loaded.playSound == false)
        #expect(loaded.theme == .dark)
        #expect(loaded.defaultImageFormat == .jpg)
        #expect(loaded.dimmingOpacity == 0.5)
        #expect(loaded.savePath == "/tmp/custom")
    }

    @Test("Load returns default settings when no file exists")
    func defaultSettings() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanup(tempDir) }

        let service = StorageService(baseDirectory: tempDir)
        let settings = try service.loadSettings()

        #expect(settings == AppSettings())
        #expect(settings.launchAtLogin == false)
        #expect(settings.theme == .system)
        #expect(settings.defaultImageFormat == .png)
    }

    @Test("ensureDirectories creates expected directory structure")
    func directoryCreation() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanup(tempDir) }

        let service = StorageService(baseDirectory: tempDir)
        try service.ensureDirectories()

        let fileManager = FileManager.default
        var isDir: ObjCBool = false

        #expect(fileManager.fileExists(atPath: service.historyDirectory.path, isDirectory: &isDir))
        #expect(isDir.boolValue)

        isDir = false
        #expect(fileManager.fileExists(atPath: service.imagesDirectory.path, isDirectory: &isDir))
        #expect(isDir.boolValue)

        isDir = false
        #expect(fileManager.fileExists(atPath: service.thumbnailsDirectory.path, isDirectory: &isDir))
        #expect(isDir.boolValue)

        isDir = false
        #expect(fileManager.fileExists(atPath: service.recordingsDirectory.path, isDirectory: &isDir))
        #expect(isDir.boolValue)
    }
}
