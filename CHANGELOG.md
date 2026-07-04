# Changelog

## 0.2.5 — 2026-07-04

- Fixed: Browse… and Import SVG… dialogs not opening — two file importers on
  one view silently disabled each other; now a single routed importer

## 0.2.4 — 2026-07-04

- UI refinements per HIG: tinted icon wells, capsule status badges,
  properly sized action menus and buttons, list header, roomier rows

## 0.2.3 — 2026-07-04

- Fixed: System Settings showed generated apps by file name
  ("meetings-fed41a12") — display names are now set on the app and extension
- Fixed: ghost "IconAppTemplate" entries in Login Items & Extensions — the
  embedded template now ships as a .bundle so macOS doesn't register it

## 0.2.2 — 2026-07-04

- Fixed: Gatekeeper blocking generated icon apps ("could not verify … is free
  of malware") when Emblem itself was installed from a download — macOS
  provenance tracking quarantined generated bundles; they're now stripped
  after generation

## 0.2.1 — 2026-07-03

- Fixed: main-thread hang ("not responding") caused by a feedback loop in the
  menu-bar visibility binding — macOS writes the binding back on every scene
  update; identical writes are now no-ops

## 0.2.0 — 2026-07-03

- **Match folder icons**: favorites' folders get their symbol stamped as the
  Finder icon too (icon views, open/save dialogs, Spotlight) — reversible,
  toggle in Settings
- Developer ID signing + notarization support in the release pipeline
  (see docs/RELEASING.md); ad-hoc fallback preserved
- ⌘N adds a favorite
- Fixed: ghost file panels over the main window (native SwiftUI dialogs),
  subprocess pipe deadlock, sheet-presentation race, status flicker during
  generation, menu-bar toggle not applying, renamed favorites orphaning their
  old icon apps
- Symbol browser layout: search row no longer wraps, grid no longer clips

## 0.1.0 — 2026-07-03

Initial release. Rebranded, refined derivative of SidebarFavorites:

- Searchable SF Symbol browser (full system catalog, curated defaults)
- Drag-and-drop folders to add favorites
- Guided 4-step setup with live extension detection
- Cloud-storage and TCC path detection with explanations and symlink workaround
- Custom SF Symbol template SVG import/export (round-trip fixed)
- Orphaned icon-app cleanup and one-click uninstall-all
- Fixed perpetual regeneration (icon flicker) via generation timestamps
- Async engine — UI never blocks on codesign/actool
- Unit + integration test suite, GitHub Actions CI
