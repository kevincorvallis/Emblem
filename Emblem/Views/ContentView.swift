import SwiftUI
import EmblemCore

struct ContentView: View {
    @Environment(FavoriteStore.self) private var store

    @State private var editingFavorite: Favorite?
    @State private var showingAddSheet = false
    @State private var addPrefillPath: String?
    @State private var setupFavorite: Favorite?
    /// Set by the add/edit sheet's save; promoted to setupFavorite in onDismiss
    /// so the two sheet presentations never race.
    @State private var pendingSetup: Favorite?
    @State private var orphans: [URL] = []
    @State private var showingOrphanPrompt = false

    var body: some View {
        Group {
            if store.favorites.isEmpty {
                emptyState
            } else {
                favoritesList
            }
        }
        .frame(minWidth: 560, minHeight: 380)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addPrefillPath = nil
                    showingAddSheet = true
                } label: {
                    Label("Add Favorite", systemImage: "plus")
                }
                .help("Add a folder to the Finder sidebar with a custom icon")
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            var isDir: ObjCBool = false
            guard let url = urls.first(where: {
                FileManager.default.fileExists(atPath: $0.path, isDirectory: &isDir) && isDir.boolValue
            }) else { return false }
            addPrefillPath = url.path
            showingAddSheet = true
            return true
        }
        .sheet(isPresented: $showingAddSheet, onDismiss: promotePendingSetup) {
            AddEditSheet(favorite: nil, prefillPath: addPrefillPath) { saved in
                pendingSetup = saved
            }
        }
        .sheet(item: $editingFavorite, onDismiss: promotePendingSetup) { favorite in
            AddEditSheet(favorite: favorite, prefillPath: nil) { saved in
                pendingSetup = saved
            }
        }
        .sheet(item: $setupFavorite) { favorite in
            SetupChecklistView(favorite: favorite)
        }
        .task {
            await store.refreshStatuses()
            orphans = store.orphanedApps()
            showingOrphanPrompt = !orphans.isEmpty
        }
        .onChange(of: store.addSheetRequested) { _, requested in
            if requested {
                store.addSheetRequested = false
                addPrefillPath = nil
                showingAddSheet = true
            }
        }
        .alert("Leftover Icon Apps Found", isPresented: $showingOrphanPrompt) {
            Button("Clean Up") {
                Task { await store.cleanOrphans() }
            }
            Button("Ignore", role: .cancel) {}
        } message: {
            Text("\(orphans.count) generated icon app(s) on disk don't belong to any current favorite. Remove them?")
        }
    }

    private func promotePendingSetup() {
        if let pending = pendingSetup {
            pendingSetup = nil
            setupFavorite = pending
        }
    }

    private var favoritesList: some View {
        List {
            Section {
                ForEach(store.favorites) { favorite in
                    FavoriteRow(
                        favorite: favorite,
                        status: store.statuses[favorite.id] ?? .awaitingSetup,
                        onEdit: { editingFavorite = favorite },
                        onSetup: { setupFavorite = favorite }
                    )
                }
            } header: {
                Text(store.favorites.count == 1
                     ? "1 favorite"
                     : "\(store.favorites.count) favorites")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .listStyle(.inset)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Favorites Yet", systemImage: "sidebar.left")
        } description: {
            Text("Give your Finder sidebar folders custom icons.\nAdd a folder, or drag one here from Finder.")
        } actions: {
            Button("Add Favorite") {
                addPrefillPath = nil
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
