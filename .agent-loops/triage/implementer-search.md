# Implementer: search results + faster index

Worked in **main repo** `/Users/abhijitsr/flick` (not the home-dir worktree copy).
Agent worktree: `/Users/abhijitsr/.grok/worktrees/abhijitsr/subagent-01a0b2ed-a7c6-7971-a79e-c983e91c40cf`

## What changed

1. **HUD results are AppKit, not SwiftUI.** `OverlayView.swift` (NSHostingView) is gone. `ResultsPane.swift` rebuilds a stack of row views when `OverlayState` publishes. Dark HUD, white text, lazy `NSWorkspace` icons, selected-row accent fill. Empty query/list shows **No results** so a blank panel is distinguishable from a draw bug. Dismiss paths (Esc, ⌥Space, ⌘W, click-outside, header ×) are unchanged.

2. **Apps publish before files.** `Catalog.refreshAll()` scans apps, `onUpdate`s immediately, then scans files. `catalog.onUpdate` is wired in `OverlayState.init` to `refresh()` only. `refreshRunning()` no longer calls `onUpdate` (no recurse). `AppDelegate` creates `OverlayState` **before** `catalog.start()` so the first publish is not dropped.

3. **Faster indexing**
   - **AppSource:** `/Applications`, `/System/Applications`, `~/Applications`, one extra level (Utilities), plus `/System/Cryptexes/App/System/Applications` if present. Reads `Contents/Info.plist` (no `Bundle()`). No icons at scan time.
   - **FileSource:** Desktop/Documents/Downloads concurrently; skip `node_modules`, `.git`, `.build`, `DerivedData`, `.cache`, `Pods`, `venv`, `.venv`, `Carthage`, `.next`, `target`, `dist`, `build`, `__pycache__`, `.swiftpm`, hidden, packages, `*.icloud`; depth 8; cap 12k; metadata only (no iCloud materialize).
   - **OverlayState.refresh()** does not call `refreshRunning()` or re-read `usage.json`. `Store` caches usage in memory. Running apps refresh on HUD open (`refreshForShow()`) or quit/kill-like queries.

## How to verify

```
cd /Users/abhijitsr/flick
swift run FlickSelfTest    # passed
bash Scripts/package-app.sh
```

Packaged app: `/Users/abhijitsr/flick/dist/Flick.app`  
Installed and launched: `/Applications/Flick.app` (pid was live after `open`).

Manual: Option+Space, type `Safari` — Application rows with icons should appear without waiting on Downloads. Empty junk query should show **No results**.

Self-test also asserts Safari is indexed from system/cryptex roots, nested `.app` one level down, Info.plist display names, skip/depth rules, and quit/kill query detection.

## Files changed

- `Sources/FlickCore/Overlay/ResultsPane.swift` (new)
- `Sources/FlickCore/Overlay/OverlayView.swift` (deleted)
- `Sources/FlickCore/Overlay/OverlayController.swift`
- `Sources/FlickCore/Overlay/OverlayState.swift`
- `Sources/FlickCore/Catalog/AppSource.swift`
- `Sources/FlickCore/Catalog/FileSource.swift`
- `Sources/FlickCore/Catalog/Catalog.swift`
- `Sources/FlickCore/Catalog/Item.swift`
- `Sources/FlickCore/Store/Store.swift`
- `Sources/FlickCore/App/AppDelegate.swift`
- `Sources/FlickSelfTest/main.swift`

## Blockers

None. GUI search of the live HUD was not driven from this agent (app is installed and running). Unit tests cover indexing Safari and drawing-path replacement compiles into the packaged binary.
