import AppKit
import CoreGraphics
import ScreenCaptureKit
import Vision

// MARK: - ScrollCaptureError

enum ScrollCaptureError: Error, LocalizedError {
    case noDisplayFound
    case captureRegionInvalid
    case noFramesCaptured
    case stitchingFailed

    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "No display found for scroll capture."
        case .captureRegionInvalid:
            return "The scroll capture region is invalid."
        case .noFramesCaptured:
            return "No frames were captured during scrolling."
        case .stitchingFailed:
            return "Failed to stitch captured frames together."
        }
    }
}

// MARK: - ScrollCaptureService

actor ScrollCaptureService {

    // MARK: - Properties

    private let screenCaptureService = ScreenCaptureService()

    // MARK: - Scrolling Capture

    /// Captures a scrollable region by simulating scroll events and stitching the results.
    func captureScrolling(
        display: SCDisplay,
        region: CGRect,
        scrollAmount: Int32 = -3,
        maxScrolls: Int = 20
    ) async throws -> NSImage {
        guard region.width > 0, region.height > 0 else {
            throw ScrollCaptureError.captureRegionInvalid
        }

        // Capture the initial frame
        let initialFrame = try await screenCaptureService.captureRegion(
            display: display,
            rect: region
        )

        var frames: [NSImage] = [initialFrame]
        var previousFrame = initialFrame

        for _ in 0..<maxScrolls {
            // Simulate a scroll event at the center of the region
            let scrollPoint = CGPoint(
                x: region.midX,
                y: region.midY
            )

            guard let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 1,
                wheel1: scrollAmount,
                wheel2: 0,
                wheel3: 0
            ) else { continue }

            scrollEvent.location = scrollPoint
            scrollEvent.post(tap: .cghidEventTap)

            // Wait for the scroll animation to settle
            try await Task.sleep(nanoseconds: 300_000_000) // 300ms

            // Capture the new frame
            let currentFrame = try await screenCaptureService.captureRegion(
                display: display,
                rect: region
            )

            // Check if the content has stopped scrolling (identical frames)
            if framesAreIdentical(previousFrame, currentFrame) {
                break
            }

            frames.append(currentFrame)
            previousFrame = currentFrame
        }

        guard frames.count > 1 else {
            return frames.first ?? initialFrame
        }

        return try await stitchImages(frames)
    }

    // MARK: - Image Stitching

    /// Stitches an array of overlapping images into a single tall image.
    func stitchImages(_ images: [NSImage]) async throws -> NSImage {
        guard !images.isEmpty else {
            throw ScrollCaptureError.noFramesCaptured
        }

        guard images.count > 1 else {
            return images[0]
        }

        // Calculate overlaps between consecutive frames
        var overlaps: [CGFloat] = []
        for i in 0..<(images.count - 1) {
            let overlap = try await findOverlap(top: images[i], bottom: images[i + 1])
            overlaps.append(overlap)
        }

        // Calculate total height
        let imageWidth = images[0].size.width
        let firstHeight = images[0].size.height
        var totalHeight = firstHeight

        for i in 1..<images.count {
            let frameHeight = images[i].size.height
            let overlap = overlaps[i - 1]
            totalHeight += frameHeight - overlap
        }

        // Create the stitched image
        let stitchedImage = NSImage(size: NSSize(width: imageWidth, height: totalHeight))
        stitchedImage.lockFocus()

        // Draw images from top to bottom
        // In AppKit, Y=0 is at the bottom, so we draw from the top (totalHeight) downward
        var currentY = totalHeight - firstHeight

        images[0].draw(
            in: NSRect(x: 0, y: currentY, width: imageWidth, height: firstHeight),
            from: NSRect(origin: .zero, size: images[0].size),
            operation: .copy,
            fraction: 1.0
        )

        for i in 1..<images.count {
            let frameHeight = images[i].size.height
            let overlap = overlaps[i - 1]
            currentY -= (frameHeight - overlap)

            images[i].draw(
                in: NSRect(x: 0, y: currentY, width: imageWidth, height: frameHeight),
                from: NSRect(origin: .zero, size: images[i].size),
                operation: .copy,
                fraction: 1.0
            )
        }

        stitchedImage.unlockFocus()

        guard stitchedImage.isValid else {
            throw ScrollCaptureError.stitchingFailed
        }

        return stitchedImage
    }

    // MARK: - Overlap Detection

    /// Finds the vertical overlap between the bottom of the top image and the top of the bottom image.
    /// Uses Vision feature prints to compare strips of pixels.
    func findOverlap(top: NSImage, bottom: NSImage) async throws -> CGFloat {
        let imageHeight = top.size.height
        let imageWidth = top.size.width

        // Check strips from largest overlap to smallest
        let minOverlap: CGFloat = 10
        let maxOverlap = imageHeight * 0.8
        let stripHeight: CGFloat = max(20, imageHeight * 0.05)
        let step: CGFloat = max(5, stripHeight * 0.5)

        var bestOverlap: CGFloat = 0
        var bestSimilarity: Float = 0
        let similarityThreshold: Float = 0.05  // Lower distance = more similar

        var y = minOverlap
        while y <= maxOverlap {
            // The strip starts at (imageHeight - y) from the bottom of the top image
            let topCropRect = CGRect(
                x: 0,
                y: imageHeight - y,
                width: imageWidth,
                height: stripHeight
            )

            // Extract a strip from the top of the bottom image at offset y
            let bottomCropRect = CGRect(
                x: 0,
                y: imageHeight - stripHeight,
                width: imageWidth,
                height: stripHeight
            )

            // Create cropped images
            let topStrip = cropImage(top, to: topCropRect)
            let bottomStrip = cropImage(bottom, to: bottomCropRect)

            // Compare using Vision feature prints
            do {
                let similarity = try computeSimilarity(topStrip, bottomStrip)
                if similarity < similarityThreshold && (bestOverlap == 0 || similarity < bestSimilarity) {
                    bestSimilarity = similarity
                    bestOverlap = y
                }
            } catch {
                // Skip this strip on error
            }

            y += step
        }

        return bestOverlap
    }

    // MARK: - Similarity Computation

    /// Computes the distance between two images using VNFeaturePrintObservation.
    /// Returns a float where lower values indicate higher similarity.
    func computeSimilarity(_ image1: NSImage, _ image2: NSImage) throws -> Float {
        let featurePrint1 = try generateFeaturePrint(for: image1)
        let featurePrint2 = try generateFeaturePrint(for: image2)

        var distance: Float = 0
        try featurePrint1.computeDistance(&distance, to: featurePrint2)
        return distance
    }

    // MARK: - Frame Comparison

    /// Checks whether two frames are pixel-identical by comparing their TIFF data.
    func framesAreIdentical(_ frame1: NSImage, _ frame2: NSImage) -> Bool {
        guard let data1 = frame1.tiffRepresentation,
              let data2 = frame2.tiffRepresentation
        else {
            return false
        }
        return data1 == data2
    }

    // MARK: - Private Helpers

    private func generateFeaturePrint(for image: NSImage) throws -> VNFeaturePrintObservation {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ScrollCaptureError.stitchingFailed
        }

        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first else {
            throw ScrollCaptureError.stitchingFailed
        }

        return result
    }

    private func cropImage(_ image: NSImage, to rect: CGRect) -> NSImage {
        let cropped = NSImage(size: rect.size)
        cropped.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: rect.size),
            from: NSRect(origin: rect.origin, size: rect.size),
            operation: .copy,
            fraction: 1.0
        )
        cropped.unlockFocus()
        return cropped
    }
}
