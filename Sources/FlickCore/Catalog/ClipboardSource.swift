import AppKit
import Foundation

public final class ClipboardSource {
    public private(set) var items: [String]
    private var lastChangeCount: Int
    private let store: Store
    public var onChange: (() -> Void)?
    private var timer: Timer?

    public init(store: Store) {
        self.store = store
        self.items = store.loadClipboard()
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    public func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer?.tolerance = 0.2
        poll()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func catalogItems() -> [Item] {
        items.enumerated().map { index, text in
            let preview = text.replacingOccurrences(of: "\n", with: " ")
            let clipped = preview.count > 80 ? String(preview.prefix(80)) + "…" : preview
            return Item(
                id: "clipboard:\(index)",
                kind: .clipboard,
                title: clipped,
                subtitle: index == 0 ? "Current clipboard" : "Clipboard history",
                keywords: ["clipboard", "clip", "paste"],
                text: text
            )
        }
    }

    func poll() {
        let board = NSPasteboard.general
        let count = board.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        ingest(board)
    }

    private func ingest(_ board: NSPasteboard) {
        let types = (board.types ?? []).map(\.rawValue)
        if PasteboardPrivacy.shouldSkip(types: types) { return }
        guard let string = board.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !string.isEmpty,
            string.utf8.count <= 16_384
        else { return }
        items.removeAll { $0 == string }
        items.insert(string, at: 0)
        if items.count > 20 { items = Array(items.prefix(20)) }
        store.saveClipboard(items)
        onChange?()
    }
}
