import AppKit
import CryptoKit
import UniformTypeIdentifiers

final class ScreenshotStore {
    static let didChangeNotification = Notification.Name("NotchShelf.ScreenshotStoreDidChange")

    private(set) var items: [ScreenshotItem] = []

    private let persistenceService: PersistenceService
    private let thumbnailService: ThumbnailService
    private let fileManager: FileManager
    private let maxRecentItems = 10

    init(
        persistenceService: PersistenceService = PersistenceService(),
        thumbnailService: ThumbnailService = ThumbnailService(),
        fileManager: FileManager = .default
    ) {
        self.persistenceService = persistenceService
        self.thumbnailService = thumbnailService
        self.fileManager = fileManager

        do {
            try persistenceService.prepareStorage()
            let loaded = try persistenceService.loadItems()
            items = loaded.filter { [persistenceService] item in
                fileManager.fileExists(atPath: persistenceService.imageURL(for: item).path)
            }
            try persist()
        } catch {
            items = []
        }
    }

    var pinnedItems: [ScreenshotItem] {
        items
            .filter(\.pinned)
            .sorted { $0.importedAt > $1.importedAt }
    }

    var recentItems: [ScreenshotItem] {
        items
            .filter { !$0.pinned }
            .sorted { $0.importedAt > $1.importedAt }
    }

    func fileURL(for item: ScreenshotItem) -> URL {
        persistenceService.imageURL(for: item)
    }

    func thumbnailURL(for item: ScreenshotItem) -> URL {
        persistenceService.thumbnailURL(for: item)
    }

    func thumbnailImage(for item: ScreenshotItem) -> NSImage? {
        let thumbURL = thumbnailURL(for: item)
        if let image = NSImage(contentsOf: thumbURL) {
            return image
        }

        return NSImage(contentsOf: fileURL(for: item))
    }

    @discardableResult
    func importFromPasteboard(_ pasteboard: NSPasteboard) -> Int {
        var importedCount = 0

        let urlOptions: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: urlOptions) as? [URL] {
            for fileURL in fileURLs {
                guard isSupportedImageFile(fileURL) else { continue }

                if (try? importImage(at: fileURL)) != nil {
                    importedCount += 1
                }
            }

            if importedCount > 0 {
                return importedCount
            }
        }

        if let image = NSImage(pasteboard: pasteboard), let pngData = image.pngData() {
            if (try? importImageData(pngData, originalFilename: "Dragged Screenshot.png", suggestedExtension: "png")) != nil {
                importedCount += 1
            }
            return importedCount
        }

        let directTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
        for type in directTypes {
            if let data = pasteboard.data(forType: type) {
                let suggestedExtension = type == .png ? "png" : "tiff"
                if (try? importImageData(data, originalFilename: "Dragged Screenshot.\(suggestedExtension)", suggestedExtension: suggestedExtension)) != nil {
                    importedCount += 1
                    break
                }
            }
        }

        return importedCount
    }

    @discardableResult
    func importFilePromises(from pasteboard: NSPasteboard, completion: @escaping (Int) -> Void) -> Bool {
        let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver] ?? []
        guard !receivers.isEmpty else {
            completion(0)
            return false
        }

        let destinationURL = persistenceService.rootDirectoryURL.appendingPathComponent("IncomingPromises", isDirectory: true)
        try? fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let group = DispatchGroup()
        let lock = NSLock()
        var importedCount = 0
        var receivedURLs: [URL] = []
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        for receiver in receivers {
            group.enter()
            receiver.receivePromisedFiles(atDestination: destinationURL, options: [:], operationQueue: operationQueue) { [weak self] fileURL, error in
                defer { group.leave() }
                guard let self, error == nil else { return }

                if (try? self.importImage(at: fileURL)) != nil {
                    lock.lock()
                    importedCount += 1
                    receivedURLs.append(fileURL)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            for receivedURL in receivedURLs {
                try? self.fileManager.removeItem(at: receivedURL)
            }
            completion(importedCount)
        }

        return true
    }

    @discardableResult
    func importImage(at url: URL) throws -> ScreenshotItem {
        let accessingSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessingSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        return try importImageData(
            data,
            originalFilename: url.lastPathComponent,
            suggestedExtension: url.pathExtension
        )
    }

    @discardableResult
    func importImageData(_ data: Data, originalFilename: String, suggestedExtension: String?) throws -> ScreenshotItem {
        guard NSImage(data: data) != nil else {
            throw ThumbnailError.unreadableImage
        }

        let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()

        if let existingIndex = items.firstIndex(where: { $0.dataHash == hash }) {
            items[existingIndex].importedAt = Date()
            try persistAndNotify()
            return items[existingIndex]
        }

        let resolvedExtension = Self.normalizedImageExtension(from: suggestedExtension) ?? "png"
        let fileName = "\(UUID().uuidString).\(resolvedExtension)"
        let thumbnailName = "\(UUID().uuidString).png"

        let item = ScreenshotItem(
            id: UUID(),
            originalFilename: originalFilename,
            storedFilename: fileName,
            thumbnailFilename: thumbnailName,
            importedAt: Date(),
            pinned: false,
            dataHash: hash
        )

        try data.write(to: persistenceService.imageURL(for: item), options: .atomic)

        let thumbnailData = try thumbnailService.makeThumbnailData(from: data)
        try thumbnailData.write(to: persistenceService.thumbnailURL(for: item), options: .atomic)

        items.append(item)
        evictOverflowingRecentsIfNeeded()
        try persistAndNotify()
        return item
    }

    func togglePinned(for itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].pinned.toggle()
        try? persistAndNotify()
    }

    func deleteItem(withID itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let item = items.remove(at: index)
        persistenceService.removeFiles(for: item)
        try? persistAndNotify()
    }

    func clearAllUnpinned() {
        let removedItems = items.filter { !$0.pinned }
        items.removeAll { !$0.pinned }
        removedItems.forEach { persistenceService.removeFiles(for: $0) }
        try? persistAndNotify()
    }

    func copyImageToPasteboard(itemID: UUID) {
        guard
            let item = items.first(where: { $0.id == itemID }),
            let image = NSImage(contentsOf: fileURL(for: item))
        else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    func revealInFinder(itemID: UUID) {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL(for: item)])
    }

    private func evictOverflowingRecentsIfNeeded() {
        let overflow = recentItems.dropFirst(maxRecentItems)
        guard !overflow.isEmpty else { return }

        let overflowIDs = Set(overflow.map(\.id))
        let removedItems = items.filter { overflowIDs.contains($0.id) }
        items.removeAll { overflowIDs.contains($0.id) }
        removedItems.forEach { persistenceService.removeFiles(for: $0) }
    }

    private func persistAndNotify() throws {
        try persist()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    private func persist() throws {
        try persistenceService.save(items: items.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }

            return lhs.importedAt > rhs.importedAt
        })
    }

    private func isSupportedImageFile(_ url: URL) -> Bool {
        let lowercasedExtension = url.pathExtension.lowercased()

        if let type = UTType(filenameExtension: lowercasedExtension), type.conforms(to: .image) {
            return true
        }

        return false
    }

    private static func normalizedImageExtension(from pathExtension: String?) -> String? {
        guard let pathExtension else {
            return nil
        }

        let candidate = pathExtension.lowercased()
        guard let type = UTType(filenameExtension: candidate), type.conforms(to: .image) else {
            return nil
        }

        return candidate
    }
}
