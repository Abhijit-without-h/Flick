import Foundation

public struct Ranker {
    public var usage: [String: UsageEntry]
    public var now: Date

    public init(usage: [String: UsageEntry], now: Date = Date()) {
        self.usage = usage
        self.now = now
    }

    public func combined(fuzzy: Double, id: String) -> Double {
        let u = usage[id].map { UsageScoring.score($0, now: now) } ?? 0
        return 0.7 * fuzzy + 0.3 * u
    }

    public func score(query: String, item: Item) -> Double? {
        guard let fuzzy = Fuzzy.bestScore(query: query, texts: item.searchTexts) else { return nil }
        return combined(fuzzy: fuzzy, id: item.id)
    }

    public func emptyQueryItems(apps: [Item], files: [Item], clipboard: [Item], commands: [Item], limit: Int = 8) -> [ResultGroup] {
        let recents: [Item] = usage
            .sorted { lhs, rhs in
                if lhs.value.lastUsed != rhs.value.lastUsed {
                    return lhs.value.lastUsed > rhs.value.lastUsed
                }
                return lhs.value.count > rhs.value.count
            }
            .compactMap { key, _ in
                apps.first(where: { $0.id == key })
                    ?? files.first(where: { $0.id == key })
            }

        var groups: [ResultGroup] = []
        if !recents.isEmpty {
            let recentApps = recents.filter { $0.kind == .app }
            let recentFiles = recents.filter { $0.kind == .file }
            if !recentApps.isEmpty {
                groups.append(ResultGroup(title: "Applications", items: Array(recentApps.prefix(limit))))
            }
            if !recentFiles.isEmpty {
                groups.append(ResultGroup(title: "Files", items: Array(recentFiles.prefix(limit))))
            }
        } else {
            let recentFiles = files.sorted { ($0.mtime ?? .distantPast) > ($1.mtime ?? .distantPast) }
            if !apps.isEmpty {
                groups.append(ResultGroup(title: "Applications", items: Array(apps.prefix(5))))
            }
            if !recentFiles.isEmpty {
                groups.append(ResultGroup(title: "Files", items: Array(recentFiles.prefix(5))))
            }
            groups.append(ResultGroup(title: "Commands", items: Array(commands.prefix(6))))
        }
        if let top = clipboard.first {
            groups.append(ResultGroup(title: "Clipboard", items: [top]))
        }
        return groups.filter { !$0.items.isEmpty }
    }

    public func grouped(_ scored: [(Item, Double)], limit: Int = 24) -> [ResultGroup] {
        let sorted = scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
        func group(_ title: String, _ kind: ItemKind) -> ResultGroup? {
            let items = sorted.filter { $0.kind == kind }
            guard !items.isEmpty else { return nil }
            return ResultGroup(title: title, items: items)
        }
        return [
            group("Applications", .app),
            group("Files", .file),
            group("Commands", .command),
            group("Clipboard", .clipboard),
        ].compactMap { $0 }
    }
}
