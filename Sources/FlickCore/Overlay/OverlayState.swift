import AppKit
import Combine
import Foundation

@MainActor
public final class OverlayState: ObservableObject {
    @Published public var query = ""
    @Published public var groups: [ResultGroup] = []
    @Published public var selectedIndex = 0
    @Published public var error: String?
    @Published public var showingActions = false
    @Published public var actions: [RowAction] = []
    @Published public var actionIndex = 0

    public let catalog: Catalog
    public let store: Store
    public var previousApp: NSRunningApplication?

    public init(catalog: Catalog, store: Store) {
        self.catalog = catalog
        self.store = store
        refresh()
    }

    public var flatItems: [Item] {
        groups.flatMap(\.items)
    }

    public var selected: Item? {
        let items = flatItems
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    public func refresh() {
        catalog.refreshRunning()
        groups = catalog.search(query: query, usage: store.loadUsage())
        if selectedIndex >= flatItems.count {
            selectedIndex = max(0, flatItems.count - 1)
        }
        error = nil
    }

    public func queryChanged(_ value: String) {
        query = value
        showingActions = false
        selectedIndex = 0
        refresh()
    }

    public func move(_ delta: Int) {
        let count = showingActions ? actions.count : flatItems.count
        guard count > 0 else { return }
        if showingActions {
            actionIndex = (actionIndex + delta + count) % count
        } else {
            selectedIndex = (selectedIndex + delta + count) % count
        }
        error = nil
    }

    public func openActions() {
        guard let item = selected else { return }
        actions = ActionPalette.actions(for: item)
        guard !actions.isEmpty else { return }
        showingActions = true
        actionIndex = 0
        error = nil
    }

    public func closeActions() {
        showingActions = false
        error = nil
    }

    @discardableResult
    public func submitDefault() -> Bool {
        if showingActions {
            guard actions.indices.contains(actionIndex), let item = selected else { return false }
            return perform(actions[actionIndex], on: item)
        }
        guard let item = selected else { return false }
        if item.kind == .calculator && item.text == nil {
            error = "Cannot evaluate"
            return false
        }
        return perform(ActionPalette.defaultAction(for: item), on: item)
    }

    @discardableResult
    public func reveal() -> Bool {
        guard let item = selected, item.path != nil else { return false }
        return perform(.reveal, on: item)
    }

    @discardableResult
    public func copyPath() -> Bool {
        guard let item = selected else { return false }
        if item.kind == .clipboard || item.kind == .calculator {
            return perform(.copyText, on: item)
        }
        return perform(.copyPath, on: item)
    }

    public func perform(_ action: RowAction, on item: Item) -> Bool {
        let result = ActionRunner.run(action, item: item, previousApp: previousApp)
        if let message = result.error {
            error = message
            return false
        }
        if action == .open || action == .run || action == .paste || action == .copyText || action == .copyPath {
            store.recordUsage(id: item.id)
        }
        return result.dismiss
    }
}
