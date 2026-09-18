import AppKit
import SwiftUI

struct OverlayView: View {
    @ObservedObject var state: OverlayState
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if state.showingActions {
                actionList
            } else {
                results
            }
            footer
        }
        .background(Color.clear)
        .preferredColorScheme(.dark)
        .onAppear { state.refresh() }
    }

    private var indexedGroups: [(title: String, rows: [(index: Int, item: Item)])] {
        var offset = 0
        return state.groups.map { group in
            let rows = group.items.enumerated().map { idx, item in
                (index: offset + idx, item: item)
            }
            offset += group.items.count
            return (title: group.title, rows: rows)
        }
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(indexedGroups, id: \.title) { group in
                        Text(group.title.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(Color.white.opacity(0.38))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 2)
                        ForEach(group.rows, id: \.item.id) { row in
                            ResultRow(
                                item: row.item,
                                selected: row.index == state.selectedIndex
                            )
                            .id(row.index)
                            .onTapGesture {
                                state.selectedIndex = row.index
                                if state.submitDefault() { onDismiss() }
                            }
                        }
                    }
                }
                .padding(.bottom, 6)
            }
            .frame(maxHeight: 360)
            .onChange(of: state.selectedIndex) { _, index in
                proxy.scrollTo(index, anchor: .center)
            }
        }
    }

    private var actionList: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ACTIONS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.white.opacity(0.38))
                .padding(.horizontal, 16)
                .padding(.top, 8)
            ForEach(Array(state.actions.enumerated()), id: \.offset) { index, action in
                HStack {
                    Text(action.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white)
                    Spacer()
                    if index == state.actionIndex {
                        Text("↩")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(index == state.actionIndex ? Color.accentColor.opacity(0.32) : Color.clear)
                )
                .padding(.horizontal, 8)
                .onTapGesture {
                    state.actionIndex = index
                    if state.submitDefault() { onDismiss() }
                }
            }
            .padding(.bottom, 6)
        }
        .frame(maxHeight: 360)
    }

    private var footer: some View {
        HStack {
            if let error = state.error {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.orange.opacity(0.9))
            } else {
                Text("Flick")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            Spacer()
            HStack(spacing: 12) {
                hint("Esc", "Close")
                hint("⌘K", "Actions")
                hint("↩", defaultHint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
    }

    private var defaultHint: String {
        guard let item = state.selected else { return "Open" }
        return ActionPalette.defaultAction(for: item).title
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.4))
        }
    }
}

private struct ResultRow: View {
    let item: Item
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
                .cornerRadius(7)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.42))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if selected {
                Text(ActionPalette.defaultAction(for: item).title)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Color.accentColor.opacity(0.32) : Color.clear)
        )
        .padding(.horizontal, 8)
    }

    private var icon: NSImage {
        if let path = item.path {
            return NSWorkspace.shared.icon(forFile: path)
        }
        switch item.kind {
        case .clipboard:
            return NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
                ?? NSImage(named: NSImage.multipleDocumentsName)
                ?? NSImage()
        case .calculator:
            return NSImage(systemSymbolName: "function", accessibilityDescription: nil) ?? NSImage()
        case .command:
            return NSImage(systemSymbolName: "command", accessibilityDescription: nil) ?? NSImage()
        default:
            return NSImage(named: NSImage.applicationIconName) ?? NSImage()
        }
    }
}
