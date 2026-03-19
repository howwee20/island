import AppKit

@main
final class NotchShelfApp: NSObject, NSApplicationDelegate {
    private var store: ScreenshotStore!
    private var watchedFolderController: WatchedFolderController!
    private var shelfWindowController: ShelfWindowController!
    private var statusItemController: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        store = ScreenshotStore()
        watchedFolderController = WatchedFolderController(store: store)
        shelfWindowController = ShelfWindowController(store: store)
        statusItemController = StatusItemController(
            store: store,
            watchedFolderController: watchedFolderController,
            windowController: shelfWindowController
        )

        watchedFolderController.restoreSavedFolder()
        shelfWindowController.showShelf()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        shelfWindowController.showShelf()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        watchedFolderController.stopWatching(clearBookmark: false)
        _ = statusItemController
    }
}
