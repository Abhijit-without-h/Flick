import AppKit
import Foundation

public enum CommandID {
    public static let emptyTrash = "emptyTrash"
    public static let lock = "lock"
    public static let sleep = "sleep"
    public static let darkMode = "toggleDarkMode"
    public static let quitPrefix = "quit:"
    public static let killPrefix = "kill:"
    public static let calculator = "calculator"
    public static let openURL = "openURL"
    public static let openFolder = "openFolder"
}

public enum CommandSource {
    public static func staticCommands() -> [Item] {
        [
            Item(
                id: CommandID.emptyTrash,
                kind: .command,
                title: "Empty Trash",
                subtitle: "Move Trash contents to oblivion",
                keywords: ["trash", "bin", "empty"],
                commandID: CommandID.emptyTrash
            ),
            Item(
                id: CommandID.lock,
                kind: .command,
                title: "Lock Screen",
                subtitle: "Control-Command-Q",
                keywords: ["lock", "screen", "login"],
                commandID: CommandID.lock
            ),
            Item(
                id: CommandID.sleep,
                kind: .command,
                title: "Sleep",
                subtitle: "Put this Mac to sleep",
                keywords: ["sleep", "suspend"],
                commandID: CommandID.sleep
            ),
            Item(
                id: CommandID.darkMode,
                kind: .command,
                title: "Toggle Dark Mode",
                subtitle: "Switch system appearance",
                keywords: ["dark", "light", "appearance", "theme"],
                commandID: CommandID.darkMode
            ),
        ]
    }

    public static func runningAppCommands() -> [Item] {
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
                && $0.bundleIdentifier != FlickApp.bundleID
                && $0.localizedName != nil
        }
        var items: [Item] = []
        for app in running {
            let name = app.localizedName ?? "App"
            let pid = app.processIdentifier
            let path = app.bundleURL?.path
            items.append(
                Item(
                    id: "\(CommandID.quitPrefix)\(pid)",
                    kind: .command,
                    title: "Quit \(name)",
                    subtitle: app.isTerminated ? "Not running" : "Running now",
                    path: path,
                    bundleIdentifier: app.bundleIdentifier,
                    keywords: ["quit", "exit", name],
                    commandID: CommandID.quitPrefix,
                    runningPID: pid
                )
            )
            items.append(
                Item(
                    id: "\(CommandID.killPrefix)\(pid)",
                    kind: .command,
                    title: "Kill \(name)",
                    subtitle: "Force quit",
                    path: path,
                    bundleIdentifier: app.bundleIdentifier,
                    keywords: ["kill", "force", name],
                    commandID: CommandID.killPrefix,
                    runningPID: pid
                )
            )
        }
        return items
    }
}
