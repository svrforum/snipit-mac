import AppKit
import AVFoundation
import CoreImage
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers
// MARK: - RecordingError

enum RecordingError: Error, LocalizedError {
    case noDisplayFound, streamNotAvailable, assetWriterFailed(String)
    case gifEncodingFailed, alreadyRecording, notRecording, maxDurationReached

    var errorDescription: String? {
        switch self {
        case .noDisplayFound: return "No display found."
        case .streamNotAvailable: return "Stream not available."
        case .assetWriterFailed(let r): return "Asset writer: \(r)"
        case .gifEncodingFailed: return "GIF encoding failed."
        case .alreadyRecording: return "Already recording."
        case .notRecording: return "Not recording."
        case .maxDurationReached: return "Max duration reached."
        }
    }
}

// MARK: - StreamOutput

private final class StreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    let handler: @Sendable (CMSampleBuffer) -> Void
    init(handler: @escaping @Sendable (CMSampleBuffer) -> Void) {
        self.handler = handler
        super.init()
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        if type == .screen { handler(sampleBuffer) }
    }
}

// MARK: - RecordingService

final class RecordingService {

    private var stream: SCStream?
    private var streamOutput: StreamOutput?

    /// Progress callback (duration, frameCount) - called from background queue
    var onProgress: ((TimeInterval, Int) -> Void)?

    // GIF - store frames as compressed JPEG data instead of raw CGImage
    private var gifFrameData: [(jpegData: Data, width: Int, height: Int, timestamp: TimeInterval)] = []
    private let maxGifFrames = 300
    private var gifMaxWidth = 480

    // MP4
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    // Shared
    private var startTime: CMTime?
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

    // MARK: - Start

    func startRecording(
        mode: RecordingMode, region: CGRect, display: SCDisplay,
        fps: Int = 30, gifQuality: GifQuality = .original,
        gifMaxWidth: Int = 480, showCursor: Bool = true,
        videoCodec: VideoCodec = .h264, maxDuration: TimeInterval = 300,
        outputDirectory: URL
    ) async throws {
        guard !isRecording else { throw RecordingError.alreadyRecording }

        self.recordingMode = mode
        self.fps = fps
        self.gifQuality = gifQuality
        self.gifMaxWidth = gifMaxWidth
        self.videoCodec = videoCodec
        self.maxDuration = mode == .gif ? min(maxDuration, 30) : maxDuration
        self.frameCount = 0
        self.recordingDuration = 0
        self.gifFrameData = []
        self.startTime = nil

        let ext = mode == .gif ? "gif" : "mp4"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        self.outputURL = outputDirectory.appendingPathComponent("SnipIt_\(formatter.string(from: Date())).\(ext)")

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        // GIF: 1x low res. MP4: 2x Retina
        let scale = mode == .gif ? 1 : 2
        let effectiveFps = mode == .gif ? min(fps, 10) : fps
        config.width = Int(region.width) * scale
        config.height = Int(region.height) * scale
        config.sourceRect = region
        config.showsCursor = showCursor
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(effectiveFps))

        isRecording = true

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        let output = StreamOutput { [self] buffer in
            self.handleFrame(buffer)
        }
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.svrforum.SnipIt.recording", qos: .userInitiated))

        self.stream = stream
        self.streamOutput = output

