import SwiftUI
import UniformTypeIdentifiers
import EmblemCore

/// Minimal wrapper so the blank SVG template can be saved via fileExporter.
struct SVGFileDocument: FileDocument {
    static let readableContentTypes: [UTType] = [UTType(filenameExtension: "svg") ?? .xml]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

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
    @State private var showingFolderPicker = false
    @State private var exportingTemplate = false
    @State private var templateDocument: SVGFileDocument?
    @State private var symlinkNotice: String?
    @State private var svgErrors: [String] = []
    @State private var showingSVGError = false
    @State private var showingTemplateSaved = false
    @State private var saving = false
    @State private var saveError: String?

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
        var isDir: ObjCBool = false
        let expanded = (folderPath as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir),
              isDir.boolValue else { return false }
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
                        Button("Browse…") { showingFolderPicker = true }
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
                    .disabled(saving)
                Spacer()
                if saving {
                    ProgressView().controlSize(.small)
                        .padding(.trailing, 8)
                }
                Button(isEditing ? "Save" : "Add") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || saving)
            }
            .controlSize(.large)
            .padding()
        }
        .frame(width: 520, height: 700)
        .interactiveDismissDisabled(saving)
        .onAppear(perform: populate)
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            if case .success(let url) = result {
                folderPath = abbreviate(url.path)
                if name.isEmpty {
                    name = url.lastPathComponent
                }
            }
        }
        .fileImporter(
            isPresented: $showingSVGImporter,
            allowedContentTypes: [UTType(filenameExtension: "svg") ?? .xml]
        ) { result in
            if case .success(let url) = result {
                importSVG(from: url)
            }
        }
        .fileExporter(
            isPresented: $exportingTemplate,
            document: templateDocument,
            contentType: UTType(filenameExtension: "svg") ?? .xml,
            defaultFilename: "my-symbol.svg"
        ) { result in
            if case .success = result {
                showingTemplateSaved = true
            }
        }
        .alert(
            "Couldn't Save Favorite",
            isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
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
                if let symlinkNotice {
                    Text(symlinkNotice)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Button("Advanced: Create Symlink", action: createSymlink)
                            .controlSize(.small)
                        Text("Creates a link in your home folder; the link lives in the sidebar instead. It can break if the cloud provider re-mounts.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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

    /// Creates `~/<folder name>` pointing at the cloud folder; the symlink is
    /// what the user drags to the sidebar.
    private func createSymlink() {
        let target = (folderPath as NSString).expandingTildeInPath
        let home = FileManager.default.homeDirectoryForCurrentUser
        let baseName = URL(fileURLWithPath: target).lastPathComponent

        var linkURL = home.appendingPathComponent(baseName)
        var counter = 2
        while FileManager.default.fileExists(atPath: linkURL.path) {
            linkURL = home.appendingPathComponent("\(baseName)-\(counter)")
            counter += 1
        }

        do {
            try FileManager.default.createSymbolicLink(
                at: linkURL, withDestinationURL: URL(fileURLWithPath: target))
            folderPath = abbreviate(linkURL.path)
            symlinkNotice = "Created \(abbreviate(linkURL.path)) → the cloud folder. This link is your sidebar favorite now."
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
        templateDocument = SVGFileDocument(data: data)
        exportingTemplate = true
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
            if let saved {
                dismiss()
                onSaved(saved)
            } else {
                if case .error(let message) = store.statuses[favorite.id] {
                    saveError = message
                } else {
                    saveError = "Something went wrong while generating the icon app."
                }
            }
        }
    }
}
