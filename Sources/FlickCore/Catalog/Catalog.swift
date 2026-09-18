import Foundation

public struct CatalogSnapshot {
    public var apps: [Item]
    public var files: [Item]
    public var commands: [Item]
    public var clipboard: [Item]

    public var all: [Item] { apps + files + commands + clipboard }

    public init(apps: [Item], files: [Item], commands: [Item], clipboard: [Item]) {
        self.apps = apps
        self.files = files
        self.commands = commands
        self.clipboard = clipboard
    }
}

public final class Catalog {
    public private(set) var snapshot: CatalogSnapshot
    public var onUpdate: (() -> Void)?

    private let store: Store
    private let clipboard: ClipboardSource
    private let watcher = FileWatcher()
    private let io = DispatchQueue(label: "dev.abhijitsr.flick.catalog", qos: .userInitiated)

    public init(store: Store) {
        self.store = store
        self.clipboard = ClipboardSource(store: store)
        if let cache = store.loadCatalogCache() {
            self.snapshot = CatalogSnapshot(
                apps: cache.apps.map {
                    Item(
                        id: $0.bundleIdentifier ?? $0.path,
                        kind: .app,
                        title: $0.name,
                        subtitle: $0.path,
                        path: $0.path,
                        bundleIdentifier: $0.bundleIdentifier,
                        keywords: [$0.name]
                    )
                },
                files: cache.files.map {
                    Item(
                        id: $0.path,
                        kind: .file,
                        title: $0.name,
                        subtitle: $0.path,
                        path: $0.path,
                        keywords: [$0.name],
                        mtime: $0.mtime
                    )
                },
                commands: CommandSource.staticCommands() + CommandSource.runningAppCommands(),
                clipboard: clipboard.catalogItems()
            )
        } else {
            self.snapshot = CatalogSnapshot(
                apps: [],
                files: [],
                commands: CommandSource.staticCommands(),
                clipboard: clipboard.catalogItems()
            )
        }
    }

    public func start() {
        clipboard.onChange = { [weak self] in
            self?.refreshClipboard()
        }
        clipboard.start()
        watcher.onChanged = { [weak self] in
            self?.refreshFiles()
        }
        watcher.start(paths: FileSource.defaultRoots().map(\.path))
        refreshAll()
    }

    public func refreshRunning() {
        var next = snapshot
        let statics = CommandSource.staticCommands()
        next.commands = statics + CommandSource.runningAppCommands()
        snapshot = next
        onUpdate?()
    }

    public func search(query: String, usage: [String: UsageEntry]) -> [ResultGroup] {
        SearchEngine.search(query: query, snapshot: snapshot, usage: usage)
    }

    private func refreshClipboard() {
        var next = snapshot
        next.clipboard = clipboard.catalogItems()
        snapshot = next
        onUpdate?()
    }

    private func refreshFiles() {
        io.async { [weak self] in
            guard let self else { return }
            let files = FileSource.scan()
            DispatchQueue.main.async {
                self.snapshot.files = files
                self.persist()
                self.onUpdate?()
            }
        }
    }

    private func refreshAll() {
        io.async { [weak self] in
            guard let self else { return }
            let apps = AppSource.scan()
            let files = FileSource.scan()
            let commands = CommandSource.staticCommands() + CommandSource.runningAppCommands()
            DispatchQueue.main.async {
                self.snapshot.apps = apps
                self.snapshot.files = files
                self.snapshot.commands = commands
                self.snapshot.clipboard = self.clipboard.catalogItems()
                self.persist()
                self.onUpdate?()
            }
        }
    }

    private func persist() {
        let cache = CatalogCache(
            apps: snapshot.apps.compactMap { item in
                guard let path = item.path else { return nil }
                return CachedApp(path: path, name: item.title, bundleIdentifier: item.bundleIdentifier)
            },
            files: snapshot.files.compactMap { item in
                guard let path = item.path else { return nil }
                return CachedFile(path: path, name: item.title, mtime: item.mtime ?? .distantPast)
            }
        )
        store.saveCatalogCache(cache)
    }
}
