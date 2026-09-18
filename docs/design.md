# Flick — Option+Space launcher

Date: 2026-09-17
App: Flick (`dev.abhijitsr.flick`)
Platform: macOS 14+ (built and used on Apple Silicon, macOS 26)

## Problem

Spotlight (Command+Space) is slow to appear and noisy: apps, files, web suggestions, and system results compete. Flick is a smaller, always-resident launcher bound to Option+Space. It searches a known-small catalog (apps, a few user folders, clipboard, commands) and returns in a few milliseconds.

## Goals

- Option+Space toggles a centered dark HUD. First paint from a pre-created window in under 16ms.
- Search apps, Desktop/Documents/Downloads, Flick recents, clipboard history, and a fixed command set.
- Keyboard-first. Mouse works; it is not the design center.
- Stay resident in the menu bar. No Dock icon. Start at login.
- Feel faster than Spotlight for the things it covers. Never wait on a disk-wide index.

## Non-goals (v1)

- Plugins / extension API
- Full-disk or Spotlight/`mdfind` search
- Emoji, snippets, window management, web search
- Image clipboard history
- Mac App Store / sandbox / notarization
- Windows or Linux
- Custom themes beyond the dark HUD

## Shape

One native Swift app. `LSUIElement` (agent). Menu bar extra. Single process. In-memory catalog plus a tiny on-disk cache.

```
Flick.app
├── App            lifecycle, hotkey, login item, menu bar
├── Overlay        NSPanel + SwiftUI results + action palette
├── Catalog        AppSource, FileSource, CommandSource, ClipboardSource
├── Search         fuzzy scorer + usage ranker + prefix routers
├── Actions        launch, open, reveal, copy, quit, kill, system
└── Store          usage, clipboard, catalog cache, hotkey pref
```

No Tauri, no WebView, no helper daemon.

## Overlay

- Always-dark HUD. `NSVisualEffectView` with a dark material and a thin white hairline. Not adaptive.
- Grouped results: Applications, Files, Commands, Clipboard. Empty groups omitted.
- Footer: `⌘K Actions` · `⌘↩ Show in Finder` · `↩ Open` (label follows the selected row’s default action).
- Width 640pt, centered on the display that currently has the mouse. Height grows with rows, capped (~8 rows + headers + footer).
- Window is created hidden at launch and only ordered in/out. Option+Space toggles. Click outside or Escape dismisses and returns focus to the previous app.

## Search and keyboard

Empty query: Flick recents (apps and files opened through Flick) plus the top clipboard item. If there is no usage yet, show recently modified files from the indexed folders and a short command list.

Typed query: candidate must be a subsequence of the name (case-insensitive). Score = `0.7 * fuzzy + 0.3 * usage`.

Fuzzy bonuses: consecutive characters, word-start / camelCase hits, prefix of the display name. Gap penalty. Usage is frequency with recency decay, persisted in Store.

Prefix routers, evaluated before mixed search:

| Query | Result |
| --- | --- |
| Looks like math (`12*8`, `= 2+2`, leading `=`) | Calculator row via `NSExpression`. Enter copies the result. Invalid expression → “Cannot evaluate”, panel stays open |
| URL-like (`https://…`, `example.com/x`) | Open URL |
| Starts with `~` or `/` | Open folder (tilde expanded) |

Keys:

| Key | Action |
| --- | --- |
| ↓ ↑ | Move selection |
| ↩ | Default action for the row |
| ⌘↩ | Show in Finder (apps and files) |
| ⌘C | Copy path (apps and files) or copy text (clipboard / calculator) |
| ⌘K | Action palette for the selected row |
| Esc | Dismiss |
| Option+Space | Toggle (dismiss if visible) |

## Catalog

**Apps.** Scan `/Applications`, `/System/Applications`, `~/Applications`. Top-level `.app` only (do not recurse into bundle contents). Record display name, bundle id, URL, icon via `NSWorkspace`.

**Files.** Recursive scan of Desktop, Documents, Downloads. Skip names starting with `.`, and directory names `node_modules`, `.git`, `.build`, `DerivedData`, `.cache`. Missing folders are skipped. Recents are Flick’s own usage log, not Apple’s recent-documents list.

**Watch.** FSEvents on those three folders. Add/remove/rename update the in-memory catalog. No full rescan unless the watcher dies.

**Clipboard.** Poll `NSPasteboard.general.changeCount`. Keep the last 20 strings. Skip `org.nspasteboard.concealedType` (password managers). No images. Persist across launches.

**Commands.** Static list below, always in the catalog, filtered by fuzzy match on name and keywords (`kill`, `quit`, `trash`, `sleep`, …).

