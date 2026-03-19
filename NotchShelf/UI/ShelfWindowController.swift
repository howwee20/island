import AppKit

final class ShelfWindowController: NSWindowController {
    private final class ShelfPanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    private let shelfView: ShelfView
    private let store: ScreenshotStore
    private var isPointerInsideShelf = false
    private var isDragInsideShelf = false

    private(set) var isExpanded = true

    init(store: ScreenshotStore) {
        self.store = store
        shelfView = ShelfView(store: store)

        let panel = ShelfPanel(
            contentRect: NSRect(origin: .zero, size: shelfView.expandedSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.becomesKeyOnlyIfNeeded = true

        super.init(window: panel)

        shelfView.isExpanded = true
        shelfView.frame = NSRect(origin: .zero, size: shelfView.expandedSize)
        shelfView.autoresizingMask = [.width, .height]
        panel.contentView = shelfView

        shelfView.onHoverStateChange = { [weak self] isHovering in
            self?.handleHoverState(isHovering)
        }

        shelfView.onDropStateChange = { [weak self] isDraggingOver in
            self?.handleDragState(isDraggingOver)
        }

        shelfView.onPreferredSizeChange = { [weak self] in
            self?.updateWindowFrame(animated: true)
        }

        shelfView.onBackgroundClick = { [weak self] in
            self?.showShelf()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositionForScreenChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func showShelf() {
        guard let window else {
            return
        }

        setExpanded(true, animated: false)
        NSApp.activate(ignoringOtherApps: true)
        updateWindowFrame(animated: false)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        let frame = targetWindowFrame()
        print("[NotchShelf] shelf frame: \(frame)")
        print("[NotchShelf] panel ordered front")
    }

    func forceExpand() {
        setExpanded(true, animated: true)
    }

    func collapseIfNotHovered() {
    }

    func toggleShelf() {
        showShelf()
    }

    func updateWindowFrame(animated: Bool) {
        guard let window else {
            return
        }

        let frame = targetWindowFrame()

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
        }
    }

    private func setExpanded(_ expanded: Bool, animated: Bool = true) {
        guard expanded != isExpanded else {
            updateWindowFrame(animated: animated)
            return
        }

        isExpanded = expanded
        shelfView.isExpanded = expanded
        updateWindowFrame(animated: animated)
    }

    private func handleHoverState(_ isHovering: Bool) {
        isPointerInsideShelf = isHovering
        if isHovering {
            setExpanded(true)
        }
    }

    private func handleDragState(_ isDraggingOver: Bool) {
        isDragInsideShelf = isDraggingOver

        if isDraggingOver {
            setExpanded(true, animated: true)
        }
    }

    private func scheduleCollapseIfNeeded() {
    }

    private func cancelPendingCollapse() {
    }

    private func targetWindowFrame() -> NSRect {
        let screen = window?.screen ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen.main!
        let preferredSize = shelfView.expandedSize

        let maxWidth = min(preferredSize.width, screen.visibleFrame.width - 120)
        let topInset = max(screen.safeAreaInsets.top, screen.frame.maxY - screen.visibleFrame.maxY)
        let topAnchorY = screen.frame.maxY - topInset - 12

        return NSRect(
            x: floor(screen.frame.midX - (maxWidth / 2)),
            y: floor(topAnchorY - preferredSize.height),
            width: maxWidth,
            height: preferredSize.height
        )
    }

    @objc
    private func repositionForScreenChange(_ notification: Notification) {
        updateWindowFrame(animated: false)
    }
}
