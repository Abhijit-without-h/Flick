import Foundation

public enum AppSource {
    public static let searchRoots: [URL] = {
        var roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]
        let cryptex = URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications", isDirectory: true)
        if FileManager.default.fileExists(atPath: cryptex.path) {
            roots.append(cryptex)
        }
        return roots
    }()

    public static func scan(roots: [URL] = searchRoots) -> [Item] {
        var items: [Item] = []
        var seen = Set<String>()
        let fm = FileManager.default

        for root in roots {
            guard let entries = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in entries {
                if url.pathExtension == "app" {
                    if let item = item(at: url, seen: &seen) {
                        items.append(item)
                    }
                    continue
                }
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { continue }
                // One extra level for folders like Utilities.
                guard let nested = try? fm.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }
                for child in nested where child.pathExtension == "app" {
                    if let item = item(at: child, seen: &seen) {
                        items.append(item)
                    }
                }
            }
        }
        return items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private static func item(at url: URL, seen: inout Set<String>) -> Item? {
        let resolved = url.resolvingSymlinksInPath()
        let path = resolved.path
        guard !seen.contains(path) else { return nil }
        seen.insert(path)

        let fallback = (url.lastPathComponent as NSString).deletingPathExtension
        let info = infoDictionary(atApp: resolved) ?? infoDictionary(atApp: url)
        let display = nonEmpty(info?["CFBundleDisplayName"] as? String)
            ?? nonEmpty(info?["CFBundleName"] as? String)
            ?? fallback
        let bid = nonEmpty(info?["CFBundleIdentifier"] as? String)
        return Item(
            id: bid ?? path,
            kind: .app,
            title: display,
            subtitle: path,
            path: path,
            bundleIdentifier: bid,
            keywords: [display, fallback]
        )
    }

    /// Faster than `Bundle(url:)` — reads Contents/Info.plist only. Icons stay lazy.
    private static func infoDictionary(atApp url: URL) -> [String: Any]? {
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL, options: [.mappedIfSafe]) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