Cold start: load the last catalog cache from Application Support, mark ready, refresh sources on a background queue, swap atomically.

## Commands

| Command | Default action |
| --- | --- |
| Calculator | Copy result to clipboard |
| Open URL | `NSWorkspace.open` |
| Open folder | Open in Finder |
| Show in Finder | `selectFile` |
| Copy path | Pasteboard |
| Quit app | `NSRunningApplication.terminate` on the matched running app |
| Kill process | `forceTerminate` on the matched running app. No confirmation dialog. Quit and Kill are separate rows. |
| Empty Trash | Finder Automation (`empty trash`) |
| Lock Screen | Control-Command-Q via System Events |
| Sleep | `pmset sleepnow` / System Events sleep |
| Toggle Dark Mode | System Events appearance preferences |
| Clipboard history | Enter copies the selected item. If Accessibility is granted, also paste into the previous app (⌘V). Otherwise copy-only. |

Running-app commands (Quit, Kill) expand to one row per matching running app when the query matches the command or the app name.

## Action palette (⌘K)

Depends on row kind:

- App: Open, Show in Finder, Copy path, Quit, Kill
- File: Open, Show in Finder, Copy path, Copy filename
- Command: Run
- Clipboard: Copy, Paste (disabled until Accessibility is granted)

## Store

Location: `~/Library/Application Support/dev.abhijitsr.flick/`

- `catalog-cache.json` — serialized apps + files (paths, names, mtimes). Not icons.
- `usage.json` — bundle id or file path → `{count, lastUsed}`.
- `clipboard.json` — last 20 strings.
- `prefs.json` — hotkey keycode + modifiers (default Option+Space).

## Permissions and packaging

- Not sandboxed. Ad-hoc signed local `.app`. Not notarized in v1.
- Login item via `SMAppService`.
- User folders: no Full Disk Access.
- Empty Trash and Dark Mode: Automation prompt for Finder / System Events on first use. If denied, the command row shows an error subtitle and does nothing destructive.
- Accessibility: optional, only for clipboard paste-into-front-app. Never block launch on it.
- Menu bar extra includes: Open Flick, Start at Login toggle, Change Hotkey, Quit Flick.
- Change Hotkey opens a small recorder window: the next modifier+key press is captured and stored in `prefs.json`. Cancel with Escape. If the combo fails to register, keep the previous combo and show “Hotkey in use”.
- If Option+Space is already registered at launch, the menu-bar extra is still created so the user can rebind. A one-line menu-bar tooltip/alert says the default hotkey failed.

## Errors

- Indexed folder missing or unreadable: skip, do not crash, do not nag.
- Launch/open fails: flash an error subtitle on the selected row; keep the panel open.
- Kill/Quit with no matching running app: “No running app matches”.
- Empty Trash denied: “Finder Automation not allowed”.
- Catalog refresh failure: keep the last good in-memory catalog.

## Performance budget

| Event | Budget |
| --- | --- |
| Hotkey → first pixel | < 16ms (window already exists) |
| Keystroke → ranked rows | < 8ms at ≤ 20k catalog items |
| Cached cold start → interactive | < 300ms |
| First-run folder scan | Background; UI is usable with apps + commands immediately |

Icons resolved lazily and cached in memory. Search runs in-process; no XPC.

## Testing

- Unit: fuzzy scorer (prefix, subsequence, camelCase, misses).
- Unit: ranking mix of fuzzy vs usage.
- Unit: ignore rules against fixture directory trees.
- Unit: prefix routers (math, URL, path).
- Unit: concealed pasteboard skip.
- Manual: hotkey toggle, launch app, open file, FSEvents add/delete, clipboard capture, login item, dismiss restores previous app.

## Project layout

This machine has Command Line Tools and the macOS 26 SDK, not a full Xcode.app. Ship as a SwiftPM executable wrapped in an `.app` bundle.

```
flick/
  Package.swift
  Sources/Flick/
    Info.plist             # copied into the bundle (LSUIElement, bundle id, usage strings)
    App/
    Overlay/
    Catalog/
    Search/
    Actions/
    Store/
  Tests/FlickTests/
  Scripts/package-app.sh   # swift build -c release → dist/Flick.app + ad-hoc sign
  docs/superpowers/specs/
```

`swift test` for unit tests. `Scripts/package-app.sh` produces `dist/Flick.app`. Install by copying to `/Applications` and launching once.

## Success

Option+Space feels instant. Typing three letters of an app name and hitting Enter is faster than Spotlight. File results only come from the three user folders. Commands in the table above all run. The app survives a reboot via the login item.
