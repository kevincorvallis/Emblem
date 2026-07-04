import SwiftUI
import EmblemCore

@main
struct EmblemApp: App {
    @State private var store = FavoriteStore()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(store)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Favorite…") {
                    store.addSheetRequested = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(store)
        }

        MenuBarExtra(
            "Emblem",
            systemImage: "sidebar.left",
            isInserted: Binding(
                get: { store.settings.showInMenuBar },
                set: { store.settings.showInMenuBar = $0; store.saveSettings() }
            )
        ) {
            MenuBarView()
                .environment(store)
        }
        .menuBarExtraStyle(.menu)
    }
}
