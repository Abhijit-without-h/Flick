# Flick CPU / indexing performance eval

Date: 2026-09-18  
Host: macOS 26.5.1 ARM64  
Method: throwaway release microbench at `.agent-loops/perf-bench` (`swift run -c release PerfBench`), `find`/`os.walk` inventory, `ps` + `sample` of `dist/Flick.app` (pid 53456, 2s).  
FlickCore was not modified. Bench is not in `Sources/`.

Design budget (`docs/design.md`): **keystroke → ranked rows < 8ms at ≤ 20k items**; first-run scan background with **apps usable immediately**; FSEvents **must not full-rescan**.

## What was measured

| Path | Cold | Warm / avg | Items |
| --- | --- | --- | --- |
| `AppSource.scan()` | **85–91 ms** | **1.6–1.9 ms** | 75 apps (top-level `/Applications`, `/System/Applications`, `~/Applications` only) |
| `FileSource.scan(Desktop)` | 0.13 ms | — | 0 |
| `FileSource.scan(Documents)` | **14.5–15.0 ms** | — | **619** |
| `FileSource.scan(Downloads)` | **5.1–5.2 ms** | — | **311** |
| `FileSource.scan()` all roots | **16.2–16.8 ms** | 16.2 ms | **930** |
| `Catalog.refreshAll` sequential (apps then files) | ~107 ms (91+17) | **18.4–19.8 ms** | 75 + 930 |
| `Store.loadCatalogCache()` | **3.2–3.7 ms** | — | 75 + 930, 202 KB |
| `Store.saveCatalogCache()` pretty JSON | **3.6 ms** | — | 75 + 930 (runs on **main** after scan) |
| `CommandSource.runningAppCommands()` | **3.9–8.8 ms** | **0.01–0.03 ms** | 10 (5 regular apps × quit+kill) |
| `Store.loadUsage()` | 0.8–1.8 ms | **0.04–0.13 ms** | 5 keys, 543 B |
| `SearchEngine.search("")` | — | **0.12–0.14 ms** | 6 recents |
| `SearchEngine.search("s")` | max **61.6 ms** (1st run) | **19.0–24.6 ms** | 24 rows, N=1020 |
| `SearchEngine.search("sa")` | — | **18.2–19.0 ms** | 24 rows |
| `search("safari"|"pdf"|"report")` | — | **14.8–16.6 ms** | 24 |
| `search("xyzxyzxyz")` miss | — | **14.0–14.5 ms** | 0 (still scans all) |
| `search("12*8")` calculator | — | **13.9 ms** | 1 (still scans all) |
| Simulated `OverlayState.refresh("sa")` | — | **18.3–18.7 ms** | running 0.02 + loadUsage 0.07 + search 18.2 |
| `Fuzzy.bestScore` 4 texts/item, q=sa | — | **13.7 ms** | **903 / 1005 hits** |
| `Fuzzy.score` title only, q=sa | — | **5.5 ms** | 264 hits |
| title+keywords only (skip path) | — | 13.4 ms | 264 hits |
| `Fuzzy.score` 10k synthetic titles | — | **6.4 ms** | 0.64 µs/item |
| `NSWorkspace.icon(forFile:)` 75 apps | **39–106 ms** (0.5–1.4 ms/icon) | **9.4 ms** (0.13 ms/icon) | 75 |
| icon 48 files | 3.1–4.3 ms | 2.2 ms | 48 |
| icon HUD result set (24) | — | **2.0 ms** | 24 |
| Idle `Flick.app` after launch | 3.8% CPU @ 3s (scan) | **0.0% CPU**, RSS 47–65 MB | sample: main thread in `mach_msg` |

`snapshot.all` in the bench: **1020** (75 apps + 930 files + 14 commands + 1 clipboard). Average `Item.searchTexts` count: **4**.

## Disk vs indexed (why scan is “fast” here)

