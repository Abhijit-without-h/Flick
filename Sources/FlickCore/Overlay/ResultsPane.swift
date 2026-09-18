import AppKit
import Combine

/// AppKit results list. SwiftUI `NSHostingView` often never redraws inside this NSPanel.
final class ResultsPane: NSView {
    private let state: OverlayState
    private let onDismiss: () -> Void
    private var cancellables = Set<AnyCancellable>()
    private var iconCache: [String: NSImage] = [:]
    private var selectedRow: ResultRowView?

    private let scrollView = NSScrollView()
    private let stack = FlippedStackView()
    private let footer = FooterBar()
    private let emptyLabel = NSTextField(labelWithString: "No results")

    init(state: OverlayState, onDismiss: @escaping () -> Void) {
        self.state = state
        self.onDismiss = onDismiss
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        setup()
        bind()
        reload()
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let width = scrollView.contentView.bounds.width
        if width > 0, abs(stack.frame.width - width) > 0.5 {
            stack.frame.size.width = width
        }
    }

    private func setup() {
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 8, right: 0)
        stack.translatesAutoresizingMaskIntoConstraints = true
        scrollView.documentView = stack

        emptyLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        emptyLabel.textColor = NSColor.white.withAlphaComponent(0.55)
        emptyLabel.alignment = .center
        emptyLabel.drawsBackground = false
        emptyLabel.isBordered = false
        emptyLabel.isEditable = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        footer.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        addSubview(emptyLabel)
        addSubview(footer)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footer.topAnchor),
            footer.leadingAnchor.constraint(equalTo: leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 34),
            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
    }

    private func bind() {
        state.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.reload() }
            }
            .store(in: &cancellables)
    }

    private func reload() {
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        selectedRow = nil

        let width = max(scrollView.contentView.bounds.width, 640)

        if state.showingActions {
            emptyLabel.isHidden = !state.actions.isEmpty
            if state.actions.isEmpty { emptyLabel.stringValue = "No results" }
            stack.addArrangedSubview(headerView("ACTIONS"))
            for (index, action) in state.actions.enumerated() {
                let row = ResultRowView()
                row.configureAction(action, selected: index == state.actionIndex)
                row.onActivate = { [weak self] in
                    guard let self else { return }
                    self.state.actionIndex = index
                    if self.state.submitDefault() { self.onDismiss() }
                }
                row.onSelect = { [weak self] in
                    self?.state.actionIndex = index
                }
                if index == state.actionIndex { selectedRow = row }
                stack.addArrangedSubview(row)
                row.widthAnchor.constraint(equalToConstant: width).isActive = true
            }
        } else if state.groups.isEmpty {
            emptyLabel.isHidden = false
            emptyLabel.stringValue = "No results"
        } else {
            emptyLabel.isHidden = true
            var flat = 0
            for group in state.groups {
                stack.addArrangedSubview(headerView(group.title))
                for item in group.items {
                    let index = flat
                    let row = ResultRowView()
                    row.configure(
                        item: item,
                        selected: index == state.selectedIndex,
                        icon: icon(for: item)
                    )
                    row.onActivate = { [weak self] in
                        guard let self else { return }
                        self.state.selectedIndex = index
                        if self.state.submitDefault() { self.onDismiss() }
                    }
                    row.onSelect = { [weak self] in
                        self?.state.selectedIndex = index
                    }
                    if index == state.selectedIndex { selectedRow = row }
                    stack.addArrangedSubview(row)
                    row.widthAnchor.constraint(equalToConstant: width).isActive = true
                    flat += 1
                }
            }
        }

        stack.frame.size.width = width
        stack.layoutSubtreeIfNeeded()
        let height = max(stack.fittingSize.height, 1)
        stack.frame = NSRect(x: 0, y: 0, width: width, height: height)

        footer.configure(error: state.error, defaultAction: defaultHint)
        scrollToSelection()
    }

    private var defaultHint: String {
        guard let item = state.selected else { return "Open" }
        return ActionPalette.defaultAction(for: item).title
    }

    private func scrollToSelection() {
        guard let selectedRow else { return }
        var rect = selectedRow.frame
        rect = rect.insetBy(dx: 0, dy: -12)
        stack.scrollToVisible(rect)
    }

    private func headerView(_ title: String) -> NSView {
        let wrap = NSView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = NSColor.white.withAlphaComponent(0.40)
        label.drawsBackground = false
        label.isBordered = false
        label.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(label)
        NSLayoutConstraint.activate([
            wrap.heightAnchor.constraint(equalToConstant: 26),
            wrap.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            label.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -2),
        ])
        return wrap
    }

    private func icon(for item: Item) -> NSImage {
        if let path = item.path {
            if let cached = iconCache[path] { return cached }
            let image = NSWorkspace.shared.icon(forFile: path)
            image.size = NSSize(width: 28, height: 28)
            iconCache[path] = image
            return image
        }
        let name: String
        switch item.kind {
        case .clipboard: name = "doc.on.clipboard"
        case .calculator: name = "function"
        case .command: name = "command"
        case .app: name = "app"
        case .file: name = "doc"
        }
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)
            ?? NSImage(named: NSImage.applicationIconName)
            ?? NSImage()
    }
}

