import AppKit
import AVFoundation
import CoreImage
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

// MARK: - RecordingError

enum RecordingError: Error, LocalizedError {
    case noDisplayFound
    case streamNotAvailable
    case assetWriterFailed(String)
    case gifEncodingFailed
    case alreadyRecording
    case notRecording
    case maxDurationReached

    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No display found for recording."
        case .streamNotAvailable:
            return "Screen capture stream could not be created."
        case .assetWriterFailed(let reason):
            return "Asset writer failed: \(reason)"
        case .gifEncodingFailed:
            return "Failed to encode GIF."
        case .alreadyRecording:
            return "Recording is already in progress."
        case .notRecording:
            return "No recording is in progress."
        case .maxDurationReached:
            return "Maximum recording duration reached."
        }
    }
}

// MARK: - StreamOutput

private final class StreamOutput: NSObject, SCStreamOutput, Sendable {
    let handler: @Sendable (CMSampleBuffer) -> Void

    init(handler: @escaping @Sendable (CMSampleBuffer) -> Void) {
        self.handler = handler
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen else { return }
        handler(sampleBuffer)
    }
}

// MARK: - RecordingService

actor RecordingService {

    // MARK: - Properties

    private var stream: SCStream?
    private var streamOutput: StreamOutput?

    // GIF state
    private var gifFrames: [(image: CGImage, timestamp: TimeInterval)] = []

    // MP4 state
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    // Shared state
    private var startTime: CMTime?
    private var recordingStartDate: Date?

    private(set) var isRecording = false
    private(set) var recordingMode: RecordingMode = .gif
    private(set) var frameCount = 0
    private(set) var recordingDuration: TimeInterval = 0

    private var fps: Int = 30
    private var gifQuality: GifQuality = .original
    private var videoCodec: VideoCodec = .h264
    private var maxDuration: TimeInterval = 300
    private var outputURL: URL?

    private let ciContext = CIContext()
    private var previousFrameHash: Int?

    // MARK: - Start Recording

    func startRecording(
        mode: RecordingMode,
        region: CGRect,
        display: SCDisplay,
        fps: Int = 30,
        gifQuality: GifQuality = .original,
        videoCodec: VideoCodec = .h264,
        maxDuration: TimeInterval = 300,
        outputDirectory: URL
    ) async throws {
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }

        // Configure state
        self.recordingMode = mode
        self.fps = fps
        self.gifQuality = gifQuality
        self.videoCodec = videoCodec
        self.maxDuration = maxDuration
        self.frameCount = 0
        self.recordingDuration = 0
        self.gifFrames = []
        self.startTime = nil
        self.previousFrameHash = nil
        self.recordingStartDate = Date()

        // Generate output URL
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let ext = mode == .gif ? "gif" : "mp4"
        let fileName = "SnipIt_\(timestamp).\(ext)"
        self.outputURL = outputDirectory.appendingPathComponent(fileName)

        // Set up SCStream
        let filter = SCContentFilter(display: display, excludingWindows: [])

        let configuration = SCStreamConfiguration()
        configuration.width = Int(region.width) * 2
        configuration.height = Int(region.height) * 2
        configuration.sourceRect = region
        configuration.showsCursor = true
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))

        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)

        let output = StreamOutput { [weak self] sampleBuffer in
            guard let self else { return }
            Task {
                await self.handleFrame(sampleBuffer)
            }
        }

        try stream.addStreamOutput(output, type: .screen, sampleBufferQueue: .global(qos: .userInitiated))

        self.stream = stream
        self.streamOutput = output

        // Set up asset writer for MP4
        if mode == .mp4 {
            try setupAssetWriter(
                width: Int(region.width) * 2,
                height: Int(region.height) * 2
            )
        }

        try await stream.startCapture()
        isRecording = true
    }

    // MARK: - Stop Recording

    func stopRecording() async throws -> URL? {
        guard isRecording else {
            throw RecordingError.notRecording
        }

        isRecording = false

        if let stream {
            try await stream.stopCapture()
        }
        self.stream = nil
        self.streamOutput = nil

        guard let outputURL else { return nil }

        switch recordingMode {
        case .gif:
            try encodeGif(to: outputURL)
        case .mp4:
            await finalizeVideo()
        }

        return outputURL
    }

    // MARK: - Cancel Recording

    func cancelRecording() async {
        isRecording = false

        if let stream {
            try? await stream.stopCapture()
        }
        self.stream = nil
        self.streamOutput = nil
        self.gifFrames = []

        // Clean up partial file
        if let outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }

        self.assetWriter?.cancelWriting()
        self.assetWriter = nil
        self.videoInput = nil
        self.pixelBufferAdaptor = nil
    }

    // MARK: - Frame Handling

    private func handleFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording else { return }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if startTime == nil {
            startTime = presentationTime
        }

        guard let startTime else { return }

        let elapsed = CMTimeGetSeconds(presentationTime) - CMTimeGetSeconds(startTime)
        recordingDuration = elapsed

        // Check max duration
        if elapsed >= maxDuration {
            Task {
                _ = try? await stopRecording()
            }
            return
        }

        switch recordingMode {
        case .gif:
            handleGifFrame(sampleBuffer, timestamp: elapsed)
        case .mp4:
            handleMp4Frame(sampleBuffer, presentationTime: presentationTime)
        }

        frameCount += 1
    }

    // MARK: - GIF Frame Handling

    private func handleGifFrame(_ sampleBuffer: CMSampleBuffer, timestamp: TimeInterval) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        guard let cgImage = ciContext.createCGImage(
            ciImage,
            from: CGRect(x: 0, y: 0, width: width, height: height)
        ) else { return }

        // Duplicate detection for skipFrames quality modes
        if gifQuality == .skipFrames || gifQuality == .skipFramesHalfSize {
            let hash = simpleFrameHash(cgImage)
            if hash == previousFrameHash {
                return
            }
            previousFrameHash = hash
        }

        let frameImage: CGImage
        if gifQuality == .skipFramesHalfSize {
            frameImage = downsampleImage(cgImage, scale: 0.5) ?? cgImage
        } else {
            frameImage = cgImage
        }

        gifFrames.append((image: frameImage, timestamp: timestamp))
    }

    // MARK: - MP4 Frame Handling

    private func handleMp4Frame(_ sampleBuffer: CMSampleBuffer, presentationTime: CMTime) {
        guard let videoInput, videoInput.isReadyForMoreMediaData else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let startTime else { return }

        let relativeTime = CMTimeSubtract(presentationTime, startTime)

        pixelBufferAdaptor?.append(imageBuffer, withPresentationTime: relativeTime)
    }

    // MARK: - GIF Encoding

    private func encodeGif(to url: URL) throws {
        guard !gifFrames.isEmpty else {
            throw RecordingError.gifEncodingFailed
        }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.gif.identifier as CFString,
            gifFrames.count,
            nil
        ) else {
            throw RecordingError.gifEncodingFailed
        }

        // Set GIF file properties (loop forever)
        let fileProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0
            ]
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        // Add each frame
        for i in 0..<gifFrames.count {
            let frame = gifFrames[i]
            let nextTimestamp = i + 1 < gifFrames.count ? gifFrames[i + 1].timestamp : frame.timestamp + (1.0 / Double(fps))
            let delay = nextTimestamp - frame.timestamp

            let frameProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFDelayTime as String: delay,
                    kCGImagePropertyGIFUnclampedDelayTime as String: delay,
                ]
            ]
            CGImageDestinationAddImage(destination, frame.image, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw RecordingError.gifEncodingFailed
        }
    }

    // MARK: - Asset Writer Setup

    private func setupAssetWriter(width: Int, height: Int) throws {
        guard let outputURL else {
            throw RecordingError.assetWriterFailed("No output URL")
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let codecType: AVVideoCodecType = videoCodec == .hevc ? .hevc : .h264

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: codecType,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width * height * 4,
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoMaxKeyFrameIntervalKey: fps * 2,
            ] as [String: Any],
        ]

        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoSettings
        )
        input.expectsMediaDataInRealTime = true

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )

        guard writer.canAdd(input) else {
            throw RecordingError.assetWriterFailed("Cannot add video input to asset writer")
        }

        writer.add(input)

        guard writer.startWriting() else {
            throw RecordingError.assetWriterFailed(writer.error?.localizedDescription ?? "Unknown error")
        }
        writer.startSession(atSourceTime: .zero)

        self.assetWriter = writer
        self.videoInput = input
        self.pixelBufferAdaptor = adaptor
    }

    // MARK: - Finalize Video

    private func finalizeVideo() async {
        videoInput?.markAsFinished()

        guard let assetWriter, assetWriter.status == .writing else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            assetWriter.finishWriting {
                continuation.resume()
            }
        }

        self.assetWriter = nil
        self.videoInput = nil
        self.pixelBufferAdaptor = nil
    }

    // MARK: - Helpers

    private func simpleFrameHash(_ image: CGImage) -> Int {
        // Sample a few pixels to detect duplicate frames quickly
        guard let data = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data)
        else { return 0 }

        let bytesPerRow = image.bytesPerRow
        let height = image.height
        let width = image.width

        var hash = 0
        let samplePoints = [
            (width / 4, height / 4),
            (width / 2, height / 2),
            (3 * width / 4, 3 * height / 4),
            (width / 4, 3 * height / 4),
            (3 * width / 4, height / 4),
        ]

        for (x, y) in samplePoints {
            let offset = y * bytesPerRow + x * 4
            let length = CFDataGetLength(data)
            guard offset + 3 < length else { continue }
            hash ^= Int(ptr[offset]) << 16
            hash ^= Int(ptr[offset + 1]) << 8
            hash ^= Int(ptr[offset + 2])
        }

        return hash
    }

    private func downsampleImage(_ image: CGImage, scale: CGFloat) -> CGImage? {
        let newWidth = Int(CGFloat(image.width) * scale)
        let newHeight = Int(CGFloat(image.height) * scale)

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage()
    }
}
