# Emblem — Design Spec

**Date:** 2026-07-03
**Status:** Approved pending user review
**Repo:** `kevinlee/Emblem` (fresh history, not a GitHub fork)
**Derived from:** [ivg-design/SidebarFavorites](https://github.com/ivg-design/SidebarFavorites) (MIT)

## 1. Overview

Emblem is a macOS 14+ app that gives Finder sidebar Favorites custom SF Symbol icons. macOS has no supported way to set a custom icon on a sidebar folder; the workaround (proven by upstream SidebarFavorites) is to generate one tiny app bundle per favorite, each embedding a Finder Sync extension whose `CFBundleSymbolName` supplies the icon. Emblem is a ground-up rebrand and refinement of that idea using the **hybrid approach**: port the proven generation engine nearly verbatim, rewrite the UI, models, and app shell fresh.

**Goals** (all four confirmed in scope):

1. **UX polish** — searchable SF Symbol browser, drag-and-drop, guided setup, live status
2. **Fix upstream bugs** — template round-trip (#6), cloud folders (#8), TCC folders (#12), drag-and-drop request (#7); mitigate icon flicker (#4)
3. **Code quality + tests** — dead code removed, modern Swift, unit + integration tests
4. **Distribution + CI** — GitHub Actions CI and release pipeline, DMG artifact, Homebrew cask

**Identity:**

- App name: **Emblem** ("custom icons for your Finder sidebar folders")
- Bundle ID: `page.klee.emblem`; generated icon apps: `page.klee.emblem.icon.<uuid>`
- Local path: `~/code/personal/emblem`
- Minimum macOS: 14 (Sonoma) — required for `@Observable`; upstream targeted 13

## 2. Background: how the trick works (ported behavior contract)

The engine must preserve this sequence exactly — it encodes hard-won platform knowledge from upstream:

1. Copy `IconAppTemplate.app` (containing a `FinderSync.appex`) to `~/Library/Application Support/Emblem/Apps/<name>.app`
2. For custom SVG icons: compile the SF Symbol template SVG to `Assets.car` via `xcrun actool` (symbolset named after the SVG's `descriptive-name` field, which must match `CFBundleSymbolName` exactly). System SF Symbols need **no** compilation — `CFBundleSymbolName` alone suffices.
3. Mutate the main app `Info.plist` (bundle ID, name, `CFBundleIcons.CFBundlePrimaryIcon.CFBundleSymbolName`, incremented `CFBundleVersion` to bust Finder's icon cache) and the extension `Info.plist` (bundle ID, name, tilde-expanded folder path), plus a `FolderPath.txt` resource the extension reads at runtime.
4. Sign the **extension first** with sandbox entitlements, **then** the main app (`codesign --force`). Signing order matters; wrong order breaks pluginkit registration.
5. Register with `lsregister -f -R -trusted`.
6. Removal: `pluginkit -e ignore -i <ext-id>` → `lsregister -u` → delete bundle.

Signing identity resolution (ported): Automatic (Apple Development → Developer ID → ad-hoc) / explicit choices, detected via `security find-identity -v -p codesigning`.

Known platform limits (documented in-app, not fixable):

- FileProvider mounts (`~/Library/CloudStorage/…`) can't get FinderSync icons; symlinks work.
- Finder caches sidebar icons aggressively; a Finder restart is needed after icon changes.

## 3. Product & UX

### Main window

- List of favorites: live icon preview, name, folder path, and a **status badge** per favorite:
  - ✅ Active (extension enabled per `pluginkit -m -p com.apple.FinderSync`)
  - ⚠️ Awaiting setup (generated but extension not enabled)
  - ❌ Folder missing (path no longer exists)
- Toolbar: add (`+`), and per-row edit/regenerate/delete.
- **Drag-and-drop**: dropping a folder from Finder onto the window (or the menu bar icon) opens the Add sheet pre-filled with that path (upstream issue #7).

### Add/Edit sheet

- Name + folder path (Browse via `NSOpenPanel`, `resolvesAliases = false` to preserve symlinks; `~` abbreviation preserved for display).
- **SF Symbol browser**: scrollable grid of all system symbols with live search and category filter, sourced from `SymbolCatalog` (see §4). Click to select; selected symbol previewed in a mock sidebar row.
- **Custom SVG**: import an SF Symbol template SVG or export a blank template. The exported template must re-import cleanly (fixes upstream #6): export and validation use the same schema, and validation errors state exactly which field failed.
- Live preview renders the icon in a fake sidebar row (as upstream) for both symbol types.

### Smart path handling (on folder selection, before save)

Classify the chosen path:

- **Cloud storage** (path under `~/Library/CloudStorage/` or resolving into it): explain the FileProvider limitation and offer **"Create symlink workaround"** — Emblem creates `~/<name>` (user-adjustable location) pointing at the cloud folder and uses the symlink as the favorite (upstream #8).
- **TCC-protected** (Desktop, Documents, Downloads): warn upfront that FinderSync may not fire without Full Disk Access for the icon app, link to the relevant System Settings pane, and let the user proceed knowingly (upstream #12, upstream PR #11's guidance built into the product).
- **Normal**: proceed silently.

### Guided setup checklist (after save)

A three-step checklist replaces upstream's README-driven setup:

1. **Icon app generated** — done automatically, shows spinner during generation (generation is async; never blocks UI).
2. **Enable the extension** — button deep-links to System Settings' Extensions pane (`x-apple.systempreferences:com.apple.ExtensionsPreferences`). Emblem polls `pluginkit` every ~2s while this step is pending and ticks it automatically when the toggle flips.
3. **Restart Finder** — one-click `killall Finder`, with a note that the folder must be dragged into the sidebar Favorites if it isn't there yet.

### Menu bar (`MenuBarExtra`)

- Aggregate status (all active / N need setup), per-favorite quick status, Quick Add, Restart Finder, Open Emblem, Quit.

### Settings

- Signing identity picker (Automatic / Ad-hoc / Apple Development / Developer ID) with live detection of available identities.
- Launch at login (`SMAppService`).
- Check for updates (GitHub Releases API; see §7).

### First-launch import

If `~/Library/Application Support/SidebarFavorites/config.json` exists, offer to import those favorites (map fields, copy custom SVGs, regenerate icon apps under Emblem's IDs). Decline = never ask again.

## 4. Architecture

```
Emblem/
├── project.yml                  # XcodeGen project definition
├── Emblem/                      # Manager app target (rewritten shell)
│   ├── App/                     # @main EmblemApp, MenuBarExtra, main window scene
│   ├── Models/                  # Favorite, Config, PathClassification
│   ├── Views/                   # FavoriteList, AddEditSheet, SymbolBrowser,
│   │                            #   SetupChecklist, SettingsView, MenuBarView
│   └── Services/                # FavoriteStore (@Observable), ExtensionStatusMonitor
├── EmblemCore/                  # Framework target: the ported engine
│   ├── IconAppEngine.swift      # from upstream IconAppGenerator (see §5)
│   ├── SymbolCatalog.swift      # runtime SF Symbol enumeration + validation
│   ├── SVGSymbolTemplate.swift  # parse/generate/validate SF Symbol template SVGs
│   ├── ConfigStore.swift        # Codable persistence + SidebarFavorites import
│   └── PathClassifier.swift     # normal / cloudStorage / tccProtected
├── IconAppTemplate/             # Ported as-is: IconApp main.swift + FinderSync appex
├── Tests/
│   ├── EmblemCoreTests/         # unit tests
│   └── IntegrationTests/        # full generation pipeline test
├── scripts/                     # build-release.sh (DMG)
├── packaging/emblem.rb          # Homebrew cask definition (for kevinlee/homebrew-tap)
└── .github/workflows/           # ci.yml, release.yml
```

**Shell conventions:** SwiftUI with `@Observable` models, structured concurrency (`async`/`await`), no Combine, no singletons in the UI layer (engine services injected). All `Process` invocations (`actool`, `codesign`, `lsregister`, `pluginkit`, `security`, `killall`) run off the main actor via a small `async` subprocess helper with captured output.

**SymbolCatalog:** enumerates system symbols at runtime from macOS's `CoreGlyphs.bundle` (`/System/Library/CoreServices/CoreGlyphs.bundle`, `symbol_order.plist` / `name_availability.plist`), with `NSImage(systemSymbolName:accessibilityDescription:)` as the per-name validity check and fallback. Categories from `symbol_categories.plist` when present. This replaces upstream's 529-line hardcoded validator list and never goes stale when macOS adds symbols. If the bundle format changes in a future macOS, the catalog degrades gracefully: search-by-name still validates via `NSImage`.

**Data storage:**

- Config: `~/Library/Application Support/Emblem/config.json` (Codable, versioned schema `{ "version": 1, "favorites": [...], "settings": {...} }`)
- Generated apps: `~/Library/Application Support/Emblem/Apps/`
- Imported custom SVGs: `~/Library/Application Support/Emblem/Icons/`

**Favorite model:** `id: UUID`, `name`, `folderPath` (tilde-abbreviated), `iconType` (.sfSymbol | .customSVG), `iconValue`, `customSVGPath?`, `createdAt`, `updatedAt`. Bundle IDs derived: `page.klee.emblem.icon.<uuid>` / `…icon.<uuid>.sync`.

## 5. IconAppEngine: what changes from upstream, what doesn't

**Unchanged (the proven core):** the entire generation sequence in §2, entitlements content, actool invocation, signing order, lsregister flags, removal sequence, signing identity resolution.

**Changed:**

- Delete dead code: `compileSFSymbolToIcns`, `compileSFSymbolToAssets`, `generateSymbolTemplateSVG`, `renderSFSymbolToPNG` (~325 lines; verified unreachable — the only call sites are within this chain itself).
- `async` API: `func generate(for favorite: Favorite) async throws`; subprocesses never block the calling thread.
- Structured errors (`EngineError`) with user-actionable messages, surfaced in the setup checklist UI.
- Icon-flicker mitigation (upstream #4): `CFBundleVersion` derives from `updatedAt` (monotonic per favorite) instead of increment-on-read, so repeated regeneration can't produce duplicate versions; regeneration always ends with an explicit "Restart Finder" step in the UI. Full fix is impossible (Finder-internal caching) — the spec commits to mitigation + documentation, not elimination.

## 6. Testing

**Unit (EmblemCoreTests, run in CI):**

- `SVGSymbolTemplate`: symbol-name extraction from `descriptive-name`; export → validate → import round-trip (regression test for upstream #6); rejection messages name the failing field.
- Plist mutation: given a template plist, assert exact resulting keys (bundle IDs, symbol name, version derivation).
- `PathClassifier`: home subfolders vs `~/Library/CloudStorage/...` vs Desktop/Documents/Downloads, including symlink-into-cloud cases.
- `ConfigStore`: encode/decode, schema version handling, SidebarFavorites config import mapping.
- `SymbolCatalog`: known-good symbol validates, garbage name rejects; catalog non-empty on the runner.

**Integration (macOS runner, run in CI):** run the real pipeline — generate an icon app for a temp folder with (a) a system symbol and (b) a fixture custom SVG; assert the bundle's plist contents, `Assets.car` presence for (b), and `codesign --verify` passes with ad-hoc identity. `pluginkit`/System Settings enablement is not CI-testable and stays manual.

## 7. CI/CD & distribution

- **`ci.yml`** — on push/PR: `xcodegen generate` → build → run unit + integration tests (macOS runner).
- **`release.yml`** — on `v*` tag: Release build, `scripts/build-release.sh` produces a DMG, GitHub Release created with the DMG attached and changelog notes. Ad-hoc signing (README documents the right-click-Open first-run dance, as upstream). The workflow is structured so a Developer ID signing + notarization step can be slotted in later without restructuring.
- **Updates:** Settings has "Check for Updates" — compares the running version against the latest GitHub Release via the public API and links to the download. No Sparkle (out of scope; awkward without notarization).
- **Homebrew:** `packaging/emblem.rb` cask ready for a `kevinlee/homebrew-tap` repo (`brew install --cask kevinlee/tap/emblem`). Creating the tap repo is a post-release follow-up.

## 8. Branding & licensing

- New app icon (emblem/shield motif, SF-symbol-derived) rendered to `AppIcon.appiconset`.
- README written for Emblem: what/why, install (DMG, brew, source), usage with screenshots, troubleshooting (Finder cache, TCC, cloud folders), **Credits**: ivg-design/SidebarFavorites (engine approach) and rknightuk/custom-finder-sidebar-icons (original discovery).
- `LICENSE`: MIT with both copyright lines — original `ivg-design` notice retained, Kevin Lee added.
- Not ported: Nix flake/packaging, the standalone prototype app + `setup_prototype.sh`, upstream docs (`PROTOTYPE_SETUP.md`, `SUMMARY.md`) — replaced by a single `docs/HOW-IT-WORKS.md` explaining the icon-app mechanism.

## 9. Out of scope

- Sparkle auto-update framework, notarization, Mac App Store (sandboxing makes the whole approach impossible there)
- Programmatically adding folders to the sidebar (no supported API; user drags the folder in once)
- Fixing FinderSync limitations for FileProvider/CloudStorage paths (symlink workaround is the ceiling)
- Localization; Nix packaging

## 10. Risks

- **macOS updates** may change `CoreGlyphs.bundle` internals (catalog degrades to name-validation-only, browser hidden) or FinderSync behavior (engine risk shared with upstream).
- **Ad-hoc signing** may keep extensions from appearing in System Settings on some machines (known upstream issue #9/#2); mitigated by Automatic identity resolution preferring a real certificate when one exists, and by troubleshooting docs.
