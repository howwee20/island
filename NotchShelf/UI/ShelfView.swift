import AppKit

final class ShelfView: NSView {
    var onHoverStateChange: ((Bool) -> Void)?
    var onDropStateChange: ((Bool) -> Void)?
    var onPreferredSizeChange: (() -> Void)?
    var onBackgroundClick: (() -> Void)?

    var isExpanded: Bool = false {
        didSet {
            applyDisplayMode()
        }
    }

    let collapsedSize = NSSize(width: 320, height: 44)

    var expandedSize: NSSize {
        let rowCount = max(store.recentItems.count, store.pinnedItems.count, 1)
        let contentWidth = (CGFloat(rowCount) * 96) + (CGFloat(max(0, rowCount - 1)) * rowSpacing) + 32
        let width = max(360, contentWidth)

        let hasPinned = !store.pinnedItems.isEmpty
        let hasRecent = !store.recentItems.isEmpty
        let visibleSections = max((hasPinned ? 1 : 0) + (hasRecent ? 1 : 0), 1)
        let height = visibleSections == 1 ? 194 : 340

        return NSSize(width: width, height: CGFloat(height))
    }

    private let store: ScreenshotStore

    private let collapsedContainer = NSView()
    private let expandedContainer = NSView()
    private let dotView = NSView()
    private let collapsedTitleLabel = NSTextField(labelWithString: "NotchShelf")
    private let collapsedCountLabel = NSTextField(labelWithString: "0")

    private let headerTitleLabel = NSTextField(labelWithString: "NotchShelf")
    private let headerSummaryLabel = NSTextField(labelWithString: "")
    private let clearButton = NSButton()
    private let emptyStateLabel = NSTextField(labelWithString: "Drop a screenshot here")
    private let pinnedTitleLabel = NSTextField(labelWithString: "Pinned")
    private let recentTitleLabel = NSTextField(labelWithString: "Recent")
    private let pinnedStack = NSStackView()
    private let recentStack = NSStackView()

    private let rowSpacing: CGFloat = 10
    private var trackingArea: NSTrackingArea?
    private var isDropTargetActive = false

