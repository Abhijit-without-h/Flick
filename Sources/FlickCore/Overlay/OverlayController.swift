import AppKit
import SwiftUI

final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
public final class OverlayController: NSObject {
    public let state: OverlayState
    public var onHide: (() -> Void)?

    private let panel: HUDPanel
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var searchHeader: SearchHeader?
    private var isHiding = false

    public init(state: OverlayState) {
        self.state = state
        panel = HUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 72),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel()
    }

    public var isVisible: Bool { panel.isVisible }

    public func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        isHiding = false
        if state.previousApp == nil {
            state.previousApp = NSWorkspace.shared.frontmostApplication
        }
        state.query = ""
        state.showingActions = false
        state.error = nil
        state.selectedIndex = 0
        searchHeader?.field.stringValue = ""
        state.refresh()
        position()
        // Stay `.regular` while the HUD is up so it can be key: Esc, click-outside,
        // and Option+Space then dismiss instead of inserting a non-breaking space.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchHeader?.field)
        startMonitors()
    }

    public func hide() {
        guard !isHiding else { return }
        isHiding = true
        stopMonitors()
        panel.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        let previous = state.previousApp
        state.previousApp = nil
        if previous?.bundleIdentifier != FlickApp.bundleID {
            previous?.activate()
        }
        onHide?()
        isHiding = false
    }

    private func configurePanel() {
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.animationBehavior = .utilityWindow

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 1
        effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor

        let header = SearchHeader()
        header.onQuery = { [weak self] text in
            self?.state.queryChanged(text)
        }
        header.onSubmit = { [weak self] in
            if self?.state.submitDefault() == true { self?.hide() }
        }
        header.onCancel = { [weak self] in
            if self?.state.showingActions == true {
                self?.state.closeActions()
            } else {
                self?.hide()
            }
        }
        searchHeader = header

        let hosting = NSHostingView(rootView: OverlayView(state: state, onDismiss: { [weak self] in
            self?.hide()
        }))
        hosting.wantsLayer = true

        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let stack = NSStackView(views: [header, divider, hosting])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        header.translatesAutoresizingMaskIntoConstraints = false
        hosting.translatesAutoresizingMaskIntoConstraints = false

        effect.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            stack.topAnchor.constraint(equalTo: effect.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor),
            hosting.widthAnchor.constraint(equalTo: stack.widthAnchor),
            hosting.heightAnchor.constraint(greaterThanOrEqualToConstant: 280),
        ])

        panel.contentView = effect
        panel.setContentSize(NSSize(width: 640, height: 420))
    }

    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let width: CGFloat = 640
        let height = panel.frame.height
        let x = visible.midX - width / 2
        let y = visible.midY + visible.height * 0.12 - height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func startMonitors() {
        stopMonitors()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event) ? nil : event
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.panel.isVisible else { return }
                if !self.panel.frame.contains(NSEvent.mouseLocation) {
                    self.hide()
                }
            }
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }

    private func stopMonitors() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
            self.mouseMonitor = nil
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 53 { // escape
            if state.showingActions {
                state.closeActions()
            } else {
                hide()
            }
            return true
        }
        if event.keyCode == 13 && flags.contains(.command) { // ⌘W
            hide()
            return true
        }
        if event.keyCode == 49 && flags.contains(.option) && !flags.contains(.command) && !flags.contains(.control) {
            hide()
            return true
        }
        if event.keyCode == 125 { // down
            state.move(1)
            return true
        }
        if event.keyCode == 126 { // up
            state.move(-1)
            return true
        }
        if event.keyCode == 36 { // return
            if flags.contains(.command) {
                if state.reveal() { hide() }
            } else if state.submitDefault() {
                hide()
            }
            return true
        }
        if event.keyCode == 40 && flags.contains(.command) { // K
            if state.showingActions {
                state.closeActions()
            } else {
                state.openActions()
            }
            return true
        }
        if event.keyCode == 8 && flags.contains(.command) { // C
            if state.copyPath() { hide() }
            return true
        }
        return false
    }
}
