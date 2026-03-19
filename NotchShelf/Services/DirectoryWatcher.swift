import Foundation

final class DirectoryWatcher {
    let url: URL
    var onChange: (() -> Void)?

    private let queue = DispatchQueue(label: "NotchShelf.DirectoryWatcher", qos: .utility)
    private var fileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?

    init(url: URL) {
        self.url = url
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        stop()

        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            return false
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .attrib, .extend],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.scheduleChangeCallback()
        }

        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        self.source = source
        source.resume()
        return true
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        source?.cancel()
        source = nil

        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    private func scheduleChangeCallback() {
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                self?.onChange?()
            }
        }

        debounceWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }
}
