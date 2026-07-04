import SwiftUI
import EmblemCore

/// The 4-step guided setup shown after a favorite is saved. Polls pluginkit
/// only while visible and only until the extension flips on.
struct SetupChecklistView: View {
    @Environment(FavoriteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let favorite: Favorite

    @State private var draggedConfirmed = false
    @State private var finderRestarted = false

    private var status: FavoriteStatus {
        store.statuses[favorite.id] ?? .awaitingSetup
    }

    private var generated: Bool {
        switch status {
        case .generating: return false
        case .error: return false
        default: return true
        }
    }

    private var extensionEnabled: Bool {
        status == .active
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Set Up “\(favorite.name)”")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                step(
                    number: 1,
                    done: generated,
                    active: !generated,
                    title: "Icon app generated"
                ) {
                    switch status {
                    case .generating:
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Generating and signing…")
                        }
                    case .error(let message):
                        VStack(alignment: .leading, spacing: 6) {
                            Text(message).foregroundStyle(.red)
                            Button("Try Again") {
                                Task { await store.regenerate(favorite) }
                            }
                        }
                    default:
                        Text("Signed and registered with macOS.")
                    }
                }

                step(
                    number: 2,
                    done: extensionEnabled,
                    active: generated && !extensionEnabled,
                    title: "Enable the Finder extension"
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("System Settings → General → Login Items & Extensions → Finder — turn on “\(favorite.name) Sync”.")
                        HStack(spacing: 8) {
                            Button("Open System Settings") {
                                SystemActions.openExtensionsSettings()
                            }
                            if !extensionEnabled {
                                HStack(spacing: 5) {
                                    ProgressView().controlSize(.mini)
                                    Text("Watching for the toggle…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                step(
                    number: 3,
                    done: draggedConfirmed,
                    active: extensionEnabled && !draggedConfirmed,
                    title: "Drag the folder into the sidebar"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("In Finder, drag “\(favorite.name)” into the Favorites section of the sidebar.")
                        sidebarIllustration
                        HStack {
                            Button("Reveal in Finder") {
                                SystemActions.revealInFinder(favorite.folderPath)
                            }
                            Button("It's in my sidebar") {
                                draggedConfirmed = true
                            }
                        }
                    }
                }

                step(
                    number: 4,
                    done: finderRestarted,
                    active: draggedConfirmed && !finderRestarted,
                    title: "Restart Finder"
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Finder caches sidebar icons; restarting makes the new icon appear.")
                        Button("Restart Finder") {
                            Task {
                                await store.restartFinder()
                                finderRestarted = true
                            }
                        }
                    }
                }
            }
            .padding()

            Divider()

            HStack {
                Spacer()
                Button(finderRestarted ? "Done" : "Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 480)
        .frame(minHeight: 420)  // steps expand/collapse; anchor so the sheet doesn't snap
        .animation(.default, value: extensionEnabled)
        .animation(.default, value: draggedConfirmed)
        .animation(.default, value: finderRestarted)
        .task {
            // Poll only while this sheet is up and the extension is still off.
            while !Task.isCancelled && !extensionEnabled {
                await store.refreshStatus(for: favorite)
                if extensionEnabled { break }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private var sidebarIllustration: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Favorites")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Label("Applications", systemImage: "square.grid.3x3")
                Label("Desktop", systemImage: "menubar.dock.rectangle")
                Label(favorite.name, systemImage: favorite.iconType == .sfSymbol ? favorite.iconValue : "star.square")
                    .foregroundStyle(Color.accentColor)
                    .bold()
            }
            .font(.caption)
            .padding(10)
            .frame(width: 160, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Image(systemName: "arrow.left")
                .padding(.horizontal, 8)
                .foregroundStyle(.secondary)
            Label(favorite.name, systemImage: "folder.fill")
                .font(.caption)
                .padding(6)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    @ViewBuilder
    private func step<Content: View>(
        number: Int,
        done: Bool,
        active: Bool,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(number).circle")
                .font(.title3)
                .foregroundStyle(done ? .green : (active ? Color.accentColor : Color.secondary))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(active || done ? .semibold : .regular))
                    .foregroundStyle(done || active ? .primary : .secondary)
                if active || (done && number == 1) {
                    content()
                        .font(.callout)
                }
            }
        }
    }
}
