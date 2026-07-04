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
                set: { newValue in
                    // macOS's MenuBarExtraController writes this binding back on
                    // every scene update; an unconditional set retriggers the
                    // update and spins the main thread forever (observed hang).
                    guard newValue != store.settings.showInMenuBar else { return }
                    store.settings.showInMenuBar = newValue
                    store.saveSettings()
                }
            )
        ) {
            MenuBarView()
                .environment(store)
        }
        .menuBarExtraStyle(.menu)
    }
}
