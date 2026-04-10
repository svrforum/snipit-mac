import AppKit
import Foundation

@Observable
final class HistoryViewModel {

    // MARK: - Dependencies

    private let historyService: HistoryService

    // MARK: - State

    var items: [CaptureHistoryItem] {
        historyService.items
    }

    // MARK: - Initialization

    init(historyService: HistoryService) {
        self.historyService = historyService
    }

    // MARK: - Public Methods

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
