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
            HStack {
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
                Picker("", selection: $showAll) {
                    Text("Recommended").tag(false)
                    Text("All").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

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
                .padding(.vertical, 2)
            }
            .frame(height: 150)

            if symbols.isEmpty {
                Text("No symbols match “\(query)”")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(selection)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
