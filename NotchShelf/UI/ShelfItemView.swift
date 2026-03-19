import AppKit

protocol ShelfItemViewDelegate: AnyObject {
    func shelfItemViewDidRequestTogglePin(_ view: ShelfItemView)
    func shelfItemViewDidRequestDelete(_ view: ShelfItemView)
    func shelfItemViewDidRequestReveal(_ view: ShelfItemView)
    func shelfItemViewDidRequestCopy(_ view: ShelfItemView)
    func shelfItemViewDidReceiveInteraction(_ view: ShelfItemView)
}

final class ShelfItemView: NSView, NSDraggingSource {
    let item: ScreenshotItem

    weak var delegate: ShelfItemViewDelegate?

    private let fileURL: URL
    private let imageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let timestampLabel = NSTextField(labelWithString: "")
    private let pinButton = NSButton()
    private let deleteButton = NSButton()

    private var trackingArea: NSTrackingArea?
    private var dragStartLocation: NSPoint = .zero
    private var startedDraggingSession = false

    init(item: ScreenshotItem, thumbnail: NSImage?, fileURL: URL) {
        self.item = item
        self.fileURL = fileURL
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.055).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor

        setupImageView(with: thumbnail)
        setupLabels()
        setupButtons()
        setupLayout()
        menu = makeContextMenu()
        updateHoverState(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )

        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        delegate?.shelfItemViewDidReceiveInteraction(self)
        updateHoverState(true)
    }

    override func mouseExited(with event: NSEvent) {
        updateHoverState(false)
    }

    override func mouseDown(with event: NSEvent) {
        delegate?.shelfItemViewDidReceiveInteraction(self)
        dragStartLocation = convert(event.locationInWindow, from: nil)
        startedDraggingSession = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !startedDraggingSession else {
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        let deltaX = point.x - dragStartLocation.x
        let deltaY = point.y - dragStartLocation.y
        let distance = hypot(deltaX, deltaY)

        guard distance > 4 else {
            return
        }

        startedDraggingSession = true
        delegate?.shelfItemViewDidReceiveInteraction(self)

        let writer = ScreenshotDragWriter(fileURL: fileURL)
        let draggingItem = NSDraggingItem(pasteboardWriter: writer)
        let dragImage = imageView.image ?? NSWorkspace.shared.icon(forFile: fileURL.path)
        let dragFrame = NSRect(x: 12, y: 22, width: bounds.width - 24, height: bounds.height - 36)
        draggingItem.setDraggingFrame(dragFrame, contents: dragImage)

        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = false
        session.draggingFormation = .none
    }

    override func mouseUp(with event: NSEvent) {
        startedDraggingSession = false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        startedDraggingSession = false
    }

    private func setupImageView(with thumbnail: NSImage?) {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = thumbnail
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 12
        imageView.layer?.cornerCurve = .continuous
        imageView.layer?.masksToBounds = true
        imageView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.04).cgColor
    }

    private func setupLabels() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.stringValue = item.displayTitle
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.maximumNumberOfLines = 1

        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.stringValue = item.displayTimestamp
        timestampLabel.textColor = NSColor.white.withAlphaComponent(0.62)
        timestampLabel.font = .systemFont(ofSize: 11, weight: .regular)
    }

    private func setupButtons() {
        configureOverlayButton(
            pinButton,
            symbolName: item.pinned ? "pin.fill" : "pin",
            action: #selector(togglePin)
        )

        configureOverlayButton(
            deleteButton,
            symbolName: "trash",
            action: #selector(deleteItem)
        )
    }

    private func setupLayout() {
        let textStack = NSStackView(views: [titleLabel, timestampLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        addSubview(imageView)
        addSubview(textStack)
        addSubview(pinButton)
        addSubview(deleteButton)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 96),
            heightAnchor.constraint(equalToConstant: 128),

            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            imageView.heightAnchor.constraint(equalToConstant: 82),

            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),

            pinButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            pinButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            pinButton.widthAnchor.constraint(equalToConstant: 22),
            pinButton.heightAnchor.constraint(equalToConstant: 22),

            deleteButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            deleteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            deleteButton.widthAnchor.constraint(equalToConstant: 22),
            deleteButton.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    private func configureOverlayButton(_ button: NSButton, symbolName: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        button.imageScaling = .scaleProportionallyUpOrDown
        button.contentTintColor = .white
        button.target = self
        button.action = action
        button.wantsLayer = true
        button.layer?.cornerRadius = 11
        button.layer?.cornerCurve = .continuous
        button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()

        let pinTitle = item.pinned ? "Unpin" : "Pin"
        menu.addItem(withTitle: pinTitle, action: #selector(togglePin), keyEquivalent: "")
        menu.addItem(withTitle: "Copy Image", action: #selector(copyImage), keyEquivalent: "")
        menu.addItem(withTitle: "Reveal in Finder", action: #selector(revealInFinder), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Delete", action: #selector(deleteItem), keyEquivalent: "")

        for menuItem in menu.items {
            menuItem.target = self
        }

        return menu
    }

    private func updateHoverState(_ isHovered: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            pinButton.animator().alphaValue = isHovered || item.pinned ? 1 : 0
            deleteButton.animator().alphaValue = isHovered ? 1 : 0
        }

        layer?.borderColor = (isHovered
            ? NSColor.white.withAlphaComponent(0.18)
            : NSColor.white.withAlphaComponent(0.08)
        ).cgColor
    }

    @objc
    private func togglePin() {
        delegate?.shelfItemViewDidRequestTogglePin(self)
    }

    @objc
    private func deleteItem() {
        delegate?.shelfItemViewDidRequestDelete(self)
    }

    @objc
    private func revealInFinder() {
        delegate?.shelfItemViewDidRequestReveal(self)
    }

    @objc
    private func copyImage() {
        delegate?.shelfItemViewDidRequestCopy(self)
    }
}
