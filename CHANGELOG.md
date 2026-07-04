# Changelog

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
