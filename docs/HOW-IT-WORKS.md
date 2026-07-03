# How Emblem Works

## The mechanism

Finder Sync extensions (`com.apple.FinderSync`) may monitor folders, and macOS
uses the *containing app's* icon for a monitored folder shown in the sidebar
Favorites. An app's icon can be an SF Symbol via `CFBundleIcons →
CFBundlePrimaryIcon → CFBundleSymbolName` in its Info.plist.

So: one tiny background app per favorite, each embedding a Finder Sync
extension that monitors that folder, each with the desired symbol name in its
plist. That's the entire trick.

## The generation pipeline (EmblemCore/IconAppEngine)

1. Copy the bundled `IconAppTemplate.app` (stub `LSBackgroundOnly` app +
   `IconAppSync.appex`) into `~/Library/Application Support/Emblem/Apps/`.
2. **Custom SVGs only:** compile the SF Symbol template to `Assets.car` with
   `xcrun actool`. The symbolset name must equal the SVG's `descriptive-name`,
   which must equal `CFBundleSymbolName`. System SF Symbols skip this — the
   name alone works.
3. Rewrite the main app plist (bundle ID `page.klee.emblem.icon.<uuid>`, name,
   symbol name, `CFBundleVersion` derived from the favorite's `updatedAt` to
   bust Finder's icon cache) and the extension plist (bundle ID `….sync`,
   watched folder path), plus `FolderPath.txt` the extension reads at runtime.
4. Sign the **extension first** with sandbox entitlements, then the main app
   (`codesign --force`). Order matters: re-signing the app before the
   extension breaks pluginkit registration.
5. Register with `lsregister -f -R -trusted`.

Removal reverses it: `pluginkit -e ignore -i <ext-id>` → `lsregister -u` →
delete the bundle.

## Signing

Generated apps are signed with the identity from Settings: Automatic prefers
an "Apple Development" certificate, then "Developer ID Application", then
ad-hoc (`-`). Ad-hoc works, but on some machines ad-hoc-signed extensions
don't appear in System Settings.

## Why the manual steps exist

- **Enable the extension:** extensions activate only via user consent in
  System Settings (General → Login Items & Extensions → Finder). Emblem
  deep-links there and polls `pluginkit -m -i <id>` until the toggle flips.
- **Drag the folder to the sidebar:** there is no supported API for adding
  sidebar Favorites; the user drags the folder in once.
- **Restart Finder:** Finder caches sidebar icons; `killall Finder` refreshes.

## Known macOS ceilings

- `~/Library/CloudStorage` paths are FileProvider mounts; FinderSync can't
  badge them. A symlink outside CloudStorage pointing in works because the
  symlink is a normal filesystem object.
- Desktop/Documents/Downloads are TCC-protected; the extension may need Full
  Disk Access to observe them.