| Root | `find -type f` | After skip (hidden / `node_modules` / `.git` / …) | Indexed by `FileSource` |
| --- | --- | --- | --- |
| Desktop | 3 | 1 | 0 |
| Documents | 6,888 | 621 | 619 |
| Downloads | 41,582 | 314 | 311 |
| **Total** | **48,473** | **~936** | **930** |

`node_modules` that are **not** indexed but **are** still under the FSEvents roots:

- `~/Documents/New project/node_modules` — 5,790 files
- `~/Downloads/Chat Interface Creation/node_modules` — 27,629 files
- `~/Downloads/SMIT UI UX Designer Portfolio/node_modules` — 13,507 files
- **46,926 files** that `FileFilter` skips on scan, but `FileWatcher` (`kFSEventStreamCreateFlagFileEvents`) still observes.

Skip is working: Documents 15 ms / Downloads 5 ms. That is **this machine**. The design allows up to 20k indexed items; search is already over budget at 1k.

## Keystroke → results (N × fuzzy)

`OverlayState.queryChanged` → `refresh()` on the main actor, every character, no debounce:

1. `catalog.refreshRunning()` — rebuild quit/kill commands.
2. `store.loadUsage()` — JSON read from disk.
3. `SearchEngine.search` — `for item in snapshot.all` + `Ranker.score` → `Fuzzy.bestScore(query, item.searchTexts)`.
4. `@Published groups` → SwiftUI `OverlayView` / `ResultRow.body` → `NSWorkspace.icon(forFile:)` with **no cache**.

`Item.searchTexts` is `[title, subtitle] + keywords`. Files: `title == keywords[0]` (duplicate name) and `subtitle` is a **relative path**. For query `"sa"`:

- title hits: **264**
- keyword hits: **264** (same names)
- **subtitle-only hits: 641**
- any hits: **905 / 1019** (89%)

Almost every path contains `s` then `a` (`Users`, `Documents`, `Downloads`, …). Fuzzy still walks all 4 strings on all 1020 items, then sorts 905 scores to take 24.

Cost model from this catalog:

- ~13.6 µs/item for `Fuzzy.bestScore` (4 allocated lowercased `Array`s per text).
- At **1,020 items: 18 ms** (measured) vs **8 ms budget**.
- At **20k items (budget N): ~18 × (20000/1020) ≈ 350 ms** (linear, no prefilter). **~44× over budget.**
- Title-only at current N is 5.5 ms — under budget **only** at ~1k, and only if path scoring is dropped.

Frame budget 16.7 ms. Search alone is one frame; first `"s"` was 61 ms.

## Ranked issues (top 5)

### 1. Full-catalog fuzzy on the main thread every keystroke — **18–25 ms at N=1020** (P0)

**Evidence:** `SearchEngine.search("sa")` avg 18.2 ms (min 18.1, max 18.5). `OverlayState.refresh("sa")` 18.3 ms, of which search is 18.2 ms. Empty query 0.14 ms (different path). Misses still cost 14 ms because there is no reject index.

**Budget miss:** 8 ms @ 20k. Actual 18 ms @ 1k.

**Why:** `Fuzzy.score` lowercases and copies both strings to `Array<Character>` per call; `bestScore` does that ×4 texts; no first-character skip; `Ranker.grouped` sorts all hits.

**Fix:**

- Precompute unique lowercased search fields on `Item` at index time (`title`, filename, optional last path component — **not** the full path).
- Dedup `keywords` against `title`.
- Cheap reject: query first char must appear in the haystack (bitmask / `Set<UInt32>` / `String.contains` on pre-lowercased title) before subsequence scoring.
- Cap scoring: score title first; only score path if title missed **and** query length ≥ 3.
- Move `SearchEngine.search` off the main actor (or at least don’t block `queryChanged`); debounce 8–16 ms.
- Keep a prefix of the last result set for the next character when the query only grew.

**Verify:** `search("sa")` avg < 2 ms at N≈1k, < 8 ms at N=20k synthetic files. HUD typing at 60 fps.

### 2. Path subtitle + duplicate keywords inflate hits 3.4× — **641 junk matches for "sa"** (P0)

