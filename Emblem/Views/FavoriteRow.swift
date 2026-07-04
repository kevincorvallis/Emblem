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
            iconWell

            VStack(alignment: .leading, spacing: 3) {
                Text(favorite.name)
                    .font(.body.weight(.semibold))
                Text(favorite.folderPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 16)

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
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .help("Actions for \(favorite.name)")
        }
        .padding(.vertical, 8)
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

    private var iconWell: some View {
        Group {
            if favorite.iconType == .custom, let svgPath = favorite.customSVGPath {
                SVGThumbnailView(url: store.customIconURL(relativePath: svgPath), size: 20)
            } else {
                Image(systemName: favorite.iconValue)
                    .font(.system(size: 17, weight: .medium))
            }
        }
        .foregroundStyle(Color.accentColor)
        .frame(width: 36, height: 36)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .generating:
            capsule(color: .secondary) {
                ProgressView().controlSize(.mini)
                Text("Generating…")
            }
        case .active:
            capsule(color: .green) {
                Image(systemName: "checkmark.circle.fill")
                Text("Active")
            }
        case .awaitingSetup:
            Button(action: onSetup) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Finish Setup")
                }
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15), in: Capsule())
                .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .help("Complete the remaining setup steps")
        case .folderMissing:
            capsule(color: .red) {
                Image(systemName: "questionmark.folder.fill")
                Text("Folder Missing")
            }
        case .error(let message):
            capsule(color: .red) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Error")
            }
            .help(message)
        }
    }

    private func capsule(color: Color, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 4, content: content)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}