private final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }
}

private final class ResultRowView: NSView {
    var onActivate: (() -> Void)?
    var onSelect: (() -> Void)?

    private let pill = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private var iconWidth: NSLayoutConstraint?

    override var acceptsFirstResponder: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        pill.wantsLayer = true
        pill.layer?.cornerRadius = 8
        pill.layer?.masksToBounds = true
        pill.translatesAutoresizingMaskIntoConstraints = false

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 7
        iconView.layer?.masksToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = NSFont.systemFont(ofSize: 13.5, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.drawsBackground = false
        titleLabel.isBordered = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.45)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.drawsBackground = false
        subtitleLabel.isBordered = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.45)
        hintLabel.alignment = .right
        hintLabel.drawsBackground = false
        hintLabel.isBordered = false
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(pill)
        pill.addSubview(iconView)
        pill.addSubview(titleLabel)
        pill.addSubview(subtitleLabel)
        pill.addSubview(hintLabel)

        let iconW = iconView.widthAnchor.constraint(equalToConstant: 28)
        iconWidth = iconW
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 46),
            pill.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            pill.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            pill.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            pill.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            iconView.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            iconW,
            iconView.heightAnchor.constraint(equalToConstant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: hintLabel.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: pill.topAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: hintLabel.leadingAnchor, constant: -8),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            hintLabel.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12),
            hintLabel.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            hintLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 110),
        ])
    }

    required init?(coder: NSCoder) { nil }

    func configure(item: Item, selected: Bool, icon: NSImage) {
        iconView.image = icon
        iconView.isHidden = false
        iconWidth?.constant = 28
        titleLabel.stringValue = item.title
        titleLabel.textColor = .white
        subtitleLabel.stringValue = item.subtitle
        subtitleLabel.isHidden = item.subtitle.isEmpty
        hintLabel.stringValue = selected ? ActionPalette.defaultAction(for: item).title : ""
        applySelection(selected)
    }

    func configureAction(_ action: RowAction, selected: Bool) {
        iconView.image = nil
        iconView.isHidden = true
        iconWidth?.constant = 0
        titleLabel.stringValue = action.title
        titleLabel.textColor = .white
        subtitleLabel.stringValue = ""
        subtitleLabel.isHidden = true
        hintLabel.stringValue = selected ? "↩" : ""
        applySelection(selected)
    }

    private func applySelection(_ selected: Bool) {
        pill.layer?.backgroundColor = selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.38).cgColor
            : NSColor.white.withAlphaComponent(0.0).cgColor
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?()
    }

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            onActivate?()
        }
    }
}

private final class FooterBar: NSView {
    private let brand = NSTextField(labelWithString: "Flick")
    private let hints = NSTextField(labelWithString: "")
    private let line = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        line.translatesAutoresizingMaskIntoConstraints = false

        brand.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        brand.textColor = NSColor.white.withAlphaComponent(0.40)
        brand.drawsBackground = false
        brand.isBordered = false
        brand.translatesAutoresizingMaskIntoConstraints = false

        hints.font = NSFont.systemFont(ofSize: 11)
        hints.textColor = NSColor.white.withAlphaComponent(0.40)
        hints.alignment = .right
        hints.drawsBackground = false
        hints.isBordered = false
        hints.translatesAutoresizingMaskIntoConstraints = false

        addSubview(line)
        addSubview(brand)
        addSubview(hints)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.topAnchor.constraint(equalTo: topAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
            brand.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            brand.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1),
            hints.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            hints.centerYAnchor.constraint(equalTo: brand.centerYAnchor),
            hints.leadingAnchor.constraint(greaterThanOrEqualTo: brand.trailingAnchor, constant: 12),
        ])
    }

    required init?(coder: NSCoder) { nil }

    func configure(error: String?, defaultAction: String) {
        if let error {
            brand.stringValue = error
            brand.textColor = NSColor.systemOrange.withAlphaComponent(0.95)
        } else {
            brand.stringValue = "Flick"
            brand.textColor = NSColor.white.withAlphaComponent(0.40)
        }
        hints.stringValue = "Esc Close   ⌘K Actions   ↩ \(defaultAction)"
        hints.textColor = NSColor.white.withAlphaComponent(0.40)
    }
}
