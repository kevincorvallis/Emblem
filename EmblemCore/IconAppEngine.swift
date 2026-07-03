import Foundation
import AppKit
import os

/// Generates, signs, and registers icon apps — the ported SidebarFavorites engine.
///
/// The sequence in `generate(for:)` is a behavior contract (see spec §2). Signing
/// order matters: the extension is signed first with sandbox entitlements, then
/// the main app; wrong order breaks pluginkit registration.
public actor IconAppEngine {
    private let store: ConfigStore
    private let templateURL: URL?
    private var cachedIdentities: [String]?
    private let fileManager = FileManager.default
    private let log = Logger(subsystem: "page.klee.emblem", category: "engine")

    private static let lsregisterPath =
        "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    public init(store: ConfigStore, templateURL: URL?) {
        self.store = store
        self.templateURL = templateURL
    }

    // MARK: - Generate

    public func generate(for favorite: Favorite) async throws {
        guard let templateURL, fileManager.fileExists(atPath: templateURL.path) else {
            throw EngineError.templateNotFound
        }

        let destinationURL = store.iconAppURL(for: favorite)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: templateURL, to: destinationURL)

        // System SF Symbols need no compilation — CFBundleSymbolName alone works.
        // Custom SVGs compile to Assets.car, named by their descriptive-name field.
        var symbolName = favorite.iconValue
        if favorite.iconType == .custom, let svgPath = favorite.customSVGPath {
            symbolName = try await compileCustomSymbol(svgPath: svgPath, appURL: destinationURL)
        }

        try updateMainInfoPlist(at: destinationURL, for: favorite, symbolName: symbolName)
        try updateExtensionInfoPlist(at: destinationURL, for: favorite)
        try updateFolderPathFile(at: destinationURL, for: favorite)
        try await signAppBundle(at: destinationURL)
        try await registerWithLaunchServices(at: destinationURL)

        // copyItem preserves the template's old mtime, which would make
        // isCurrent(for:) false forever and force a regeneration (and Finder icon
        // flicker) on every check — the likely root cause of upstream issue #4.
        try? fileManager.setAttributes(
            [.modificationDate: Date()], ofItemAtPath: destinationURL.path)

        log.info("Generated icon app for \(favorite.name, privacy: .public)")
    }

    // MARK: - Plist mutation

    private func updateMainInfoPlist(at appURL: URL, for favorite: Favorite, symbolName: String) throws {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard var plist = NSDictionary(contentsOf: plistURL) as? [String: Any] else {
            throw EngineError.plistReadFailed
        }

        plist["CFBundleIdentifier"] = favorite.bundleIdentifier
        plist["CFBundleName"] = favorite.name

        var icons = plist["CFBundleIcons"] as? [String: Any] ?? [:]
        var primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any] ?? [:]
        primaryIcon["CFBundleSymbolName"] = symbolName
        icons["CFBundlePrimaryIcon"] = primaryIcon
        plist["CFBundleIcons"] = icons
        plist.removeValue(forKey: "CFBundleIconFile")

        // Derived from updatedAt (monotonic per favorite) so every regeneration
        // gets a fresh version to bust Finder's icon cache — upstream's
        // increment-on-read could repeat values.
        plist["CFBundleVersion"] = String(Int(favorite.updatedAt.timeIntervalSince1970))

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL)
    }

    private func updateExtensionInfoPlist(at appURL: URL, for favorite: Favorite) throws {
        let plistURL = appURL.appendingPathComponent("Contents/PlugIns/IconAppSync.appex/Contents/Info.plist")
        guard var plist = NSDictionary(contentsOf: plistURL) as? [String: Any] else {
            throw EngineError.plistReadFailed
        }

        plist["CFBundleIdentifier"] = favorite.extensionBundleIdentifier
        plist["CFBundleName"] = "\(favorite.name) Sync"
        // FinderSync needs the full path; tilde forms don't resolve there.
        plist["SidebarFolderPaths"] = [favorite.expandedFolderPath]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL)
    }

    private func updateFolderPathFile(at appURL: URL, for favorite: Favorite) throws {
        let resourcesDir = appURL.appendingPathComponent("Contents/PlugIns/IconAppSync.appex/Contents/Resources")
        if !fileManager.fileExists(atPath: resourcesDir.path) {
            try fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
        }
        try favorite.expandedFolderPath.write(
            to: resourcesDir.appendingPathComponent("FolderPath.txt"),
            atomically: true, encoding: .utf8)
    }

    // MARK: - Custom symbol compilation

    private func compileCustomSymbol(svgPath: String, appURL: URL) async throws -> String {
        let svgURL = store.customIconURL(relativePath: svgPath)
        guard fileManager.fileExists(atPath: svgURL.path) else {
            throw EngineError.customIconNotFound
        }

        let content = try String(contentsOf: svgURL, encoding: .utf8)
        let symbolName = try SVGSymbolTemplate.extractSymbolName(from: content)

        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let xcassetsURL = tempDir.appendingPathComponent("Symbols.xcassets")
        let symbolsetURL = xcassetsURL.appendingPathComponent("\(symbolName).symbolset")
        try fileManager.createDirectory(at: symbolsetURL, withIntermediateDirectories: true)

        try #"{"info": {"version": 1, "author": "xcode"}}"#
            .write(to: xcassetsURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
        try fileManager.copyItem(at: svgURL, to: symbolsetURL.appendingPathComponent("\(symbolName).svg"))
        try """
        {
          "info": {"version": 1, "author": "xcode"},
          "symbols": [{"filename": "\(symbolName).svg", "idiom": "universal"}]
        }
        """.write(to: symbolsetURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

        let outputDir = tempDir.appendingPathComponent("output")
        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

        do {
            try await Subprocess.run("/usr/bin/xcrun", [
                "actool", xcassetsURL.path,
                "--compile", outputDir.path,
                "--platform", "macosx",
                "--minimum-deployment-target", "14.0",
                "--output-format", "human-readable-text",
            ])
        } catch let SubprocessError.nonZeroExit(_, output) {
            throw EngineError.actoolFailed(output)
        }

        let assetsCarSource = outputDir.appendingPathComponent("Assets.car")
        guard fileManager.fileExists(atPath: assetsCarSource.path) else {
            throw EngineError.actoolFailed("Assets.car not produced")
        }

        let resourcesDir = appURL.appendingPathComponent("Contents/Resources")
        try fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
        let assetsCarDest = resourcesDir.appendingPathComponent("Assets.car")
        if fileManager.fileExists(atPath: assetsCarDest.path) {
            try fileManager.removeItem(at: assetsCarDest)
        }
        try fileManager.copyItem(at: assetsCarSource, to: assetsCarDest)

        return symbolName
    }

    // MARK: - Signing

    public func availableSigningIdentities() async -> [String] {
        if let cached = cachedIdentities {
            return cached
        }
        guard let output = try? await Subprocess.run(
            "/usr/bin/security", ["find-identity", "-v", "-p", "codesigning"]) else {
            cachedIdentities = []
            return []
        }

        var identities: [String] = []
        for line in output.components(separatedBy: "\n") {
            if line.contains("Apple Development") {
                identities.append("Apple Development")
            } else if line.contains("Developer ID Application") {
                identities.append("Developer ID Application")
            }
        }
        var seen = Set<String>()
        let unique = identities.filter { seen.insert($0).inserted }
        cachedIdentities = unique
        return unique
    }

    public func resolveSigningIdentity(_ preference: SigningIdentity) async -> String {
        let available = await availableSigningIdentities()
        switch preference {
        case .automatic:
            if available.contains("Apple Development") { return "Apple Development" }
            if available.contains("Developer ID Application") { return "Developer ID Application" }
            return "-"
        case .adHoc:
            return "-"
        case .appleDevelopment, .developerID:
            return available.contains(preference.rawValue) ? preference.rawValue : "-"
        }
    }

    private func signAppBundle(at appURL: URL) async throws {
        let extensionURL = appURL.appendingPathComponent("Contents/PlugIns/IconAppSync.appex")
        let identity = await resolveSigningIdentity(store.config.settings.signingIdentity)

        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        // Matches what Xcode uses for Finder Sync extensions.
        let entitlementsURL = tempDir.appendingPathComponent("extension.entitlements")
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>com.apple.security.app-sandbox</key>
            <true/>
            <key>com.apple.security.files.user-selected.read-only</key>
            <true/>
        </dict>
        </plist>
        """.write(to: entitlementsURL, atomically: true, encoding: .utf8)

        do {
            try await Subprocess.run("/usr/bin/codesign", [
                "--force", "--sign", identity,
                "--entitlements", entitlementsURL.path,
                extensionURL.path,
            ])
        } catch let SubprocessError.nonZeroExit(_, output) {
            throw EngineError.codesignFailed("Extension: \(output)")
        }

        do {
            try await Subprocess.run("/usr/bin/codesign", [
                "--force", "--sign", identity, appURL.path,
            ])
        } catch let SubprocessError.nonZeroExit(_, output) {
            throw EngineError.codesignFailed("Main app: \(output)")
        }

        log.info("Signed with identity \(identity, privacy: .public)")
    }

    // MARK: - Launch Services / removal

    private func registerWithLaunchServices(at appURL: URL) async throws {
        // Full flags like Xcode: -f -R -trusted
        try await Subprocess.run(Self.lsregisterPath, ["-f", "-R", "-trusted", appURL.path])
    }

    public func remove(for favorite: Favorite) async throws {
        // Best-effort disable; the extension may never have been registered.
        try? await Subprocess.run("/usr/bin/pluginkit", ["-e", "ignore", "-i", favorite.extensionBundleIdentifier])

        let appURL = store.iconAppURL(for: favorite)
        if fileManager.fileExists(atPath: appURL.path) {
            try? await Subprocess.run(Self.lsregisterPath, ["-u", appURL.path])
            try fileManager.removeItem(at: appURL)
        }
    }

    /// Remove a bundle not tracked by any favorite (housekeeping).
    public func removeOrphan(at appURL: URL) async throws {
        try? await Subprocess.run(Self.lsregisterPath, ["-u", appURL.path])
        try fileManager.removeItem(at: appURL)
    }

    public func isCurrent(for favorite: Favorite) -> Bool {
        let appURL = store.iconAppURL(for: favorite)
        guard fileManager.fileExists(atPath: appURL.path),
              let attrs = try? fileManager.attributesOfItem(atPath: appURL.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return false
        }
        return modDate >= favorite.updatedAt
    }

    public func restartFinder() async {
        try? await Subprocess.run("/usr/bin/killall", ["Finder"])
    }

    /// True if the favorite's FinderSync extension is enabled in System Settings.
    public func isExtensionEnabled(for favorite: Favorite) async -> Bool {
        guard let output = try? await Subprocess.run(
            "/usr/bin/pluginkit", ["-m", "-i", favorite.extensionBundleIdentifier]) else {
            return false
        }
        // "+" prefix means enabled, "-" disabled, "?" unregistered-but-known.
        return output.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+")
    }

    public enum EngineError: LocalizedError {
        case templateNotFound
        case plistReadFailed
        case customIconNotFound
        case actoolFailed(String)
        case codesignFailed(String)

        public var errorDescription: String? {
            switch self {
            case .templateNotFound:
                return "IconAppTemplate.app not found in app resources"
            case .plistReadFailed:
                return "Failed to read Info.plist in the generated app"
            case .customIconNotFound:
                return "Custom icon SVG file not found"
            case .actoolFailed(let output):
                return "Failed to compile the custom symbol: \(output.prefix(300))"
            case .codesignFailed(let output):
                return "Failed to sign the icon app: \(output.prefix(300))"
            }
        }
    }
}
