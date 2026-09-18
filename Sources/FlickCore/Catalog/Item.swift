import Foundation

public enum ItemKind: String, Codable, Equatable {
    case app
    case file
    case command
    case clipboard
    case calculator
}

public struct Item: Identifiable, Equatable {
    public var id: String
    public var kind: ItemKind
    public var title: String
    public var subtitle: String
    public var path: String?
    public var bundleIdentifier: String?
    public var keywords: [String]
    public var commandID: String?
    public var text: String?
    public var url: URL?
    public var runningPID: Int32?
    public var mtime: Date?

    public init(
        id: String,
        kind: ItemKind,
        title: String,
        subtitle: String = "",
        path: String? = nil,
        bundleIdentifier: String? = nil,
        keywords: [String] = [],
        commandID: String? = nil,
        text: String? = nil,
        url: URL? = nil,
        runningPID: Int32? = nil,
        mtime: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.path = path
        self.bundleIdentifier = bundleIdentifier
        self.keywords = keywords
        self.commandID = commandID
        self.text = text
        self.url = url
        self.runningPID = runningPID
        self.mtime = mtime
    }

    public var searchTexts: [String] {
        [title, subtitle] + keywords
    }
}

public struct ResultGroup: Equatable {
    public var title: String
    public var items: [Item]

    public init(title: String, items: [Item]) {
        self.title = title
        self.items = items
    }
}

public enum FileFilter {
    public static let skippedDirectories: Set<String> = [
        "node_modules", ".git", ".build", "DerivedData", ".cache",
    ]

    public static func shouldSkip(name: String, isDirectory: Bool) -> Bool {
        if name.hasPrefix(".") { return true }
        if isDirectory && skippedDirectories.contains(name) { return true }
        return false
    }
}

public enum PasteboardPrivacy {
    public static let concealedType = "org.nspasteboard.concealedType"

    public static func isConcealed(types: [String]) -> Bool {
        types.contains(concealedType)
    }
}
