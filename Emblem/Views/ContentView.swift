import SwiftUI
import EmblemCore

struct ContentView: View {
    @Environment(FavoriteStore.self) private var store

    @State private var editingFavorite: Favorite?
    @State private var showingAddSheet = false
    @State private var addPrefillPath: String?
    @State private var setupFavorite: Favorite?
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
            guard let url = urls.first(where: \.hasDirectoryPath) else { return false }
            addPrefillPath = url.path
            showingAddSheet = true
            return true
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEditSheet(favorite: nil, prefillPath: addPrefillPath) { saved in
                setupFavorite = saved
            }
        }
        .sheet(item: $editingFavorite) { favorite in
            AddEditSheet(favorite: favorite, prefillPath: nil) { saved in
                setupFavorite = saved
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
        .alert("Leftover Icon Apps Found", isPresented: $showingOrphanPrompt) {
            Button("Clean Up") {
                Task { await store.cleanOrphans() }
            }
            Button("Ignore", role: .cancel) {}
        } message: {
            Text("\(orphans.count) generated icon app(s) on disk don't belong to any current favorite. Remove them?")
        }
    }

    private var favoritesList: some View {
        List {
            ForEach(store.favorites) { favorite in
                FavoriteRow(
                    favorite: favorite,
                    status: store.statuses[favorite.id] ?? .awaitingSetup,
                    onEdit: { editingFavorite = favorite },
                    onSetup: { setupFavorite = favorite }
                )
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
