import Foundation

public enum FileSource {
    public static func defaultRoots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["Desktop", "Documents", "Downloads"].map {
            home.appendingPathComponent($0, isDirectory: true)
        }
    }

    public static func scan(roots: [URL] = defaultRoots()) -> [Item] {
        var items: [Item] = []
        let fm = FileManager.default
        for root in roots {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else { continue }
            items.append(contentsOf: scanTree(root: root, fm: fm))
        }
        return items
    }

    public static func scanTree(root: URL, fm: FileManager = .default) -> [Item] {
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var items: [Item] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey, .isRegularFileKey])
            let isDirectory = values?.isDirectory ?? false
            if FileFilter.shouldSkip(name: name, isDirectory: isDirectory) {
                if isDirectory { enumerator.skipDescendants() }
                continue
            }
            if isDirectory { continue }
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