        if mode == .mp4 {
            try setupAssetWriter(width: config.width, height: config.height)
        }

        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            stream.startCapture { error in
                if let error {
                    debugLog("startCapture FAILED: \(error)")
                    c.resume(throwing: error)
                } else {
                    debugLog("startCapture SUCCESS")
                    c.resume()
                }
            }
        }
    }

    // MARK: - Stop

    func stopRecording() async throws -> URL? {
        debugLog("stopRecording: frames=\(frameCount) gifFrames=\(gifFrameData.count)")
        guard isRecording else { throw RecordingError.notRecording }
        isRecording = false
        onProgress = nil

        // Capture references before clearing
        let capturedStream = stream
        let capturedOutput = streamOutput
        stream = nil
        streamOutput = nil

        // Stop stream on background queue with its own autorelease pool
        if let capturedStream {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                DispatchQueue.global().async {
                    autoreleasepool {
                        let sem = DispatchSemaphore(value: 0)
                        capturedStream.stopCapture { _ in sem.signal() }
                        _ = sem.wait(timeout: .now() + 3)
                        debugLog("stopCapture done")
                    }
                    // Keep refs alive until after autorelease pool drained
                    _ = capturedOutput
                    c.resume()
                }
            }
        }

        guard let outputURL else { return nil }

        // Encode on background queue
        switch recordingMode {
        case .gif:
            let frames = gifFrameData
            let currentFps = fps
            gifFrameData = [] // Free immediately
            debugLog("Encoding GIF with \(frames.count) frames...")
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    autoreleasepool {
                        do {
                            try Self.encodeGifStatic(frames: frames, fps: currentFps, to: outputURL)
                            debugLog("GIF saved: \(outputURL.lastPathComponent)")
                            c.resume()
                        } catch {
                            debugLog("GIF encode error: \(error)")
                            c.resume(throwing: error)
                        }
                    }
                }
            }
        case .mp4:
            await finalizeVideo()
        }

        debugLog("Recording complete: \(outputURL.lastPathComponent)")
        return outputURL
    }

    // MARK: - Cancel

    func cancelRecording() {
        isRecording = false
        onProgress = nil
        let s = stream
        let o = streamOutput
        stream = nil
        streamOutput = nil
        gifFrameData = []

        Task {
            if let s { try? await s.stopCapture() }
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { _ = o }
        }

        if let outputURL { try? FileManager.default.removeItem(at: outputURL) }
        assetWriter?.cancelWriting()
        assetWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
    }

    // MARK: - Frame Handling

    private func handleFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording, sampleBuffer.isValid else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if startTime == nil {
            startTime = pts
            debugLog("First frame received!")
        }
        guard let startTime else { return }

        let elapsed = CMTimeGetSeconds(pts) - CMTimeGetSeconds(startTime)
        recordingDuration = elapsed

        if elapsed >= maxDuration {
            Task { _ = try? await stopRecording() }
            return
        }

        switch recordingMode {
        case .gif:  handleGifFrame(sampleBuffer, timestamp: elapsed)
        case .mp4:  handleMp4Frame(sampleBuffer, presentationTime: pts)
        }

        frameCount += 1
        onProgress?(elapsed, frameCount)
    }

    private func handleGifFrame(_ sampleBuffer: CMSampleBuffer, timestamp: TimeInterval) {
        guard gifFrameData.count < maxGifFrames else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let w = CVPixelBufferGetWidth(imageBuffer)
        let h = CVPixelBufferGetHeight(imageBuffer)

        guard let cgImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: w, height: h)) else { return }

        // Downsample for GIF
        let targetW = min(w, gifMaxWidth)
        let scale = CGFloat(targetW) / CGFloat(w)
        let targetH = Int(CGFloat(h) * scale)

        let finalImage: CGImage
        if w > gifMaxWidth {
            finalImage = downsampleImage(cgImage, scale: scale) ?? cgImage
        } else {
            finalImage = cgImage
        }

        // Store as compressed data to save memory
        let bitmapRep = NSBitmapImageRep(cgImage: finalImage)
        guard let data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) else { return }

        gifFrameData.append((jpegData: data, width: targetW, height: targetH, timestamp: timestamp))
    }

    private func handleMp4Frame(_ sampleBuffer: CMSampleBuffer, presentationTime: CMTime) {
        guard let videoInput, videoInput.isReadyForMoreMediaData else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let startTime else { return }
        pixelBufferAdaptor?.append(imageBuffer, withPresentationTime: CMTimeSubtract(presentationTime, startTime))
    }

    // MARK: - GIF Encoding

    private static func encodeGifStatic(
        frames: [(jpegData: Data, width: Int, height: Int, timestamp: TimeInterval)],
        fps: Int,
        to url: URL
    ) throws {
        guard !frames.isEmpty else { throw RecordingError.gifEncodingFailed }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, frames.count, nil
        ) else { throw RecordingError.gifEncodingFailed }

        let fileProps: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]
        ]
        CGImageDestinationSetProperties(destination, fileProps as CFDictionary)

        for i in 0..<frames.count {
            autoreleasepool {
                let frame = frames[i]
                let nextTS = i + 1 < frames.count ? frames[i + 1].timestamp : frame.timestamp + (1.0 / Double(fps))
                let delay = max(nextTS - frame.timestamp, 0.02)

                let frameProps: [String: Any] = [
                    kCGImagePropertyGIFDictionary as String: [
                        kCGImagePropertyGIFDelayTime as String: delay,
                        kCGImagePropertyGIFUnclampedDelayTime as String: delay,
                    ]
                ]

                if let source = CGImageSourceCreateWithData(frame.jpegData as CFData, nil),
                   let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                    CGImageDestinationAddImage(destination, cgImage, frameProps as CFDictionary)
                }
            }
        }

        guard CGImageDestinationFinalize(destination) else { throw RecordingError.gifEncodingFailed }
    }

    // MARK: - Asset Writer

    private func setupAssetWriter(width: Int, height: Int) throws {
        guard let outputURL else { throw RecordingError.assetWriterFailed("No URL") }
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let codecType: AVVideoCodecType = videoCodec == .hevc ? .hevc : .h264
        let settings: [String: Any] = [
            AVVideoCodecKey: codecType, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width * height * 4,
                AVVideoExpectedSourceFrameRateKey: fps,
            ] as [String: Any],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else { throw RecordingError.assetWriterFailed("Cannot add input") }
        writer.add(input)
        guard writer.startWriting() else { throw RecordingError.assetWriterFailed(writer.error?.localizedDescription ?? "Unknown") }
        writer.startSession(atSourceTime: .zero)
        self.assetWriter = writer; self.videoInput = input; self.pixelBufferAdaptor = adaptor
    }

    private func finalizeVideo() async {
        videoInput?.markAsFinished()
        guard let assetWriter, assetWriter.status == .writing else { return }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            assetWriter.finishWriting { c.resume() }
        }
        self.assetWriter = nil; self.videoInput = nil; self.pixelBufferAdaptor = nil
    }

    // MARK: - Helpers

    private func downsampleImage(_ image: CGImage, scale: CGFloat) -> CGImage? {
        let w = Int(CGFloat(image.width) * scale)
        let h = Int(CGFloat(image.height) * scale)
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }
}