    init(store: ScreenshotStore) {
        self.store = store
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.24
        layer?.shadowRadius = 18
        layer?.shadowOffset = NSSize(width: 0, height: -6)

        let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        registerForDraggedTypes(promiseTypes + [.fileURL, .png, .tiff])
        setupCollapsedView()
        setupExpandedView()
        applyDisplayMode()
        updateAppearance()
        reloadItems()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange(_:)),
            name: ScreenshotStore.didChangeNotification,
            object: store
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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
        onHoverStateChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverStateChange?(false)
    }

    override func mouseDown(with event: NSEvent) {
        onBackgroundClick?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !(sender.draggingSource is ShelfItemView), canImport(from: sender.draggingPasteboard) else {
            return []
        }

        isDropTargetActive = true
        onDropStateChange?(true)
        updateAppearance()
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDropTargetActive = false
        onDropStateChange?(false)
        updateAppearance()
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        canImport(from: sender.draggingPasteboard) ? .copy : []
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        canImport(from: sender.draggingPasteboard)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let startedPromiseImport = store.importFilePromises(from: sender.draggingPasteboard) { [weak self] importedCount in
            guard let self, importedCount > 0 else { return }
            self.onHoverStateChange?(true)
        }

        if startedPromiseImport {
            isDropTargetActive = false
            onDropStateChange?(false)
            updateAppearance()
            return true
        }

        let importedCount = store.importFromPasteboard(sender.draggingPasteboard)
        let didImport = importedCount > 0

        isDropTargetActive = false
        onDropStateChange?(false)
        updateAppearance()

        return didImport
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        isDropTargetActive = false
        onDropStateChange?(false)
        updateAppearance()
    }

    private func setupCollapsedView() {
        collapsedContainer.translatesAutoresizingMaskIntoConstraints = false

        dotView.translatesAutoresizingMaskIntoConstraints = false
        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 4
        dotView.layer?.cornerCurve = .continuous

        collapsedTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        collapsedTitleLabel.textColor = .white
        collapsedTitleLabel.font = .systemFont(ofSize: 13, weight: .medium)

        collapsedCountLabel.translatesAutoresizingMaskIntoConstraints = false
        collapsedCountLabel.textColor = .white
        collapsedCountLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        collapsedCountLabel.alignment = .center
        collapsedCountLabel.wantsLayer = true
        collapsedCountLabel.layer?.cornerRadius = 9
        collapsedCountLabel.layer?.cornerCurve = .continuous
        collapsedCountLabel.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor

        addSubview(collapsedContainer)
        collapsedContainer.addSubview(dotView)
        collapsedContainer.addSubview(collapsedTitleLabel)
        collapsedContainer.addSubview(collapsedCountLabel)

        NSLayoutConstraint.activate([
            collapsedContainer.topAnchor.constraint(equalTo: topAnchor),
            collapsedContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            collapsedContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            collapsedContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            dotView.leadingAnchor.constraint(equalTo: collapsedContainer.leadingAnchor, constant: 14),
            dotView.centerYAnchor.constraint(equalTo: collapsedContainer.centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 8),
            dotView.heightAnchor.constraint(equalToConstant: 8),

            collapsedTitleLabel.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 10),
            collapsedTitleLabel.centerYAnchor.constraint(equalTo: collapsedContainer.centerYAnchor),

            collapsedCountLabel.leadingAnchor.constraint(greaterThanOrEqualTo: collapsedTitleLabel.trailingAnchor, constant: 12),
            collapsedCountLabel.trailingAnchor.constraint(equalTo: collapsedContainer.trailingAnchor, constant: -12),
            collapsedCountLabel.centerYAnchor.constraint(equalTo: collapsedContainer.centerYAnchor),
            collapsedCountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
            collapsedCountLabel.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    private func setupExpandedView() {
        expandedContainer.translatesAutoresizingMaskIntoConstraints = false

        headerTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerTitleLabel.textColor = .white
        headerTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        headerSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        headerSummaryLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        headerSummaryLabel.font = .systemFont(ofSize: 12, weight: .regular)

        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.textColor = NSColor.white.withAlphaComponent(0.55)
        emptyStateLabel.font = .systemFont(ofSize: 13, weight: .regular)
        emptyStateLabel.alignment = .center

        pinnedTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        recentTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        for label in [pinnedTitleLabel, recentTitleLabel] {
            label.textColor = NSColor.white.withAlphaComponent(0.55)
            label.font = .systemFont(ofSize: 11, weight: .semibold)
        }

        configureItemRow(pinnedStack)
        configureItemRow(recentStack)
        configureHeaderButton()

        addSubview(expandedContainer)
        expandedContainer.addSubview(headerTitleLabel)
        expandedContainer.addSubview(headerSummaryLabel)
        expandedContainer.addSubview(clearButton)
        expandedContainer.addSubview(emptyStateLabel)
        expandedContainer.addSubview(pinnedTitleLabel)
        expandedContainer.addSubview(pinnedStack)
        expandedContainer.addSubview(recentTitleLabel)
        expandedContainer.addSubview(recentStack)

        NSLayoutConstraint.activate([
            expandedContainer.topAnchor.constraint(equalTo: topAnchor),
            expandedContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            expandedContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            expandedContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            headerTitleLabel.topAnchor.constraint(equalTo: expandedContainer.topAnchor, constant: 14),
            headerTitleLabel.leadingAnchor.constraint(equalTo: expandedContainer.leadingAnchor, constant: 16),

            clearButton.centerYAnchor.constraint(equalTo: headerTitleLabel.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: expandedContainer.trailingAnchor, constant: -16),

            headerSummaryLabel.centerYAnchor.constraint(equalTo: headerTitleLabel.centerYAnchor),
            headerSummaryLabel.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -12),

            emptyStateLabel.topAnchor.constraint(equalTo: headerTitleLabel.bottomAnchor, constant: 48),
            emptyStateLabel.leadingAnchor.constraint(equalTo: expandedContainer.leadingAnchor, constant: 20),
            emptyStateLabel.trailingAnchor.constraint(equalTo: expandedContainer.trailingAnchor, constant: -20),

            pinnedTitleLabel.topAnchor.constraint(equalTo: headerTitleLabel.bottomAnchor, constant: 18),
            pinnedTitleLabel.leadingAnchor.constraint(equalTo: expandedContainer.leadingAnchor, constant: 16),

            pinnedStack.topAnchor.constraint(equalTo: pinnedTitleLabel.bottomAnchor, constant: 10),
            pinnedStack.leadingAnchor.constraint(equalTo: expandedContainer.leadingAnchor, constant: 16),
            pinnedStack.trailingAnchor.constraint(lessThanOrEqualTo: expandedContainer.trailingAnchor, constant: -16),
            pinnedStack.heightAnchor.constraint(equalToConstant: 128),

            recentTitleLabel.topAnchor.constraint(equalTo: pinnedStack.bottomAnchor, constant: 20),
            recentTitleLabel.leadingAnchor.constraint(equalTo: expandedContainer.leadingAnchor, constant: 16),

            recentStack.topAnchor.constraint(equalTo: recentTitleLabel.bottomAnchor, constant: 10),
            recentStack.leadingAnchor.constraint(equalTo: expandedContainer.leadingAnchor, constant: 16),
            recentStack.trailingAnchor.constraint(lessThanOrEqualTo: expandedContainer.trailingAnchor, constant: -16),
            recentStack.heightAnchor.constraint(equalToConstant: 128)
        ])
    }

    private func configureItemRow(_ stackView: NSStackView) {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .horizontal
        stackView.alignment = .top
        stackView.spacing = rowSpacing
        stackView.edgeInsets = NSEdgeInsets()
    }

    private func configureHeaderButton() {
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.title = "Clear"
        clearButton.isBordered = false
        clearButton.font = .systemFont(ofSize: 12, weight: .semibold)
        clearButton.contentTintColor = .white
        clearButton.target = self
        clearButton.action = #selector(clearUnpinned)
    }

    private func applyDisplayMode() {
        collapsedContainer.isHidden = isExpanded
        expandedContainer.isHidden = !isExpanded
        onPreferredSizeChange?()
        updateAppearance()
    }

    private func reloadItems() {
        rebuild(stackView: pinnedStack, items: store.pinnedItems)
        rebuild(stackView: recentStack, items: store.recentItems)

        let totalCount = store.items.count
        let pinnedCount = store.pinnedItems.count
        let recentCount = store.recentItems.count

        collapsedCountLabel.stringValue = "\(totalCount)"
        headerSummaryLabel.stringValue = "\(recentCount) recent • \(pinnedCount) pinned"
        dotView.layer?.backgroundColor = totalCount > 0
            ? NSColor.white.cgColor
            : NSColor.white.withAlphaComponent(0.35).cgColor

        let hasPinned = pinnedCount > 0
        let hasRecent = recentCount > 0
        let isEmpty = totalCount == 0

        emptyStateLabel.isHidden = !isEmpty
        pinnedTitleLabel.isHidden = !hasPinned
        pinnedStack.isHidden = !hasPinned
        recentTitleLabel.isHidden = !hasRecent
        recentStack.isHidden = !hasRecent
        clearButton.isHidden = recentCount == 0

        onPreferredSizeChange?()
    }

    private func rebuild(stackView: NSStackView, items: [ScreenshotItem]) {
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for item in items {
            let itemView = ShelfItemView(
                item: item,
                thumbnail: store.thumbnailImage(for: item),
                fileURL: store.fileURL(for: item)
            )
            itemView.delegate = self
            stackView.addArrangedSubview(itemView)
        }
    }

    private func canImport(from pasteboard: NSPasteboard) -> Bool {
        let urlOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: urlOptions) as? [URL], !urls.isEmpty {
            return true
        }

        if let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver], !receivers.isEmpty {
            return true
        }

        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
            return true
        }

        return pasteboard.availableType(from: [.png, .tiff]) != nil
    }

    private func updateAppearance() {
        layer?.backgroundColor = NSColor.black.withAlphaComponent(isDropTargetActive ? 1.0 : 0.96).cgColor
        layer?.borderColor = (isDropTargetActive
            ? NSColor.white.withAlphaComponent(0.26)
            : NSColor.white.withAlphaComponent(isExpanded ? 0.12 : 0.08)
        ).cgColor
    }

    @objc
    private func storeDidChange(_ notification: Notification) {
        reloadItems()
    }

    @objc
    private func clearUnpinned() {
        store.clearAllUnpinned()
    }
}

extension ShelfView: ShelfItemViewDelegate {
    func shelfItemViewDidRequestTogglePin(_ view: ShelfItemView) {
        store.togglePinned(for: view.item.id)
    }

    func shelfItemViewDidRequestDelete(_ view: ShelfItemView) {
        store.deleteItem(withID: view.item.id)
    }

    func shelfItemViewDidRequestReveal(_ view: ShelfItemView) {
        store.revealInFinder(itemID: view.item.id)
    }

    func shelfItemViewDidRequestCopy(_ view: ShelfItemView) {
        store.copyImageToPasteboard(itemID: view.item.id)
    }

    func shelfItemViewDidReceiveInteraction(_ view: ShelfItemView) {
        onHoverStateChange?(true)
    }
}
