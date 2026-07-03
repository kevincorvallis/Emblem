import SwiftUI
import EmblemCore

struct MenuBarView: View {
    @Environment(FavoriteStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    private var needsSetupCount: Int {
        store.favorites.filter { store.statuses[$0.id] != .active }.count
    }

    var body: some View {
        Group {
            if store.favorites.isEmpty {
                Text("No favorites yet")
            } else {
                Text(needsSetupCount == 0
                     ? "All \(store.favorites.count) favorites active"
                     : "\(needsSetupCount) favorite(s) need setup")
                Divider()
                ForEach(store.favorites) { favorite in
                    Label {
                        Text(favorite.name)
                    } icon: {
                        Image(systemName: store.statuses[favorite.id] == .active
                              ? "checkmark.circle.fill" : "exclamationmark.circle")
                    }
                }
            }

            Divider()

            Button("Open Emblem") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Restart Finder") {
                Task { await store.restartFinder() }
            }

            Divider()

            Button("Quit Emblem") {
                NSApp.terminate(nil)
            }
        }
        .task {
            await store.refreshStatuses()
        }
    }
}
