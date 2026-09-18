import Foundation

public enum SearchEngine {
    public static func search(
        query: String,
        snapshot: CatalogSnapshot,
        usage: [String: UsageEntry],
        now: Date = Date()
    ) -> [ResultGroup] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let ranker = Ranker(usage: usage, now: now)

        if q.isEmpty {
            return ranker.emptyQueryItems(
                apps: snapshot.apps,
                files: snapshot.files,
                clipboard: snapshot.clipboard,
                commands: CommandSource.staticCommands()
            )
        }

        var groups: [ResultGroup] = []

        if Calculator.looksLikeMath(q) {
            if let result = Calculator.evaluate(q) {
                groups.append(
                    ResultGroup(
                        title: "Commands",
                        items: [
                            Item(
                                id: "\(CommandID.calculator):\(result)",
                                kind: .calculator,
                                title: result,
                                subtitle: q.hasPrefix("=") ? String(q.dropFirst()).trimmingCharacters(in: .whitespaces) : q,
                                keywords: ["calc", "calculator"],
                                commandID: CommandID.calculator,
                                text: result
                            ),
                        ]
                    )
                )
            } else {
                groups.append(
                    ResultGroup(
                        title: "Commands",
                        items: [
                            Item(
                                id: CommandID.calculator,
                                kind: .calculator,
                                title: "Cannot evaluate",
                                subtitle: q,
                                commandID: CommandID.calculator
                            ),
                        ]
                    )
                )
            }
        }

        if let url = URLRouter.url(from: q) {
            groups.append(
                ResultGroup(
                    title: "Commands",
                    items: [
                        Item(
                            id: "\(CommandID.openURL):\(url.absoluteString)",
                            kind: .command,
                            title: "Open URL",
                            subtitle: url.absoluteString,
                            keywords: ["url", "open"],
                            commandID: CommandID.openURL,
                            url: url
                        ),
                    ]
                )
            )
        }

        if PathRouter.looksLikePath(q) {
            let expanded = PathRouter.expanded(q)
            groups.append(
                ResultGroup(
                    title: "Commands",
                    items: [
                        Item(
                            id: "\(CommandID.openFolder):\(expanded)",
                            kind: .command,
                            title: "Open folder",
                            subtitle: expanded,
                            path: expanded,
                            keywords: ["folder", "open", "path"],
                            commandID: CommandID.openFolder
                        ),
                    ]
                )
            )
        }

        var scored: [(Item, Double)] = []
        for item in snapshot.all {
            if let s = ranker.score(query: q, item: item) {
                scored.append((item, s))
            }
        }
        groups.append(contentsOf: ranker.grouped(scored))
        return mergeGroups(groups)
    }

    private static func mergeGroups(_ groups: [ResultGroup]) -> [ResultGroup] {
        var order: [String] = []
        var map: [String: [Item]] = [:]
        var seen = Set<String>()
        for group in groups {
            if map[group.title] == nil { order.append(group.title) }
            var items = map[group.title] ?? []
            for item in group.items where !seen.contains(item.id) {
                items.append(item)
                seen.insert(item.id)
            }
            map[group.title] = items
        }
        return order.compactMap { title in
            guard let items = map[title], !items.isEmpty else { return nil }
            return ResultGroup(title: title, items: items)
        }
    }
}
