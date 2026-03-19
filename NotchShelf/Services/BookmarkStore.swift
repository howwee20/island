import Foundation

final class BookmarkStore {
    private let defaults: UserDefaults
    private let bookmarkKey = "NotchShelf.WatchedFolderBookmark"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(bookmarkData, forKey: bookmarkKey)
    }

    func resolveBookmark() -> URL? {
        guard let bookmarkData = defaults.data(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false

        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            defaults.removeObject(forKey: bookmarkKey)
            return nil
        }

        if isStale {
            try? saveBookmark(for: url)
        }

        return url
    }

    func clear() {
        defaults.removeObject(forKey: bookmarkKey)
    }
}
