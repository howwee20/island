import Foundation

final class PersistenceService {
    private struct PersistedState: Codable {
        var items: [ScreenshotItem]
    }

    let rootDirectoryURL: URL
    let imagesDirectoryURL: URL
    let thumbnailsDirectoryURL: URL
    let stateFileURL: URL

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let root = baseURL.appendingPathComponent("NotchShelf", isDirectory: true)

        rootDirectoryURL = root
        imagesDirectoryURL = root.appendingPathComponent("Images", isDirectory: true)
        thumbnailsDirectoryURL = root.appendingPathComponent("Thumbnails", isDirectory: true)
        stateFileURL = root.appendingPathComponent("state.json", isDirectory: false)
    }

    func prepareStorage() throws {
        try fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: thumbnailsDirectoryURL, withIntermediateDirectories: true)
    }

    func loadItems() throws -> [ScreenshotItem] {
        guard fileManager.fileExists(atPath: stateFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: stateFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(PersistedState.self, from: data).items
    }

    func save(items: [ScreenshotItem]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let payload = PersistedState(items: items)
        let data = try encoder.encode(payload)
        try data.write(to: stateFileURL, options: .atomic)
    }

    func imageURL(for item: ScreenshotItem) -> URL {
        imagesDirectoryURL.appendingPathComponent(item.storedFilename, isDirectory: false)
    }

    func thumbnailURL(for item: ScreenshotItem) -> URL {
        thumbnailsDirectoryURL.appendingPathComponent(item.thumbnailFilename, isDirectory: false)
    }

    func removeFiles(for item: ScreenshotItem) {
        let fileURLs = [imageURL(for: item), thumbnailURL(for: item)]

        for fileURL in fileURLs where fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
}