**Evidence:** 264 title hits vs 905 any-hits. Title-only fuzzy 5.5 ms vs 13.7 ms `bestScore`. Scoring title+keywords (still includes duplicate name, no path) 13.4 ms / 264 hits.

**Fix:** Stop putting the full relative path in `searchTexts`. Use filename + extension only; keep path for display. Unique the text list. This is also a ranking bug (short queries match every file).

**Verify:** `"sa"` hits drop from ~900 to ~260 on this catalog; Safari still ranks above random files.

### 3. `Catalog.refreshAll` waits on the file scan before publishing apps; persist on main — **18 ms warm / ~100 ms cold, design-violating** (P1)

**Evidence:**

```111:125:Sources/FlickCore/Catalog/Catalog.swift
    private func refreshAll() {
        io.async { [weak self] in
            ...
            let apps = AppSource.scan()
            let files = FileSource.scan()
            ...
            DispatchQueue.main.async {
                self.snapshot.apps = apps
                self.snapshot.files = files
                ...
                self.persist()
                self.onUpdate?()
            }
        }
    }
```

Sequential apps-then-files: 18.4 ms warm, ~107 ms first process (Bundle I/O). `onUpdate` is **never wired** (known), so the HUD does not pick up the live index. Design: “UI is usable with apps + commands immediately”; “No full rescan unless the watcher dies.”

`refreshFiles()` also full-scans on every FSEvent debounce (0.4 s) and `persist()`s **prettyPrinted + sortedKeys** JSON (3.6 ms) on the main queue.

**Fix:**

- Publish apps (and cache) first; files in a second `onUpdate`.
- Wire `catalog.onUpdate` to `OverlayState.refresh()` only if the HUD is visible, or swap `snapshot` and re-search the current query.
- `persist()` on the catalog IO queue, compact JSON (drop `prettyPrinted` / `sortedKeys` on the hot path).
- Watcher: apply add/remove/rename to the in-memory array; full scan only on start or stream failure.

**Verify:** After delete of `catalog-cache.json`, HUD empty-query / `"safari"` shows apps before Documents scan finishes. `saveCatalogCache` not on main (Time Profiler / `os_signpost`).

### 4. Uncached `NSWorkspace.icon(forFile:)` in SwiftUI `ResultRow.body` — **0.5–1.4 ms per app icon cold** (P1)

**Evidence:** 75 app icons 39–106 ms cold, 9.4 ms warm. Design: “Icons resolved lazily and cached in memory.” `ResultRow.icon` calls `NSWorkspace.shared.icon(forFile:)` every body eval. `groups` is `@Published` so every keystroke rebuilds rows. `OverlayView.onAppear` calls `refresh()` **again** after `OverlayController.show()` already did.

NSHostingView blank-list issue is separate (correctness), but icon I/O on the main thread is real jank on first paint / first query.

**Fix:** `NSCache<NSString, NSImage>` keyed by path; load lazily once per path; do not touch `icon(forFile:)` in `body` without a cache hit. Prefetch the 24 visible rows. Drop duplicate `onAppear { state.refresh() }` or the one in `show()`.

**Verify:** Second keystroke icon time ≈ 0; first HUD 24-row paint < 3 ms of icon work. Instruments: no `iconForFile` on every `body`.

### 5. FSEvents `FileEvents` on whole Desktop/Documents/Downloads — **46,926 skipped files still wake the watcher** (P1)

**Evidence:** `FileWatcher` uses `kFSEventStreamCreateFlagFileEvents`, latency 0.4 s, then `onChanged` → **full** `FileSource.scan()` + main-thread persist. Idle sample is 0% CPU (no event storm during the 2s). An `npm install` in Downloads would emit tens of thousands of file events, coalesce to a rescan every 0.4 s (17 ms scan + 3.6 ms JSON) for the duration of the write.

Idle clipboard timer (0.45 s, `changeCount` only) did **not** appear in the 2s `sample`; **not** a top CPU issue at rest (0.0% CPU, 22 MB footprint during sample).

