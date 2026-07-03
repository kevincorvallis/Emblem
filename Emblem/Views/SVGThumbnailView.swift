import SwiftUI

/// Renders the Regular-S variant of an SF Symbol template SVG (ported from
/// upstream's native-NSImage renderer).
struct SVGThumbnailView: View {
    let url: URL
    let size: CGFloat

    @State private var image: NSImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
            } else {
                Image(systemName: "square.on.square")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .task(id: url) {
            isLoading = true
            image = await SVGThumbnailCache.shared.thumbnail(for: url, size: size)
            isLoading = false
        }
    }
}

/// Thumbnail cache; extraction crops the template to its Regular-S guide bounds.
actor SVGThumbnailCache {
    static let shared = SVGThumbnailCache()

    private var cache: [String: NSImage] = [:]

    func thumbnail(for url: URL, size: CGFloat) async -> NSImage? {
        let key = "\(url.absoluteString)_\(Int(size))"
        if let cached = cache[key] {
            return cached
        }
        guard let extracted = extractSymbolSVG(from: url),
              let image = renderSVG(extracted, size: size) else {
            return nil
        }
        cache[key] = image
        return image
    }

    func invalidate(for url: URL) {
        let prefix = url.absoluteString
        cache = cache.filter { !$0.key.hasPrefix(prefix) }
    }

    private func extractSymbolSVG(from url: URL) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        // Regular-S bounds from the template's guide lines (defaults are the
        // standard SF Symbol template coordinates).
        var baselineY: CGFloat = 696
        var caplineY: CGFloat = 625.541
        var leftMargin: CGFloat = 1394.79
        var rightMargin: CGFloat = 1504.9

        func extractNumber(fromLineWithID id: String, attribute: String) -> CGFloat? {
            guard let range = content.range(
                of: "<line[^>]*id=\"\(id)\"[^>]*>", options: .regularExpression) else {
                return nil
            }
            let line = String(content[range])
            guard let match = line.range(
                of: "\(attribute)=\"([0-9.]+)\"", options: .regularExpression) else {
                return nil
            }
            let value = line[match].dropFirst(attribute.count + 2).dropLast()
            return Double(value).map { CGFloat($0) }
        }

        baselineY = extractNumber(fromLineWithID: "Baseline-S", attribute: "y1") ?? baselineY
        caplineY = extractNumber(fromLineWithID: "Capline-S", attribute: "y1") ?? caplineY
        leftMargin = extractNumber(fromLineWithID: "left-margin-Regular-S", attribute: "x1") ?? leftMargin
        rightMargin = extractNumber(fromLineWithID: "right-margin-Regular-S", attribute: "x1") ?? rightMargin

        let padding: CGFloat = 5
        let viewBox = (
            x: leftMargin - padding,
            y: caplineY - padding,
            width: (rightMargin - leftMargin) + padding * 2,
            height: (baselineY - caplineY) + padding * 2
        )

        // Prefer the Regular-S group; fall back to the whole Symbols layer.
        let groupContent: String
        if let start = content.range(of: "<g id=\"Regular-S\">"),
           let end = content.range(of: "</g>", range: start.upperBound..<content.endIndex) {
            groupContent = String(content[start.lowerBound...end.upperBound])
        } else if let start = content.range(of: "<g id=\"Symbols\">"),
                  let end = content.range(of: "</g>", range: start.upperBound..<content.endIndex) {
            groupContent = String(content[start.upperBound..<end.lowerBound])
        } else {
            return nil
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="\(viewBox.x) \(viewBox.y) \(viewBox.width) \(viewBox.height)" width="\(viewBox.width)" height="\(viewBox.height)">
            <style>
                path, rect, circle, ellipse, polygon { fill: black; }
            </style>
            \(groupContent)
        </svg>
        """
    }

    private func renderSVG(_ svg: String, size: CGFloat) -> NSImage? {
        guard let data = svg.data(using: .utf8), let svgImage = NSImage(data: data) else {
            return nil
        }
        let scaled = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let svgSize = svgImage.size
            let scale = min(rect.width / svgSize.width, rect.height / svgSize.height)
            let drawRect = NSRect(
                x: (rect.width - svgSize.width * scale) / 2,
                y: (rect.height - svgSize.height * scale) / 2,
                width: svgSize.width * scale,
                height: svgSize.height * scale)
            svgImage.draw(in: drawRect)
            return true
        }
        scaled.isTemplate = true
        return scaled
    }
}
