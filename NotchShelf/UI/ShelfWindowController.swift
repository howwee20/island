import AppKit

final class ShelfWindowController: NSWindowController {
    private final class ShelfPanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    private let shelfView: ShelfView
    private let store: ScreenshotStore
    private var collapseWorkItem: DispatchWorkItem?
    private var isPointerInsideShelf = false
    private var isDragInsideShelf = false

    private(set) var isExpanded = false

    init(store: ScreenshotStore) {
        self.store = store
        shelfView = ShelfView(store: store)

        let panel = ShelfPanel(
            contentRect: NSRect(origin: .zero, size: shelfView.collapsedSize),
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

        shelfView.frame = NSRect(origin: .zero, size: shelfView.collapsedSize)
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
            self?.toggleExpansion()
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

        if store.items.isEmpty {
            setExpanded(true, animated: false)
        }

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
        guard !isPointerInsideShelf, !isDragInsideShelf else { return }
        setExpanded(false)
    }

    func toggleShelf() {
        toggleExpansion()
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

    private func toggleExpansion() {
        cancelPendingCollapse()
        setExpanded(!isExpanded)
    }

    private func handleHoverState(_ isHovering: Bool) {
        isPointerInsideShelf = isHovering

        if isHovering {
            cancelPendingCollapse()
            setExpanded(true)
        } else {
            scheduleCollapseIfNeeded()
        }
    }

    private func handleDragState(_ isDraggingOver: Bool) {
        isDragInsideShelf = isDraggingOver

        if isDraggingOver {
            cancelPendingCollapse()
            setExpanded(true, animated: true)
        } else {
            scheduleCollapseIfNeeded()
        }
    }

    private func scheduleCollapseIfNeeded() {
        guard !store.items.isEmpty else {
            return
        }

        guard !isPointerInsideShelf, !isDragInsideShelf else {
            return
        }

        cancelPendingCollapse()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isPointerInsideShelf, !self.isDragInsideShelf else {
                return
            }

            self.setExpanded(false)
        }

        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
    }

    private func cancelPendingCollapse() {
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }

    private func targetWindowFrame() -> NSRect {
        let screen = window?.screen ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen.main!
        let preferredSize = isExpanded ? shelfView.expandedSize : shelfView.collapsedSize

        let maxWidth = min(preferredSize.width, screen.visibleFrame.width - 120)
        let topInset = max(screen.safeAreaInsets.top, screen.frame.maxY - screen.visibleFrame.maxY)
        let topAnchorY = screen.frame.maxY - topInset - 6

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
