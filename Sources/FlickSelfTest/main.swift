import Foundation
import FlickCore

@main
enum FlickSelfTest {
    static var failures = 0

    static func expect(_ condition: Bool, _ message: String, file: String = #fileID, line: Int = #line) {
        if !condition {
            failures += 1
            fputs("FAIL \(file):\(line) \(message)\n", stderr)
        }
    }

    static func main() {
        testFuzzy()
        testRanker()
        testRouters()
        testFileFilter()
        testStore()
        if failures > 0 {
            fputs("\(failures) failure(s)\n", stderr)
            exit(1)
        }
        print("All Flick core tests passed.")
    }

    static func testFuzzy() {
        let prefix = Fuzzy.score(query: "saf", text: "Safari")
        let later = Fuzzy.score(query: "ari", text: "Safari")
        expect(prefix != nil && later != nil && prefix! > later!, "prefix should beat later subsequence")
        expect(Fuzzy.score(query: "sfr", text: "Safari") != nil, "sfr matches Safari")
        expect(Fuzzy.score(query: "vsc", text: "Visual Studio Code") != nil, "vsc matches VS Code")
        expect(Fuzzy.score(query: "xyz", text: "Safari") == nil, "xyz misses Safari")
        expect(Fuzzy.score(query: "", text: "Safari") == 0, "empty query scores 0")
    }

    static func testRanker() {
        let safari = Item(id: "safari", kind: .app, title: "Safari")
        let now = Date()
        let used = Ranker(usage: ["safari": UsageEntry(count: 20, lastUsed: now)], now: now)
        let cold = Ranker(usage: [:], now: now)
        let usedScore = used.score(query: "sa", item: safari)!
        let coldScore = cold.score(query: "sa", item: safari)!
        expect(usedScore > coldScore, "usage should boost Safari")

        let app = Item(id: "safari", kind: .app, title: "Safari", path: "/Applications/Safari.app")
        let file = Item(id: "/tmp/a.pdf", kind: .file, title: "a.pdf", path: "/tmp/a.pdf", mtime: Date())
        let groups = Ranker(usage: [
            "safari": UsageEntry(count: 3, lastUsed: Date()),
            "/tmp/a.pdf": UsageEntry(count: 1, lastUsed: Date().addingTimeInterval(-10)),
        ]).emptyQueryItems(apps: [app], files: [file], clipboard: [], commands: CommandSource.staticCommands())
        expect(groups.contains { $0.title == "Applications" && $0.items.contains { $0.id == "safari" } }, "recents include Safari")
        expect(groups.contains { $0.title == "Files" && $0.items.contains { $0.id == "/tmp/a.pdf" } }, "recents include file")
    }

    static func testRouters() {
        expect(Calculator.looksLikeMath("12*8"), "12*8 is math")
        expect(!Calculator.looksLikeMath("safari"), "safari is not math")
        expect(Calculator.evaluate("12*8") == "96", "12*8 == 96")
        expect(Calculator.evaluate("=2+2") == "4", "2+2 == 4")
        expect(Calculator.evaluate("(1+2)*3") == "9", "(1+2)*3 == 9")
        expect(Calculator.evaluate("2+") == nil, "2+ cannot evaluate")
        expect(URLRouter.url(from: "https://example.com")?.absoluteString == "https://example.com", "https URL")
        expect(URLRouter.url(from: "example.com/x")?.absoluteString == "https://example.com/x", "bare domain")
        expect(URLRouter.url(from: "safari") == nil, "safari is not a URL")
        expect(PathRouter.looksLikePath("~/Documents"), "~ path")
        expect(!PathRouter.expanded("~/Desktop").contains("~"), "tilde expands")

        let snapshot = CatalogSnapshot(apps: [], files: [], commands: [], clipboard: [])
        let math = SearchEngine.search(query: "12*8", snapshot: snapshot, usage: [:]).flatMap(\.items)
        expect(math.contains { $0.kind == .calculator && $0.text == "96" }, "search engine calculator")
        let bad = SearchEngine.search(query: "2+", snapshot: snapshot, usage: [:]).flatMap(\.items)
        expect(bad.contains { $0.title == "Cannot evaluate" }, "bad math message")
    }

    static func testFileFilter() {
        expect(FileFilter.shouldSkip(name: "node_modules", isDirectory: true), "skip node_modules")
        expect(FileFilter.shouldSkip(name: ".env", isDirectory: false), "skip dotfiles")
        expect(!FileFilter.shouldSkip(name: "Report.pdf", isDirectory: false), "keep pdf")
        expect(PasteboardPrivacy.isConcealed(types: [PasteboardPrivacy.concealedType]), "concealed")
        expect(!PasteboardPrivacy.isConcealed(types: ["public.utf8-plain-text"]), "plain text not concealed")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("flick-filter-\(UUID().uuidString)", isDirectory: true)
        let keep = root.appendingPathComponent("keep.txt")
        let hidden = root.appendingPathComponent(".secret")
        let modules = root.appendingPathComponent("node_modules", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: modules, withIntermediateDirectories: true)
            try "ok".write(to: keep, atomically: true, encoding: .utf8)
            try "no".write(to: hidden, atomically: true, encoding: .utf8)
            try "no".write(to: modules.appendingPathComponent("pkg.js"), atomically: true, encoding: .utf8)
            let items = FileSource.scanTree(root: root)
            expect(items.map(\.title) == ["keep.txt"], "scan skips ignored paths, got \(items.map(\.title))")
        } catch {
            expect(false, "fixture setup failed \(error)")
        }
        try? FileManager.default.removeItem(at: root)
    }

    static func testStore() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("flick-store-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = Store(root: root)
        let prefs = Prefs(keyCode: 49, modifiers: 2048, loginItemEnabled: false)
        store.savePrefs(prefs)
        expect(store.loadPrefs() == prefs, "prefs round-trip")
        store.recordUsage(id: "safari", at: Date(timeIntervalSince1970: 1_700_000_000))
        store.recordUsage(id: "safari", at: Date(timeIntervalSince1970: 1_700_000_100))
        expect(store.loadUsage()["safari"]?.count == 2, "usage count 2")
    }
}
