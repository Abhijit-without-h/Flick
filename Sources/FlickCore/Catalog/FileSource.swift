import Foundation

public enum FileSource {
    public static let maxDepth = 8
    public static let maxItems = 12_000

    public static func defaultRoots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["Desktop", "Documents", "Downloads"].map {
            home.appendingPathComponent($0, isDirectory: true)
        }
    }

    public static func isAllowed(path: String) -> Bool {
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        return defaultRoots().contains { root in
            let rootPath = root.resolvingSymlinksInPath().path
            return resolved == rootPath || resolved.hasPrefix(rootPath + "/")
        }
    }

    public static func scan(roots: [URL] = defaultRoots()) -> [Item] {
        let fm = FileManager.default
        let existing = roots.filter { url in
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }
        guard !existing.isEmpty else { return [] }

        let lock = NSLock()
        var items: [Item] = []
        items.reserveCapacity(min(maxItems, 1024))

        DispatchQueue.concurrentPerform(iterations: existing.count) { index in
            let scanned = scanTree(
                root: existing[index],
                fm: fm,
                maxDepth: maxDepth,
                maxItems: maxItems
            )
            lock.lock()
            if items.count < maxItems {
                items.append(contentsOf: scanned.prefix(maxItems - items.count))
            }
            lock.unlock()
        }
        return items
    }

    public static func scanTree(
        root: URL,
        fm: FileManager = .default,
        maxDepth: Int = maxDepth,
        maxItems: Int = maxItems
    ) -> [Item] {
        // Metadata keys only — do not read file contents (avoids materializing iCloud).
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isPackageKey,
                .contentModificationDateKey,
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        let rootCount = root.standardizedFileURL.pathComponents.count
        var items: [Item] = []
        items.reserveCapacity(256)

        for case let url as URL in enumerator {
            if items.count >= maxItems { break }

            let name = url.lastPathComponent
            if name.hasSuffix(".icloud") { continue }

            let values = try? url.resourceValues(forKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .contentModificationDateKey,
            ])
            let isDirectory = values?.isDirectory ?? false
            let depth = url.pathComponents.count - rootCount

            if isDirectory {
                if FileFilter.shouldSkip(name: name, isDirectory: true) || depth >= maxDepth {
                    enumerator.skipDescendants()
                }
                continue
            }
            if FileFilter.shouldSkip(name: name, isDirectory: false) { continue }
            if depth > maxDepth { continue }
            guard values?.isRegularFile == true else { continue }

            let path = url.path
            items.append(
                Item(
                    id: path,
                    kind: .file,
                    title: name,
                    subtitle: relativeSubtitle(path, root: root),
                    path: path,
                    keywords: [name, url.pathExtension],
                    mtime: values?.contentModificationDate
                )
            )
        }
        return items
    }

    private static func relativeSubtitle(_ path: String, root: URL) -> String {
        let rootPath = root.deletingLastPathComponent().path
        if path.hasPrefix(rootPath) {
            return String(path.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return path
    }
}
