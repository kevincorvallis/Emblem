import SwiftUI
import EmblemCore

struct FavoriteRow: View {
    @Environment(FavoriteStore.self) private var store

    let favorite: Favorite
    let status: FavoriteStatus
    let onEdit: () -> Void
    let onSetup: () -> Void

    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: 12) {
            iconPreview
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(favorite.name)
                    .font(.headline)
                Text(favorite.folderPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            statusBadge

            Menu {
                Button("Edit…", action: onEdit)
                Button("Setup Steps…", action: onSetup)
                Button("Regenerate Icon App") {
                    Task { await store.regenerate(favorite) }
                }
                Button("Reveal in Finder") {
                    SystemActions.revealInFinder(favorite.folderPath)
                }
                Divider()
                Button("Delete", role: .destructive) {
                    confirmingDelete = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            "Remove “\(favorite.name)”?",
            isPresented: $confirmingDelete
        ) {
            Button("Remove Favorite", role: .destructive) {
                Task { await store.delete(favorite) }
            }
        } message: {
            Text("The icon app is deleted and its extension unregistered. The folder itself is not touched.")
        }
    }

    @ViewBuilder
    private var iconPreview: some View {
        if favorite.iconType == .custom, let svgPath = favorite.customSVGPath {
            SVGThumbnailView(url: store.customIconURL(relativePath: svgPath), size: 24)
                .foregroundStyle(Color.accentColor)
        } else {
            Image(systemName: favorite.iconValue)
                .font(.system(size: 18))
                .foregroundStyle(Color.accentColor)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            switch status {
            case .generating:
                ProgressView().controlSize(.small)
                Text("Generating…")
            case .active:
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("Active")
            case .awaitingSetup:
                Circle().fill(.orange).frame(width: 8, height: 8)
                Button("Finish Setup", action: onSetup)
                    .buttonStyle(.link)
            case .folderMissing:
                Circle().fill(.red).frame(width: 8, height: 8)
                Text("Folder Missing")
            case .error(let message):
                Circle().fill(.red).frame(width: 8, height: 8)
                Text("Error").help(message)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
