import AppKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private var overlay: OverlayController?
    private var catalog: Catalog?
    private let store = Store()
    private var recorderMonitor: Any?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let catalog = Catalog(store: store)
        self.catalog = catalog

        let state = OverlayState(catalog: catalog, store: store)
        let overlay = OverlayController(state: state)
        self.overlay = overlay
        catalog.start()

        setupStatusItem()
        setupHotKey()
        if CommandLine.arguments.contains("--show") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.overlay?.show()
            }
        }

        var prefs = store.loadPrefs()
        prefs.loginItemEnabled = LoginItem.isEnabled
        store.savePrefs(prefs)
    }

    public func applicationDidResignActive(_ notification: Notification) {
        overlay?.hide()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        hotKey?.unregister()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let icon = Bundle.main.image(forResource: "MenuBarIcon") {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = false
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: "Flick")
                    ?? NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Flick")
                button.image?.isTemplate = true
            }
            button.toolTip = "Flick"
        }
        item.menu = buildMenu()
        statusItem = item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Flick", action: #selector(openFlick), keyEquivalent: "")
            .target = self
        menu.addItem(NSMenuItem.separator())

        let login = NSMenuItem(
            title: LoginItem.isEnabled ? "Start at Login ✓" : "Start at Login",
            action: #selector(toggleLogin),
            keyEquivalent: ""
        )
        login.target = self
        menu.addItem(login)

        let hotkeyTitle = hotKey?.isRegistered == false
            ? "Change Hotkey (in use)…"
            : "Change Hotkey (\(hotKey?.displayString ?? "⌥Space"))…"
        let hotkeyItem = NSMenuItem(title: hotkeyTitle, action: #selector(changeHotKey), keyEquivalent: "")
        hotkeyItem.target = self
        menu.addItem(hotkeyItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Flick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private func refreshMenu() {
        statusItem?.menu = buildMenu()
        if hotKey?.isRegistered == false {
            statusItem?.button?.toolTip = "Flick — default hotkey in use. Rebind from the menu."
        } else {
            statusItem?.button?.toolTip = "Flick — \(hotKey?.displayString ?? "⌥Space")"
        }
    }

    private func setupHotKey() {
        let prefs = store.loadPrefs()
        let hotKey = HotKey(keyCode: prefs.keyCode, modifiers: prefs.modifiers)
        hotKey.onPressed = { [weak self] in
            Task { @MainActor in
                self?.overlay?.toggle()
            }
        }
        if !hotKey.register() {
            statusItem?.button?.toolTip = "Flick — hotkey in use. Rebind from the menu."
        }
        self.hotKey = hotKey
        refreshMenu()
    }

    @objc private func openFlick() {
        overlay?.show()
    }

    @objc private func toggleLogin() {
        let enabled = !LoginItem.isEnabled
        _ = LoginItem.setEnabled(enabled)
        var prefs = store.loadPrefs()
        prefs.loginItemEnabled = LoginItem.isEnabled
        store.savePrefs(prefs)
        refreshMenu()
    }

    @objc private func changeHotKey() {
        overlay?.hide()
        let alert = NSAlert()
        alert.messageText = "Press a new shortcut"
        alert.informativeText = "Use at least one modifier (⌥ ⌘ ⌃ ⇧). Escape cancels."
        alert.addButton(withTitle: "Cancel")
        alert.window.appearance = NSAppearance(named: .darkAqua)

        recorderMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 {
                NSApp.stopModal()
                return nil
            }
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !mods.isEmpty else { return nil }
            let carbon = HotKey.carbonModifiers(from: event.modifierFlags)
            if self.hotKey?.update(keyCode: UInt32(event.keyCode), modifiers: carbon) == true {
                var prefs = self.store.loadPrefs()
                prefs.keyCode = UInt32(event.keyCode)
                prefs.modifiers = carbon
                self.store.savePrefs(prefs)
                self.refreshMenu()
            } else {
                self.statusItem?.button?.toolTip = "Flick — Hotkey in use"
            }
            NSApp.stopModal()
            return nil
        }
        alert.runModal()
        if let recorderMonitor {
            NSEvent.removeMonitor(recorderMonitor)
            self.recorderMonitor = nil
        }
    }
}
