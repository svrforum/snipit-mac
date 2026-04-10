import Foundation

enum CaptureMode: String, Codable, CaseIterable {
    case fullScreen
    case window
    case region
    case scroll
}
