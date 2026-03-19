import AppKit

final class StatusItemController: NSObject, NSMenuDelegate {
    private let store: ScreenshotStore
    private let watchedFolderController: WatchedFolderController
    private weak var windowController: ShelfWindowController?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()

    private let showShelfItem = NSMenuItem(title: "Show Shelf", action: #selector(showShelf), keyEquivalent: "")
    private let watchFolderItem = NSMenuItem(title: "Watch Screenshot Folder…", action: #selector(chooseFolder), keyEquivalent: "")
    private let stopWatchingItem = NSMenuItem(title: "Stop Watching Folder", action: #selector(stopWatching), keyEquivalent: "")
    private let currentFolderItem = NSMenuItem(title: "No folder selected", action: nil, keyEquivalent: "")
    private let clearItem = NSMenuItem(title: "Clear All Unpinned", action: #selector(clearAllUnpinned), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit NotchShelf", action: #selector(quit), keyEquivalent: "q")

    init(
        store: ScreenshotStore,
        watchedFolderController: WatchedFolderController,
        windowController: ShelfWindowController
    ) {
        self.store = store
        self.watchedFolderController = watchedFolderController
        self.windowController = windowController
        super.init()

        configureStatusItem()
        configureMenu()

        watchedFolderController.onFolderChanged = { [weak self] url in
            self?.updateFolderDisplay(with: url)
        }
        updateFolderDisplay(with: watchedFolderController.watchedFolderURL)
    }

    private func configureStatusItem() {
        statusItem.button?.image = NSImage(systemSymbolName: "photo.stack", accessibilityDescription: "NotchShelf")
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.contentTintColor = .labelColor
        statusItem.menu = menu
    }

    private func configureMenu() {
        menu.delegate = self

        currentFolderItem.isEnabled = false

        let items = [
            showShelfItem,
            .separator(),
            watchFolderItem,
            stopWatchingItem,
            currentFolderItem,
            .separator(),
            clearItem,
            .separator(),
            quitItem
        ]

        for item in items {
            item.target = self
            menu.addItem(item)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateFolderDisplay(with: watchedFolderController.watchedFolderURL)
    }

    private func updateFolderDisplay(with url: URL?) {
        if let url {
            currentFolderItem.title = "Watching: \(url.lastPathComponent)"
            stopWatchingItem.isEnabled = true
        } else {
            currentFolderItem.title = "No folder selected"
            stopWatchingItem.isEnabled = false
        }
    }

    @objc
    private func showShelf() {
        windowController?.showShelf()
    }

    @objc
    private func chooseFolder() {
        watchedFolderController.chooseFolder()
        windowController?.showShelf()
    }

    @objc
    private func stopWatching() {
        watchedFolderController.stopWatching()
    }

    @objc
    private func clearAllUnpinned() {
        store.clearAllUnpinned()
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}
