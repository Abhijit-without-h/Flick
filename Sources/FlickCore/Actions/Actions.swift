import AppKit
import ApplicationServices
import Foundation

public enum RowAction: String, Equatable {
    case open
    case reveal
    case copyPath
    case copyText
    case paste
    case quit
    case kill
    case run

    public var title: String {
        switch self {
        case .open: return "Open"
        case .reveal: return "Show in Finder"
        case .copyPath: return "Copy Path"
        case .copyText: return "Copy"
        case .paste: return "Paste"
        case .quit: return "Quit"
        case .kill: return "Kill"
        case .run: return "Run"
        }
    }
}

public struct ActionResult {
    public var dismiss: Bool
    public var error: String?

    public static let ok = ActionResult(dismiss: true, error: nil)
    public static func fail(_ message: String) -> ActionResult {
        ActionResult(dismiss: false, error: message)
    }
}

public enum ActionPalette {
    public static func actions(for item: Item) -> [RowAction] {
        switch item.kind {
        case .app:
            return [.open, .reveal, .copyPath, .quit, .kill]
        case .file:
            return [.open, .reveal, .copyPath]
        case .command:
            return [.run]
        case .clipboard:
            return AXIsProcessTrusted() ? [.copyText, .paste] : [.copyText]
        case .calculator:
            return item.text == nil ? [] : [.copyText]
        }
    }

    public static func defaultAction(for item: Item) -> RowAction {
        switch item.kind {
        case .app, .file: return .open
        case .command: return .run
        case .clipboard: return AXIsProcessTrusted() ? .paste : .copyText
        case .calculator: return .copyText
        }
    }
}

public enum ActionRunner {
    @discardableResult
    public static func run(_ action: RowAction, item: Item, previousApp: NSRunningApplication?) -> ActionResult {
        switch action {
        case .open:
            return open(item)
        case .reveal:
            return reveal(item)
        case .copyPath:
            guard let path = item.path else { return .fail("No path") }
            copy(path)
            return .ok
        case .copyText:
            guard let text = item.text ?? item.path else { return .fail("Nothing to copy") }
            copy(text)
            return .ok
        case .paste:
            guard let text = item.text else { return .fail("Nothing to paste") }
            copy(text)
            previousApp?.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                pasteKeystroke()
            }
            return .ok
        case .quit:
            return terminate(item, force: false)
        case .kill:
            return terminate(item, force: true)
        case .run:
            return runCommand(item, previousApp: previousApp)
        }
    }

    private static func open(_ item: Item) -> ActionResult {
        if let url = item.url {
            NSWorkspace.shared.open(url)
            return .ok
        }
        guard let path = item.path else { return .fail("Nothing to open") }
        if item.commandID == CommandID.openFolder {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            if !isDir.boolValue {
                return reveal(item)
            }
        }
        let url = URL(fileURLWithPath: path)
        let ok = NSWorkspace.shared.open(url)
        return ok ? .ok : .fail("Couldn’t open")
    }

    private static func reveal(_ item: Item) -> ActionResult {
        guard let path = item.path else { return .fail("No path") }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        return .ok
    }

    private static func terminate(_ item: Item, force: Bool) -> ActionResult {
        if let pid = item.runningPID,
           let app = NSRunningApplication(processIdentifier: pid)
        {
            if let bid = item.bundleIdentifier, app.bundleIdentifier != bid {
                return .fail("No running app matches")
            }
            let ok = force ? app.forceTerminate() : app.terminate()
            return ok ? .ok : .fail("Couldn’t \(force ? "kill" : "quit")")
        }
        if item.kind == .app, let bid = item.bundleIdentifier {
            let running = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bid }
            guard !running.isEmpty else { return .fail("No running app matches") }
            for app in running {
                _ = force ? app.forceTerminate() : app.terminate()
            }
            return .ok
        }
        return .fail("No running app matches")
    }

    private static func runCommand(_ item: Item, previousApp: NSRunningApplication?) -> ActionResult {
        switch item.commandID {
        case CommandID.calculator:
            return ActionRunner.run(.copyText, item: item, previousApp: previousApp)
        case CommandID.openURL:
            return open(item)
        case CommandID.openFolder:
            return open(item)
        case CommandID.emptyTrash:
            return appleScript(
                """
                tell application "Finder" to empty the trash
                """,
                denied: "Finder Automation not allowed"
            )
        case CommandID.lock:
            return appleScript(
                """
                tell application "System Events" to keystroke "q" using {control down, command down}
                """,
                denied: "System Events Automation not allowed"
            )
        case CommandID.sleep:
            return shell("/usr/bin/pmset", ["sleepnow"])
        case CommandID.darkMode:
            return appleScript(
                """
                tell application "System Events" to tell appearance preferences to set dark mode to not dark mode
                """,
                denied: "System Events Automation not allowed"
            )
        case CommandID.quitPrefix:
            return terminate(item, force: false)
        case CommandID.killPrefix:
            return terminate(item, force: true)
        default:
            if item.commandID == CommandID.quitPrefix || item.id.hasPrefix(CommandID.quitPrefix) {
                return terminate(item, force: false)
            }
            if item.id.hasPrefix(CommandID.killPrefix) {
                return terminate(item, force: true)
            }
            return .fail("Unknown command")
        }
    }

    private static func copy(_ string: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(string, forType: .string)
    }

    private static func pasteKeystroke() {
        guard AXIsProcessTrusted() else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let keyV: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func appleScript(_ source: String, denied: String) -> ActionResult {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        _ = script?.executeAndReturnError(&error)
        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int
            if number == -1743 || number == -10004 {
                return .fail(denied)
            }
            let message = error[NSAppleScript.errorMessage] as? String ?? denied
            return .fail(message)
        }
        return .ok
    }

    private static func shell(_ launchPath: String, _ arguments: [String]) -> ActionResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        do {
            try process.run()
            return .ok
        } catch {
            return .fail("Couldn’t run \(launchPath)")
        }
    }
}
