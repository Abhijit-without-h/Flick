import AppKit

final class SearchHeader: NSView, NSTextFieldDelegate {
    var onQuery: ((String) -> Void)?
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?

    let field = HUDSearchField()
    private let icon = NSImageView()
    private let closeButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        icon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        icon.contentTintColor = NSColor.white.withAlphaComponent(0.45)
        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        field.textColor = .white
        field.placeholderString = "Search apps, files, commands"
        field.delegate = self
        field.onCancel = { [weak self] in self?.onCancel?() }
        (field.cell as? NSTextFieldCell)?.placeholderAttributedString = NSAttributedString(
            string: "Search apps, files, commands",
            attributes: [
                .foregroundColor: NSColor.white.withAlphaComponent(0.28),
                .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            ]
        )
        field.translatesAutoresizingMaskIntoConstraints = false

        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.contentTintColor = NSColor.white.withAlphaComponent(0.35)
        closeButton.imagePosition = .imageOnly
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.toolTip = "Close (Esc)"

        addSubview(icon)
        addSubview(field)
        addSubview(closeButton)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 52),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            field.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            field.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            field.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 22),
            closeButton.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    @objc private func closeTapped() {
        onCancel?()
    }

    required init?(coder: NSCoder) { nil }

    func controlTextDidChange(_ obj: Notification) {
        onQuery?(field.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            onSubmit?()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            onCancel?()
            return true
        }
        if commandSelector == #selector(NSResponder.moveDown(_:))
            || commandSelector == #selector(NSResponder.moveUp(_:))
        {
            return false
        }
        return false
    }
}

/// Intercepts Esc, ⌘W, and ⌥Space so the HUD can close even while the field is focused.
final class HUDSearchField: NSTextField {
    var onCancel: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 {
            onCancel?()
            return true
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 13 && flags.contains(.command) { // W
            onCancel?()
            return true
        }
        if event.keyCode == 49 && flags.contains(.option) && !flags.contains(.command) && !flags.contains(.control) {
            onCancel?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 49 && flags.contains(.option) {
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }

    override func insertText(_ insertString: Any) {
        if let string = insertString as? String, string == "\u{00A0}" || string == " " {
            let flags = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
            if flags.contains(.option) {
                onCancel?()
                return
            }
        }
        super.insertText(insertString)
    }
}
