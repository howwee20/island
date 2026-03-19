import AppKit

final class DebugWindowController: NSWindowController {
    private let logTextView = NSTextView()
    private var shelfWindowController: ShelfWindowController?

    convenience init(shelfWindowController: ShelfWindowController) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NotchShelf Debug Window"
        window.center()
        self.init(window: window)
        self.shelfWindowController = shelfWindowController
        setupUI()
    }

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let showBtn = makeButton(title: "Show Shelf Now", action: #selector(showShelf))
        let toggleBtn = makeButton(title: "Toggle Shelf", action: #selector(toggleShelf))
        let printBtn = makeButton(title: "Print Window State", action: #selector(printState))

        let buttonStack = NSStackView(views: [showBtn, toggleBtn, printBtn])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        logTextView.isEditable = false
        logTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logTextView.autoresizingMask = [.width]
        scrollView.documentView = logTextView

        contentView.addSubview(buttonStack)
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            buttonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),

            scrollView.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])

        log("NotchShelf Debug Window ready")
        printState()
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let btn = NSButton(title: title, target: self, action: action)
        btn.bezelStyle = .rounded
        return btn
    }

    func log(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let current = self.logTextView.string
            self.logTextView.string = current + message + "\n"
            self.logTextView.scrollToEndOfDocument(nil)
            print("[NotchShelf] \(message)")
        }
    }

    @objc private func showShelf() {
        guard let wc = shelfWindowController, let panel = wc.window else {
            log("ERROR: no shelf window controller")
            return
        }

        wc.showShelf()
        wc.forceExpand()

        // Force red border and explicit frame for debugging
        if let cv = panel.contentView {
            cv.wantsLayer = true
            cv.layer?.borderColor = NSColor.red.cgColor
            cv.layer?.borderWidth = 4
        }

        panel.orderFrontRegardless()

        log("Show Shelf Now pressed")
        log("  panel.frame = \(panel.frame)")
        log("  panel.isVisible = \(panel.isVisible)")
        log("  panel.alphaValue = \(panel.alphaValue)")
        log("  panel.level = \(panel.level.rawValue)")
    }

    @objc private func toggleShelf() {
        shelfWindowController?.toggleShelf()
        log("Toggle Shelf pressed")
    }

    @objc func printState() {
        let policy = NSApp.activationPolicy()
        let policyStr: String
        switch policy {
        case .regular: policyStr = "regular"
        case .accessory: policyStr = "accessory"
        case .prohibited: policyStr = "prohibited"
        @unknown default: policyStr = "unknown"
        }

        log("--- Window State ---")
        log("  activation policy: \(policyStr)")
        log("  screens count: \(NSScreen.screens.count)")
        for (i, screen) in NSScreen.screens.enumerated() {
            log("  screen[\(i)] frame: \(screen.frame)")
            log("  screen[\(i)] visibleFrame: \(screen.visibleFrame)")
            log("  screen[\(i)] safeAreaInsets: \(screen.safeAreaInsets)")
        }

        if let panel = shelfWindowController?.window {
            log("  shelf panel frame: \(panel.frame)")
            log("  shelf panel isVisible: \(panel.isVisible)")
            log("  shelf panel alphaValue: \(panel.alphaValue)")
            log("  shelf panel level: \(panel.level.rawValue)")
            log("  shelf panel screen: \(String(describing: panel.screen?.frame))")
        } else {
            log("  shelf panel: nil")
        }
        log("--------------------")
    }
}
