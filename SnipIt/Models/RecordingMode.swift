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
