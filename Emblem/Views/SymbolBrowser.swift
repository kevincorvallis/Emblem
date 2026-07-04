import SwiftUI
import EmblemCore

/// Searchable SF Symbol picker: curated "Recommended" grid by default, full
/// system catalog behind search or the All toggle.
struct SymbolBrowser: View {
    @Binding var selection: String

    @State private var query = ""
    @State private var showAll = false

    private var symbols: [String] {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            return SymbolCatalog.search(query)
        }
        return showAll ? SymbolCatalog.allSymbols() : SymbolCatalog.curated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Search on its own row so the placeholder never wraps.
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search all symbols", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(6)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))

            HStack {
                Picker("", selection: $showAll) {
                    Text("Recommended").tag(false)
                    Text("All").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 170)

                Spacer()

                if symbols.isEmpty {
                    Text("No symbols match “\(query)”")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(selection)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 6)], spacing: 6) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button {
                            selection = symbol
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 17))
                                .frame(width: 40, height: 36)
                                .background(
                                    selection == symbol
                                        ? Color.accentColor.opacity(0.25)
                                        : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.borderless)
                        .help(symbol)
                    }
                }
                .padding(.trailing, 16)  // keep the last column clear of the scrollbar
            }
            .frame(height: 162)  // exactly 4 rows: 4×36 + 3×6
        }
    }
}
