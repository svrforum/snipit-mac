import AppKit

enum ImageProcessor {

    /// Applies a mosaic (pixelation) effect to a rectangular region of the image.
    /// Divides the region into blocks of `blockSize` x `blockSize` pixels,
    /// samples the center pixel of each block, and fills the entire block with that color.
    static func applyMosaic(to image: NSImage, in rect: CGRect, blockSize: Int = 16) -> NSImage {
        let imageSize = image.size

        // Create a mutable copy
        let result = NSImage(size: imageSize)
        result.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: imageSize),
            from: NSRect(origin: .zero, size: imageSize),
            operation: .copy,
            fraction: 1.0
        )
        result.unlockFocus()

        // Get bitmap representation
        guard let tiffData = result.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return image
        }

        let pixelsWide = bitmap.pixelsWide
        let pixelsHigh = bitmap.pixelsHigh

        // Convert rect from image coordinate space to pixel space
        let scaleX = CGFloat(pixelsWide) / imageSize.width
        let scaleY = CGFloat(pixelsHigh) / imageSize.height

        let pixelRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.size.width * scaleX,
            height: rect.size.height * scaleY
        )

        let minX = max(0, Int(pixelRect.minX))
        let minY = max(0, Int(pixelRect.minY))
        let maxX = min(pixelsWide, Int(pixelRect.maxX))
        let maxY = min(pixelsHigh, Int(pixelRect.maxY))

        // Iterate over blocks
        var y = minY
        while y < maxY {
            var x = minX
            while x < maxX {
                let blockW = min(blockSize, maxX - x)
                let blockH = min(blockSize, maxY - y)

                // Sample center pixel of the block
                let centerX = min(x + blockW / 2, pixelsWide - 1)
                let centerY = min(y + blockH / 2, pixelsHigh - 1)

                guard let centerColor = bitmap.colorAt(x: centerX, y: centerY) else {
                    x += blockSize
                    continue
                }

                // Fill the entire block with the center pixel color
                for by in y..<(y + blockH) {
                    for bx in x..<(x + blockW) {
                        bitmap.setColor(centerColor, atX: bx, y: by)
                    }
                }

                x += blockSize
            }
            y += blockSize
        }

        // Construct final image from modified bitmap
        let mosaicImage = NSImage(size: imageSize)
        mosaicImage.addRepresentation(bitmap)
        return mosaicImage
    }
}
