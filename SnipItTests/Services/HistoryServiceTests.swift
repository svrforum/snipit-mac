import Testing
import Foundation
import AppKit
@testable import SnipIt

@Suite("HistoryService Tests")
struct HistoryServiceTests {

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

    private func makeTestImage(width: Int, height: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }

    @Test("Add capture and retrieve from history")
    func addAndRetrieve() async throws {
        let tempDir = try makeTempDirectory()
        defer { cleanup(tempDir) }

        let storage = StorageService(baseDirectory: tempDir)
        try storage.ensureDirectories()
        let history = HistoryService(storageService: storage)

        let image = makeTestImage(width: 100, height: 100)
        try await history.addCapture(image: image, mode: .fullScreen)

        #expect(history.items.count == 1)
        #expect(history.items[0].mode == .fullScreen)
        #expect(history.items[0].width == 100)
    }

    @Test("History enforces maximum of 100 items")
    func maxLimit() async throws {
        let tempDir = try makeTempDirectory()
        defer { cleanup(tempDir) }

        let storage = StorageService(baseDirectory: tempDir)
        try storage.ensureDirectories()
        let history = HistoryService(storageService: storage)

        let image = makeTestImage(width: 10, height: 10)
        for _ in 0..<105 {
            try await history.addCapture(image: image, mode: .region)
        }

        #expect(history.items.count == 100)
    }

    @Test("Delete item removes it from history")
    func deleteItem() async throws {
        let tempDir = try makeTempDirectory()
        defer { cleanup(tempDir) }

        let storage = StorageService(baseDirectory: tempDir)
        try storage.ensureDirectories()
        let history = HistoryService(storageService: storage)

        let image = makeTestImage(width: 50, height: 50)
        try await history.addCapture(image: image, mode: .window)

        #expect(history.items.count == 1)

        let item = history.items[0]
        history.deleteItem(item)

        #expect(history.items.isEmpty)
    }
}