**Fix:** Drop `FileEvents` (directory-level events). Ignore paths whose any component is in `FileFilter.skippedDirectories` or hidden. Debounce 1–2 s. Incremental catalog update.

**Verify:** `touch` a file in `~/Downloads/Chat Interface Creation/node_modules` does **not** call `FileSource.scan`. `touch ~/Downloads/foo.txt` adds one item without a 930-file walk.

## Other findings (not top 5)

- **`refreshRunning()` + `loadUsage()` every keystroke:** 0.02 + 0.07 ms now. Wrong place, cheap at U=5. Cache usage in memory; refresh running apps on HUD show only.
- **`AppSource.scan` cold 85–91 ms:** `Bundle(url:)` plus a `localizedName` helper that opens the bundle **again** and ignores `NSWorkspace`. Warm 1.6 ms. Cache names; single Info.plist read.
- **Calculator/URL/path queries still scan the catalog** (13.9 ms for `"12*8"`).
- **`Ranker.emptyQueryItems`:** `apps.first(where:)` × usage keys, O(U×N). Fine at U=5; use a dictionary at 20k.
- **Clipboard 0.45 s poll:** idle 0% CPU. Keep; optional `NSPasteboard.didChange` if it exists later. Not worth optimizing now.
- **App scan is non-recursive:** 75 apps matches cache. `/Applications/Utilities` etc. are not indexed (feature, not CPU).
- **Launch sample:** 3.8% CPU @ 3s while `refreshAll` ran; then 0.0%. RSS settled 47 MB.

## Recommended fix order (implementer)

1. Unique, pre-lowercased search fields; **do not fuzzy the full path**. Target `"sa"` < 6 ms at current N.
2. First-char / contains reject + title-first scoring. Target `"sa"` < 2 ms at current N, < 8 ms at 20k.
3. Split `refreshAll`: publish apps immediately; wire `onUpdate`; persist off main.
4. Icon `NSCache`; remove double `refresh` on show.
5. Watcher: directory events, skip `node_modules`, incremental updates (matches design.md line 87).
6. Debounce query; in-memory usage; `refreshRunning` on show only.

## How to verify

```bash
cd /Users/abhijitsr/flick/.agent-loops/perf-bench
swift run -c release PerfBench
```

Pass bar vs `docs/design.md`:

| Event | Budget | This machine now |
| --- | --- | --- |
| Keystroke → ranked rows | < 8 ms @ ≤ 20k | **18 ms @ 1.0k** (fail) |
| Cached cold start interactive | < 300 ms | cache decode 3.2 ms + empty search 0.14 ms (pass if HUD used the cache) |
| First-run apps usable immediately | yes | **fail** (`refreshAll` waits on files; `onUpdate` unwired) |
| Watcher incremental | no full rescan | **fail** (full `FileSource.scan` on every debounce) |
| Idle CPU | low | **0.0%** after launch (pass) |

End-to-end HUD: Instruments Time Profiler, type `safari` at ~10 cps. Signpost `SearchEngine.search` and `ResultRow.icon`. `sample $(pgrep -n Flick) 3` during an `npm install` in Downloads.

Synthetic 20k: generate 20k files under a temp root, point `FileSource.scan(roots:)` at it, time `SearchEngine.search`.

## Blockers / not measured

- No Instruments GUI trace of NSHostingView layout/redraw (estimated via icon + search times only). The known blank-list SwiftUI bug is **correctness**, not explained by the 18 ms search (search **does** return 24 groups).
- Did not drive the live HUD from this eval (no keystroke-to-pixel). Search numbers are in-process `CFAbsoluteTimeGetCurrent()` in a release binary linking FlickCore.
- First `"s"` 61 ms seen once (cold caches); later runs 19 ms. Treat 19 ms as steady-state, 61 ms as first-query worst.
- code-review-graph index for this repo was empty; read sources directly.
- Did not kill the `dist/Flick.app` instance started for `sample` (pid was 53456, idle 0% CPU).
