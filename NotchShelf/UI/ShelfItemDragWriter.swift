import AppKit

final class ScreenshotDragWriter: NSObject, NSPasteboardWriting {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        var types: [NSPasteboard.PasteboardType] = [.fileURL]

        if pngData != nil {
            types.append(.png)
        }

        if tiffData != nil {
            types.append(.tiff)
        }

        return types
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .fileURL:
            return fileURL.absoluteString
        case .png:
            return pngData
        case .tiff:
            return tiffData
        default:
            return nil
        }
    }

    private lazy var pngData: Data? = {
        if fileURL.pathExtension.lowercased() == "png" {
            return try? Data(contentsOf: fileURL)
        }

        return NSImage(contentsOf: fileURL)?.pngData()
    }()

    private lazy var tiffData: Data? = {
        NSImage(contentsOf: fileURL)?.tiffRepresentation
    }()
}
