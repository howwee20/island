import AppKit

@main
final class NotchShelfApp: NSObject, NSApplicationDelegate {
    private var store: ScreenshotStore!
    private var watchedFolderController: WatchedFolderController!
    private var shelfWindowController: ShelfWindowController!
    private var statusItemController: StatusItemController!
    private var debugWindowController: DebugWindowController!
    private var globalHotkeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        store = ScreenshotStore()
        watchedFolderController = WatchedFolderController(store: store)
        shelfWindowController = ShelfWindowController(store: store)
        statusItemController = StatusItemController(
            store: store,
            watchedFolderController: watchedFolderController,
            windowController: shelfWindowController
        )

        // Debug window — always visible on launch
        debugWindowController = DebugWindowController(shelfWindowController: shelfWindowController)

        watchedFolderController.restoreSavedFolder()
        presentWindows()

        // Global hotkey: Control+Option+N toggles shelf
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == [.control, .option], event.charactersIgnoringModifiers == "n" {
                DispatchQueue.main.async {
                    self?.shelfWindowController.toggleShelf()
                }
            }
        }

        debugWindowController.log("App launched — activation policy: regular")
        debugWindowController.log("Status item created: \(statusItemController != nil)")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        presentWindows()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        presentWindows()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        watchedFolderController.stopWatching(clearBookmark: false)
    }

    private func presentWindows() {
        debugWindowController.showWindow(nil)
        debugWindowController.window?.orderFrontRegardless()
        debugWindowController.window?.makeKeyAndOrderFront(nil)
        shelfWindowController.showShelf()
        shelfWindowController.forceExpand()
    }
}
