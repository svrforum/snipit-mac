import Foundation

struct CaptureHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let imagePath: String
    let thumbnailPath: String
    let width: Int
    let height: Int
    let mode: CaptureMode

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        imagePath: String,
        thumbnailPath: String,
        width: Int,
        height: Int,
        mode: CaptureMode
    ) {
        self.id = id
        self.timestamp = timestamp
        self.imagePath = imagePath
        self.thumbnailPath = thumbnailPath
        self.width = width
        self.height = height
        self.mode = mode
    }
}
