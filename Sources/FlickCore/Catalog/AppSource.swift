import AppKit
import Foundation

public enum AppSource {
    public static let searchRoots: [URL] = [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Applications", isDirectory: true),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
    ]

    public static func scan() -> [Item] {
        var items: [Item] = []
        var seen = Set<String>()
        let fm = FileManager.default
        let workspace = NSWorkspace.shared

        for root in searchRoots {
            guard let names = try? fm.contentsOfDirectory(atPath: root.path) else { continue }
            for name in names where name.hasSuffix(".app") {
                let url = root.appendingPathComponent(name)
                let path = url.path
                guard !seen.contains(path) else { continue }
                seen.insert(path)
                let bundle = Bundle(url: url)
                let display = workspace.localizedName(forApplicationAt: url)
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? (name as NSString).deletingPathExtension
                let bid = bundle?.bundleIdentifier
                items.append(
                    Item(
                        id: bid ?? path,
                        kind: .app,
                        title: display,
                        subtitle: path,
                        path: path,
                        bundleIdentifier: bid,
                        keywords: [display, (name as NSString).deletingPathExtension]
                    )
                )
            }
        }
        return items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}

private extension NSWorkspace {
    func localizedName(forApplicationAt url: URL) -> String? {
        if let name = url.deletingPathExtension().lastPathComponent as String? {
            // Prefer Info.plist display name when present.
            if let bundle = Bundle(url: url) {
                if let display = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !display.isEmpty {
                    return display
                }
                if let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, !bundleName.isEmpty {
                    return bundleName
                }
            }
            return name
        }
        return nil
    }
}
