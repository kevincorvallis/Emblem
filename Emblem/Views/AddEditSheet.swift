import SwiftUI
import UniformTypeIdentifiers
import EmblemCore

struct AddEditSheet: View {
    @Environment(FavoriteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let existingFavorite: Favorite?
    let prefillPath: String?
    /// Called with the saved favorite so the caller can present setup steps.
    let onSaved: (Favorite) -> Void

    @State private var name = ""
    @State private var folderPath = ""
    @State private var iconType: Favorite.IconType = .sfSymbol
    @State private var iconValue = "folder.fill"
    @State private var customSVGPath: String?

    @State private var showingSVGImporter = false
    @State private var svgErrors: [String] = []
    @State private var showingSVGError = false
    @State private var showingTemplateSaved = false
    @State private var saving = false

    init(favorite: Favorite?, prefillPath: String?, onSaved: @escaping (Favorite) -> Void) {
        self.existingFavorite = favorite
        self.prefillPath = prefillPath
        self.onSaved = onSaved
    }

    private var isEditing: Bool { existingFavorite != nil }

    private var classification: PathClassification {
        folderPath.isEmpty ? .normal : PathClassifier.classify(folderPath)
    }

    private var isValid: Bool {
        guard !name.isEmpty, !folderPath.isEmpty else { return false }
        switch iconType {
        case .sfSymbol: return SymbolCatalog.isValid(iconValue)
        case .custom: return customSVGPath != nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Edit Favorite" : "Add Favorite")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            Form {
                Section {
                    TextField("Name", text: $name)
                    HStack {
                        TextField("Folder", text: $folderPath)
                        Button("Browse…", action: pickFolder)
                    }
                    pathBanner
                }

                Section("Icon") {
                    Picker("Type", selection: $iconType) {
                        Text("SF Symbol").tag(Favorite.IconType.sfSymbol)
                        Text("Custom SVG").tag(Favorite.IconType.custom)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if iconType == .sfSymbol {
                        SymbolBrowser(selection: $iconValue)
                    } else {
                        customSVGSection
                    }
                }

                Section("Preview") {
                    sidebarPreview
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || saving)
            }
            .padding()
        }
        .frame(width: 520, height: 640)
        .onAppear(perform: populate)
        .fileImporter(
            isPresented: $showingSVGImporter,
            allowedContentTypes: [UTType(filenameExtension: "svg") ?? .xml]
        ) { result in
            if case .success(let url) = result {
                importSVG(from: url)
            }
        }
        .alert("Invalid SVG Template", isPresented: $showingSVGError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(svgErrors.joined(separator: "\n"))
        }
        .alert("Template Saved", isPresented: $showingTemplateSaved) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("""
            Open the template in a vector editor (Figma, Illustrator, …), draw \
            your icon inside the Regular-S guides in a single color, set a symbol \
            name in the descriptive-name field, then import it here.
            """)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var pathBanner: some View {
        switch classification {
        case .normal:
            EmptyView()
        case .cloudStorage:
            VStack(alignment: .leading, spacing: 6) {
                Label(
                    "Cloud folders (iCloud, Drive, Dropbox…) can't show custom sidebar icons — a macOS limitation.",
                    systemImage: "exclamationmark.icloud")
                .font(.caption)
                .foregroundStyle(.orange)
                HStack {
                    Button("Advanced: Create Symlink…", action: createSymlink)
                        .controlSize(.small)
                    Text("The symlink lives in the sidebar instead; it can break if the cloud provider re-mounts.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        case .tccProtected:
            Label(
                "Desktop, Documents and Downloads are privacy-protected; the icon may not appear unless the icon app gets Full Disk Access.",
                systemImage: "lock.shield")
            .font(.caption)
            .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var customSVGSection: some View {
        if let path = customSVGPath {
            HStack {
                SVGThumbnailView(url: store.customIconURL(relativePath: path), size: 20)
                Text(path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Change…") { showingSVGImporter = true }
            }
        } else {
            HStack(spacing: 12) {
                Button {
                    showingSVGImporter = true
                } label: {
                    Label("Import SVG…", systemImage: "square.and.arrow.down")
                }
                Button {
                    saveBlankTemplate()
                } label: {
                    Label("Save Blank Template…", systemImage: "doc.badge.plus")
                }
            }
            Text("Import an SF Symbol template SVG, or start from a blank template.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sidebarPreview: some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                Group {
                    if iconType == .custom, let path = customSVGPath {
                        SVGThumbnailView(url: store.customIconURL(relativePath: path), size: 16)
                    } else {
                        Image(systemName: SymbolCatalog.isValid(iconValue) ? iconValue : "questionmark.square.dashed")
                    }
                }
                .font(.system(size: 15))
                .foregroundStyle(Color.accentColor)
                Text(name.isEmpty ? "Folder Name" : name)
                    .foregroundStyle(name.isEmpty ? .secondary : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func populate() {
        if let favorite = existingFavorite {
            name = favorite.name
            folderPath = favorite.folderPath
            iconType = favorite.iconType
            iconValue = favorite.iconValue
            customSVGPath = favorite.customSVGPath
        } else if let prefillPath {
            folderPath = abbreviate(prefillPath)
            name = URL(fileURLWithPath: prefillPath).lastPathComponent
        }
    }

    private func abbreviate(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = false  // preserve symlink paths
        panel.message = "Select a folder to add to the Finder sidebar"
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            folderPath = abbreviate(url.path)
            if name.isEmpty {
                name = url.lastPathComponent
            }
        }
    }

    private func createSymlink() {
        let target = (folderPath as NSString).expandingTildeInPath
        let panel = NSSavePanel()
        panel.title = "Choose Symlink Location"
        panel.nameFieldStringValue = URL(fileURLWithPath: target).lastPathComponent
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.message = "The symlink is what you'll drag to the sidebar. It opens the cloud folder when clicked."
        panel.prompt = "Create Symlink"
        guard panel.runModal() == .OK, let linkURL = panel.url else { return }
        do {
            try FileManager.default.createSymbolicLink(
                at: linkURL, withDestinationURL: URL(fileURLWithPath: target))
            folderPath = abbreviate(linkURL.path)
        } catch {
            svgErrors = [error.localizedDescription]
            showingSVGError = true
        }
    }

    private func importSVG(from url: URL) {
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }

        let result = SVGSymbolTemplate.validate(at: url)
        guard result.isValid,
              let content = try? String(contentsOf: url, encoding: .utf8),
              let symbolName = try? SVGSymbolTemplate.extractSymbolName(from: content) else {
            svgErrors = result.errors.compactMap(\.errorDescription)
            if svgErrors.isEmpty { svgErrors = ["Could not read the SVG file."] }
            showingSVGError = true
            return
        }

        do {
            let relative = try SVGSymbolTemplate.importSymbol(
                from: url, named: symbolName, into: store.iconsDirectoryURL)
            Task { await SVGThumbnailCache.shared.invalidate(for: store.customIconURL(relativePath: relative)) }
            customSVGPath = relative
            iconValue = symbolName
        } catch {
            svgErrors = [error.localizedDescription]
            showingSVGError = true
        }
    }

    private func saveBlankTemplate() {
        guard let templateURL = SVGSymbolTemplate.blankTemplateURL,
              let data = try? Data(contentsOf: templateURL) else {
            svgErrors = ["Bundled template missing."]
            showingSVGError = true
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "svg") ?? .xml]
        panel.nameFieldStringValue = "my-symbol.svg"
        panel.message = "Choose where to save the blank SF Symbol template"
        panel.prompt = "Save Template"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                showingTemplateSaved = true
            } catch {
                svgErrors = [error.localizedDescription]
                showingSVGError = true
            }
        }
    }

    private func save() {
        var favorite: Favorite
        if let existing = existingFavorite {
            favorite = existing
            favorite.name = name
            favorite.folderPath = folderPath
            favorite.iconType = iconType
            favorite.iconValue = iconValue
            favorite.customSVGPath = iconType == .custom ? customSVGPath : nil
        } else {
            favorite = Favorite(
                name: name,
                folderPath: folderPath,
                iconType: iconType,
                iconValue: iconValue,
                customSVGPath: iconType == .custom ? customSVGPath : nil)
        }

        saving = true
        Task {
            let saved = await store.addOrUpdate(favorite)
            saving = false
            dismiss()
            if let saved {
                onSaved(saved)
            }
        }
    }
}
