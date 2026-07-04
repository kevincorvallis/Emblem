# Emblem

Custom icons for your Finder sidebar folders.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

macOS shows every sidebar Favorite with the same generic folder icon. Emblem lets you pick any SF Symbol (or import your own) for each folder — so `~/Projects` gets a hammer, `~/Music` gets a waveform, and your sidebar finally tells folders apart at a glance.

## How it works

macOS has no supported API for sidebar folder icons. Emblem uses the same proven trick as [SidebarFavorites](https://github.com/ivg-design/SidebarFavorites): it generates one tiny background app per favorite, each embedding a Finder Sync extension whose `CFBundleSymbolName` supplies the icon. Emblem generates, signs, and registers these apps for you, and walks you through the two manual steps macOS requires (enabling the extension, dragging the folder in). See [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md) for details.

The generated apps are self-sufficient — Emblem doesn't need to stay running.

## Install

### Build from source

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
git clone https://github.com/kevincorvallis/Emblem.git && cd Emblem
brew install xcodegen
xcodegen generate
xcodebuild -scheme Emblem -configuration Release build
# Product: DerivedData .../Release/Emblem.app — copy to /Applications
```

### DMG / Homebrew

Tagged releases build a DMG via GitHub Actions (ad-hoc signed: right-click → Open on first launch). A Homebrew cask definition lives in `packaging/emblem.rb`.

## Usage

1. **Add a favorite** — click `+` or drag a folder from Finder onto the window.
2. **Pick an icon** — search the full SF Symbols catalog, or import an SF Symbol template SVG.
3. **Follow the setup steps** — Emblem generates and signs the icon app, deep-links you to System Settings to enable the extension (and auto-detects when you do), shows you exactly what to drag where, and restarts Finder.

### Custom SVG icons

Export a blank SF Symbol template from the add sheet, draw your glyph inside the Regular-S guides in a single color, set a symbol name in the `descriptive-name` field, and import it back.

## Limitations (macOS, not Emblem)

- **Cloud folders** (iCloud Drive, Google Drive, Dropbox — anything under `~/Library/CloudStorage`) can't get FinderSync sidebar icons. Emblem detects these and can create a symlink workaround.
- **Desktop / Documents / Downloads** are TCC-protected; icons may not appear unless the icon app has Full Disk Access.
- **Finder caches icons** aggressively — the setup flow's "Restart Finder" step handles this.
- Each icon needs its own generated app; they live in `~/Library/Application Support/Emblem/Apps/`. Settings → Maintenance → "Uninstall All" removes every trace.

## Credits

- Engine approach from [ivg-design/SidebarFavorites](https://github.com/ivg-design/SidebarFavorites) (MIT), refined and rewritten
- Original technique discovered by [rknightuk/custom-finder-sidebar-icons](https://github.com/rknightuk/custom-finder-sidebar-icons)

## License

MIT — see [LICENSE](LICENSE). SF Symbols is a trademark of Apple Inc.; this project is not affiliated with Apple.
