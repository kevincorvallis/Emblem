import Foundation

/// Marker class for bundle lookup (EmblemCore carries the blank template resource).
public final class SVGSymbolTemplateMarker {}

/// Parsing, validation, and import of SF Symbol template SVGs.
public struct SVGSymbolTemplate {
    public struct ValidationResult {
        public let isValid: Bool
        public let errors: [ValidationError]
        public let warnings: [String]
    }

    public enum ValidationError: LocalizedError, Equatable {
        case fileNotReadable
        case missingSymbolsLayer
        case missingRegularVariant
        case missingSymbolName
        case invalidSymbolName(String)

        public var errorDescription: String? {
            switch self {
            case .fileNotReadable:
                return "Could not read the SVG file"
            case .missingSymbolsLayer:
                return "Missing 'Symbols' layer (id=\"Symbols\")"
            case .missingRegularVariant:
                return "Missing Regular-S weight variant (id=\"Regular-S\")"
            case .missingSymbolName:
                return "Missing symbol name (id=\"descriptive-name\" text element)"
            case .invalidSymbolName(let name):
                return "Invalid symbol name '\(name)' — use dot-separated lowercase tokens, no spaces"
            }
        }
    }

    /// URL of the bundled blank template users start from.
    public static var blankTemplateURL: URL? {
        Bundle(for: SVGSymbolTemplateMarker.self)
            .url(forResource: "custom-icon-template", withExtension: "svg")
    }

    // MARK: - Symbol name extraction

    /// Reads the symbol name from the SVG's descriptive-name element.
    /// Accepts both the SF Symbols app export form (`<text id="descriptive-name">
    /// ...<tspan>name</tspan></text>`) and the direct-text form used by blank
    /// templates (`<text id="descriptive-name" ...>name</text>`). Upstream only
    /// handled the tspan form, which broke re-importing its own template (bug #6).
    public static func extractSymbolName(from content: String) throws -> String {
        let patterns = [
            #"id="descriptive-name"[^>]*>.*?<tspan[^>]*>([^<]+)</tspan>"#,
            #"id="descriptive-name"[^>]*>([^<]+)<"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content) {
                let name = String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    return name
                }
            }
        }
        throw ValidationError.missingSymbolName
    }

    /// A usable CFBundleSymbolName: dot-separated tokens, no whitespace.
    static func isValidSymbolName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return name.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    // MARK: - Validation

    public static func validate(at url: URL) -> ValidationResult {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return ValidationResult(isValid: false, errors: [.fileNotReadable], warnings: [])
        }
        return validate(content: content)
    }

    public static func validate(content: String) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [String] = []

        if !content.contains("id=\"Symbols\"") {
            errors.append(.missingSymbolsLayer)
        }
        if !content.contains("id=\"Regular-S\"") {
            errors.append(.missingRegularVariant)
        }

        switch try? extractSymbolName(from: content) {
        case .none:
            errors.append(.missingSymbolName)
        case .some(let name) where !isValidSymbolName(name):
            errors.append(.invalidSymbolName(name))
        case .some:
            break
        }

        // Informational only — a missing template-version must not block import
        // (the strict upstream check is what broke round-tripping).
        if !content.contains("id=\"template-version\"") {
            warnings.append("No template-version marker; assuming a compatible template")
        }
        for variant in ["Ultralight-S", "Black-S"] where !content.contains("id=\"\(variant)\"") {
            warnings.append("Missing \(variant) variant (optional but recommended)")
        }

        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }

    // MARK: - Import

    /// Validates and copies an SVG into the icons directory. Returns the relative path.
    public static func importSymbol(from sourceURL: URL, named name: String, into iconsDirectory: URL) throws -> String {
        let result = validate(at: sourceURL)
        guard result.isValid else {
            throw ImportError.validationFailed(result.errors)
        }

        let relativePath = "\(name).svg"
        let destinationURL = iconsDirectory.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return relativePath
    }

    public enum ImportError: LocalizedError {
        case validationFailed([ValidationError])

        public var errorDescription: String? {
            switch self {
            case .validationFailed(let errors):
                return "SVG validation failed: "
                    + errors.compactMap(\.errorDescription).joined(separator: "; ")
            }
        }
    }
}
