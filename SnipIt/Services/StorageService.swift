import AppKit
import Foundation

// MARK: - StorageError

enum StorageError: Error, LocalizedError {
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to the requested format."
        }
    }
}

// MARK: - StorageService

@Observable
final class StorageService {

    // MARK: - Properties

    let baseDirectory: URL

    var settingsURL: URL {
        baseDirectory.appendingPathComponent("settings.json")
    }

    var historyDirectory: URL {
        baseDirectory.appendingPathComponent("History")
    }

    var imagesDirectory: URL {
        baseDirectory.appendingPathComponent("Images")
    }

    var thumbnailsDirectory: URL {
        baseDirectory.appendingPathComponent("Thumbnails")
    }

    var recordingsDirectory: URL {
        baseDirectory.appendingPathComponent("Recordings")
    }

    // MARK: - Initialization

    init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            self.baseDirectory = appSupport.appendingPathComponent("SnipIt")
        }
    }

    // MARK: - Directory Management

    func ensureDirectories() throws {
        let directories = [
            baseDirectory,
            historyDirectory,
            imagesDirectory,
            thumbnailsDirectory,
            recordingsDirectory,
        ]
        let fileManager = FileManager.default
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
            }
        }
    }

    // MARK: - Settings

    func saveSettings(_ settings: AppSettings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    func loadSettings() throws -> AppSettings {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: settingsURL.path) else {
            return AppSettings()
        }
        let data = try Data(contentsOf: settingsURL)
        let decoder = JSONDecoder()
        return try decoder.decode(AppSettings.self, from: data)
    }

    // MARK: - Image Storage

    func saveImage(_ image: NSImage, format: ImageFormat) throws -> URL {
        try ensureDirectories()
        let fileName = generateFileName(format: format)
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        let data: Data?
        switch format {
        case .png:
            data = image.pngRepresentation()
        case .jpg:
            data = image.jpegRepresentation(compressionFactor: 0.9)
        case .pdf:
            data = image.pdfRepresentation()
        }

        guard let imageData = data else {
            throw StorageError.imageConversionFailed
        }

        try imageData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func saveThumbnail(_ image: NSImage) throws -> URL {
        try ensureDirectories()
        let thumbnailSize = NSSize(width: 160, height: 100)
        let thumbnailImage = NSImage(size: thumbnailSize)
        thumbnailImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: thumbnailSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        thumbnailImage.unlockFocus()

        guard let data = thumbnailImage.jpegRepresentation(compressionFactor: 0.7) else {
            throw StorageError.imageConversionFailed
        }

        let fileName = generateFileName(format: .jpg)
        let fileURL = thumbnailsDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    // MARK: - File Management

    func deleteFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Helpers

    func generateFileName(format: ImageFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "SnipIt_\(timestamp).\(format.rawValue)"
    }
}

// MARK: - NSImage Extensions

private extension NSImage {

    func pngRepresentation() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData)
        else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    func jpegRepresentation(compressionFactor: CGFloat) -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData)
        else { return nil }
        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionFactor]
        )
    }

    func pdfRepresentation() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData)
        else { return nil }
        let pdfData = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: size)
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return nil }
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        bitmap.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
        return pdfData as Data
    }
}
