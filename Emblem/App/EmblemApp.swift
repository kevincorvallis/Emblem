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
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environment(store)
        }

        MenuBarExtra(
            "Emblem",
            systemImage: "sidebar.left",
            isInserted: .constant(store.settings.showInMenuBar)
        ) {
            MenuBarView()
                .environment(store)
        }
        .menuBarExtraStyle(.menu)
    }
}
