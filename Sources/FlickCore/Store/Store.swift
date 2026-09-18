import Foundation

public struct Prefs: Codable, Equatable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var loginItemEnabled: Bool

    public static let optionSpace: Prefs = .init(
        keyCode: 49,          // kVK_Space
        modifiers: 2048,      // optionKey
        loginItemEnabled: false
    )

    public init(keyCode: UInt32, modifiers: UInt32, loginItemEnabled: Bool) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.loginItemEnabled = loginItemEnabled
    }
}

public struct UsageEntry: Codable, Equatable {
    public var count: Int
    public var lastUsed: Date

    public init(count: Int, lastUsed: Date) {
        self.count = count
        self.lastUsed = lastUsed
    }
}

public struct CachedApp: Codable, Equatable {
    public var path: String
    public var name: String
    public var bundleIdentifier: String?

    public init(path: String, name: String, bundleIdentifier: String?) {
        self.path = path
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct CachedFile: Codable, Equatable {
    public var path: String
    public var name: String
    public var mtime: Date

    public init(path: String, name: String, mtime: Date) {
        self.path = path
        self.name = name
        self.mtime = mtime
    }
}

public struct CatalogCache: Codable, Equatable {
    public var apps: [CachedApp]
    public var files: [CachedFile]

    public init(apps: [CachedApp], files: [CachedFile]) {
        self.apps = apps
        self.files = files
    }
}

public final class Store {
    public let root: URL
    private var usageCache: [String: UsageEntry]?

    public init(root: URL? = nil) {
        let defaultRoot = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(FlickApp.bundleID, isDirectory: true)
        self.root = root ?? defaultRoot
        try? FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: self.root.path
        )
    }

    public func loadPrefs() -> Prefs {
        load(Prefs.self, file: "prefs.json") ?? .optionSpace
    }

    public func savePrefs(_ prefs: Prefs) {
        save(prefs, file: "prefs.json")
    }

    public func loadUsage() -> [String: UsageEntry] {
        if let usageCache { return usageCache }
        let loaded = load([String: UsageEntry].self, file: "usage.json") ?? [:]
        usageCache = loaded
        return loaded
    }

    public func saveUsage(_ usage: [String: UsageEntry]) {
        usageCache = usage
        save(usage, file: "usage.json")
    }

    public func recordUsage(id: String, at date: Date = Date()) {
        var usage = loadUsage()
        let existing = usage[id]
        usage[id] = UsageEntry(count: (existing?.count ?? 0) + 1, lastUsed: date)
        saveUsage(usage)
    }

    public func loadClipboard() -> [String] {
        load([String].self, file: "clipboard.json") ?? []
    }

    public func saveClipboard(_ items: [String]) {
        save(Array(items.prefix(20)), file: "clipboard.json")
    }

    public func loadCatalogCache() -> CatalogCache? {
        load(CatalogCache.self, file: "catalog-cache.json")
    }

    public func saveCatalogCache(_ cache: CatalogCache) {
        save(cache, file: "catalog-cache.json")
    }

    private func url(_ file: String) -> URL {
        root.appendingPathComponent(file)
    }

    private func load<T: Decodable>(_ type: T.Type, file: String) -> T? {
        let path = url(file)
        guard let data = try? Data(contentsOf: path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, file: String) {
        let path = url(file)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        let tmp = path.appendingPathExtension("tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if FileManager.default.fileExists(atPath: path.path) {
                _ = try FileManager.default.replaceItemAt(path, withItemAt: tmp)
            } else {
                try FileManager.default.moveItem(at: tmp, to: path)
            }
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: path.path
            )
        } catch {
            try? data.write(to: path, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: path.path
            )
        }
    }
}

public enum UsageScoring {
    /// 0...1 from frequency + recency (≈14 day decay).
    public static func score(_ entry: UsageEntry, now: Date = Date()) -> Double {
        let age = max(0, now.timeIntervalSince(entry.lastUsed))
        let recency = exp(-age / (14.0 * 86_400.0))
        let freq = min(1.0, log2(Double(entry.count) + 1.0) / 5.0)
        return 0.6 * recency + 0.4 * freq
    }
}
