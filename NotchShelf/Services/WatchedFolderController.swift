import AppKit
import UniformTypeIdentifiers

final class WatchedFolderController {
    private let store: ScreenshotStore
    private let bookmarkStore: BookmarkStore
    private let fileManager: FileManager

    private var watcher: DirectoryWatcher?
    private var securityScopedURL: URL?

    private(set) var watchedFolderURL: URL? {
        didSet {
            onFolderChanged?(watchedFolderURL)
        }
    }

    var onFolderChanged: ((URL?) -> Void)?

    init(
        store: ScreenshotStore,
        bookmarkStore: BookmarkStore = BookmarkStore(),
        fileManager: FileManager = .default
    ) {
        self.store = store
        self.bookmarkStore = bookmarkStore
        self.fileManager = fileManager
    }

    func restoreSavedFolder() {
        guard let url = bookmarkStore.resolveBookmark() else {
            return
        }

        _ = startWatching(url: url, persistBookmark: false)
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Watch Folder"
        panel.message = "Choose a folder to auto-import new screenshots."

        NSApp.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        _ = startWatching(url: url, persistBookmark: true)
    }

    @discardableResult
    func startWatching(url: URL, persistBookmark: Bool) -> Bool {
        stopWatching(clearBookmark: false)

        if persistBookmark {
            try? bookmarkStore.saveBookmark(for: url)
        }

        let accessGranted = url.startAccessingSecurityScopedResource()
        if accessGranted {
            securityScopedURL = url
        }

        watchedFolderURL = url

        let watcher = DirectoryWatcher(url: url)
        watcher.onChange = { [weak self] in
            self?.scanFolder()
        }

        let didStart = watcher.start()
        self.watcher = watcher
        scanFolder()

        return didStart
    }

    func stopWatching(clearBookmark: Bool = true) {
        watcher?.stop()
        watcher = nil

        if let securityScopedURL {
            securityScopedURL.stopAccessingSecurityScopedResource()
            self.securityScopedURL = nil
        }

        watchedFolderURL = nil

        if clearBookmark {
            bookmarkStore.clear()
        }
    }

    private func scanFolder() {
        guard let folderURL = watchedFolderURL else {
            return
        }

        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]

        let urls = (try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        let sortedURLs = urls.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        for fileURL in sortedURLs.prefix(40) where isSupportedImageFile(fileURL) {
            _ = try? store.importImage(at: fileURL)
        }
    }

    private func isSupportedImageFile(_ url: URL) -> Bool {
        guard
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey]),
            values.isRegularFile == true
        else {
            return false
        }

        if let type = UTType(filenameExtension: url.pathExtension.lowercased()) {
            return type.conforms(to: .image)
        }

        return false
    }
}
