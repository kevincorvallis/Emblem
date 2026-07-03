import SwiftUI
import ServiceManagement
import EmblemCore

struct SettingsView: View {
    @Environment(FavoriteStore.self) private var store

    @State private var identities: [String] = []
    @State private var confirmingUninstall = false

    var body: some View {
        @Bindable var store = store

        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $store.settings.launchAtLogin)
                    .onChange(of: store.settings.launchAtLogin) { _, enabled in
                        applyLaunchAtLogin(enabled)
                        store.saveSettings()
                    }
                Toggle("Show in menu bar", isOn: $store.settings.showInMenuBar)
                    .onChange(of: store.settings.showInMenuBar) { _, _ in
                        store.saveSettings()
                    }
            }

            Section {
                Picker("Signing identity", selection: $store.settings.signingIdentity) {
                    ForEach(SigningIdentity.allCases, id: \.self) { identity in
                        Text(identity.displayName).tag(identity)
                    }
                }
                .onChange(of: store.settings.signingIdentity) { _, _ in
                    store.saveSettings()
                }
                Text(identities.isEmpty
                     ? "No signing certificates found — ad-hoc signing will be used."
                     : "Available: \(identities.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Code Signing")
            } footer: {
                Text("Generated icon apps are signed with this identity. Automatic prefers a real certificate and falls back to ad-hoc.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Maintenance") {
                LabeledContent("Orphaned icon apps") {
                    Button("Clean Up") {
                        Task { await store.cleanOrphans() }
                    }
                }
                LabeledContent("All generated icon apps") {
                    Button("Uninstall All…", role: .destructive) {
                        confirmingUninstall = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .task {
            identities = await store.availableSigningIdentities()
        }
        .confirmationDialog(
            "Uninstall all icon apps?",
            isPresented: $confirmingUninstall
        ) {
            Button("Uninstall All", role: .destructive) {
                Task { await store.uninstallAll() }
            }
        } message: {
            Text("Every generated icon app is unregistered and deleted. Your favorites stay listed and can be regenerated. Do this before deleting Emblem itself.")
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Launch at login change failed: \(error)")
        }
    }
}
