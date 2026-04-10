import AppKit
import Foundation

@Observable
final class HistoryService {

    // MARK: - Properties

    private let storageService: StorageService
    private let maxItems = 100

    private var indexURL: URL {
        storageService.historyDirectory.appendingPathComponent("index.json")
    }

    var items: [CaptureHistoryItem] = []

    // MARK: - Initialization

    init(storageService: StorageService) {
        self.storageService = storageService
        loadIndex()
    }

    // MARK: - Public Methods

    func addCapture(image: NSImage, mode: CaptureMode) async throws {
        let imageURL = try storageService.saveImage(image, format: .png)
        let thumbnailURL = try storageService.saveThumbnail(image)

        let item = CaptureHistoryItem(
            imagePath: imageURL.lastPathComponent,
            thumbnailPath: thumbnailURL.lastPathComponent,
            width: Int(image.size.width),
            height: Int(image.size.height),
            mode: mode
        )

        items.insert(item, at: 0)

        while items.count > maxItems {
            let removed = items.removeLast()
            deleteFiles(for: removed)
        }

        saveIndex()
    }

    func loadImage(for item: CaptureHistoryItem) -> NSImage? {
        let url = storageService.imagesDirectory
            .appendingPathComponent(item.imagePath)
        return NSImage(contentsOf: url)
    }

    func loadThumbnail(for item: CaptureHistoryItem) -> NSImage? {
        let url = storageService.thumbnailsDirectory
            .appendingPathComponent(item.thumbnailPath)
        return NSImage(contentsOf: url)
    }

    func deleteItem(_ item: CaptureHistoryItem) {
        items.removeAll { $0.id == item.id }
        deleteFiles(for: item)
        saveIndex()
    }

    func clearHistory() {
        for item in items {
            deleteFiles(for: item)
        }
        items.removeAll()
        saveIndex()
    }

    // MARK: - Private Methods

    private func loadIndex() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: indexURL.path) else { return }
        do {
            let data = try Data(contentsOf: indexURL)
            let decoder = JSONDecoder()
            items = try decoder.decode([CaptureHistoryItem].self, from: data)
        } catch {
            items = []
        }
    }

    private func saveIndex() {
        do {
            try storageService.ensureDirectories()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(items)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            // Silently fail; index will be rebuilt on next successful save
        }
    }

    private func deleteFiles(for item: CaptureHistoryItem) {
        let imageURL = storageService.imagesDirectory
            .appendingPathComponent(item.imagePath)
        let thumbnailURL = storageService.thumbnailsDirectory
            .appendingPathComponent(item.thumbnailPath)
        storageService.deleteFile(at: imageURL)
        storageService.deleteFile(at: thumbnailURL)
    }
}
