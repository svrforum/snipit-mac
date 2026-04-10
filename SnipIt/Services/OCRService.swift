import AppKit
import Vision

// MARK: - OCR Types

struct OCRResult {
    let fullText: String
    let lines: [OCRLine]
}

struct OCRLine {
    let text: String
    let boundingBox: CGRect
    let words: [OCRWord]
}

struct OCRWord {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}

// MARK: - OCRError

enum OCRError: Error, LocalizedError {
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert NSImage to CGImage for OCR processing."
        }
    }
}

// MARK: - OCRService

actor OCRService {

    // MARK: - Text Extraction

    /// Extracts text from an image using Vision framework with accurate recognition.
    func extractText(from image: NSImage, language: [String]? = nil) async throws -> OCRResult {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageConversionFailed
        }

        let imageHeight = CGFloat(cgImage.height)
        let imageWidth = CGFloat(cgImage.width)

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = language ?? ["ko-KR", "en-US", "ja-JP", "zh-Hans"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return OCRResult(fullText: "", lines: [])
        }

        var lines: [OCRLine] = []

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            // Convert normalized bounding box to image coordinates (flip Y axis)
            let normalizedBox = observation.boundingBox
            let lineBoundingBox = CGRect(
                x: normalizedBox.origin.x * imageWidth,
                y: (1.0 - normalizedBox.origin.y - normalizedBox.height) * imageHeight,
                width: normalizedBox.width * imageWidth,
                height: normalizedBox.height * imageHeight
            )

            let text = topCandidate.string
            var words: [OCRWord] = []

            // Extract individual word bounding boxes
            let wordRange = text.startIndex..<text.endIndex
            if (try? topCandidate.boundingBox(for: wordRange)) != nil {
                // Split text into words and attempt per-word bounding boxes
                let wordTexts = text.split(separator: " ")
                var currentIndex = text.startIndex

                for wordText in wordTexts {
                    guard let range = text.range(
                        of: String(wordText),
                        range: currentIndex..<text.endIndex
                    ) else { continue }

                    let wordBoundingBox: CGRect
                    if let wordRect = try? topCandidate.boundingBox(for: range) {
                        let normalizedWordBox = wordRect.boundingBox
                        wordBoundingBox = CGRect(
                            x: normalizedWordBox.origin.x * imageWidth,
                            y: (1.0 - normalizedWordBox.origin.y - normalizedWordBox.height) * imageHeight,
                            width: normalizedWordBox.width * imageWidth,
                            height: normalizedWordBox.height * imageHeight
                        )
                    } else {
                        wordBoundingBox = lineBoundingBox
                    }

                    words.append(OCRWord(
                        text: String(wordText),
                        boundingBox: wordBoundingBox,
                        confidence: topCandidate.confidence
                    ))

                    currentIndex = range.upperBound
                }
            } else {
                // Fallback: single word covering entire line
                words.append(OCRWord(
                    text: text,
                    boundingBox: lineBoundingBox,
                    confidence: topCandidate.confidence
                ))
            }

            lines.append(OCRLine(
                text: text,
                boundingBox: lineBoundingBox,
                words: words
            ))
        }

        let fullText = lines.map(\.text).joined(separator: "\n")
        return OCRResult(fullText: fullText, lines: lines)
    }

    // MARK: - Available Languages

    /// Returns the list of supported recognition languages for the accurate recognition level.
    func availableLanguages() -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        do {
            return try request.supportedRecognitionLanguages()
        } catch {
            return ["en-US"]
        }
    }
}
