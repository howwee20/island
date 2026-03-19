import AppKit

enum ThumbnailError: Error {
    case unreadableImage
    case encodingFailed
}

final class ThumbnailService {
    func makeThumbnailData(from data: Data, maxDimension: CGFloat = 240) throws -> Data {
        guard let image = NSImage(data: data) else {
            throw ThumbnailError.unreadableImage
        }

        return try makeThumbnailData(from: image, maxDimension: maxDimension)
    }

    func makeThumbnailImage(from imageURL: URL, maxDimension: CGFloat = 240) throws -> NSImage {
        guard let image = NSImage(contentsOf: imageURL) else {
            throw ThumbnailError.unreadableImage
        }

        return try resizedImage(from: image, maxDimension: maxDimension)
    }

    private func makeThumbnailData(from image: NSImage, maxDimension: CGFloat) throws -> Data {
        let resized = try resizedImage(from: image, maxDimension: maxDimension)
        guard
            let tiffData = resized.tiffRepresentation,
            let representation = NSBitmapImageRep(data: tiffData),
            let pngData = representation.representation(using: .png, properties: [:])
        else {
            throw ThumbnailError.encodingFailed
        }

        return pngData
    }

    private func resizedImage(from image: NSImage, maxDimension: CGFloat) throws -> NSImage {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else {
            throw ThumbnailError.unreadableImage
        }

        let scale = min(maxDimension / max(originalSize.width, originalSize.height), 1)
        let targetSize = NSSize(
            width: max(1, floor(originalSize.width * scale)),
            height: max(1, floor(originalSize.height * scale))
        )

        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(targetSize.width),
                pixelsHigh: Int(targetSize.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            throw ThumbnailError.encodingFailed
        }

        let context = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: targetSize)).fill()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.restoreGraphicsState()

        let resizedImage = NSImage(size: targetSize)
        resizedImage.addRepresentation(bitmap)
        return resizedImage
    }
}
