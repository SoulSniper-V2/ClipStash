import Foundation

/// Categorizes clipboard content by type for display and filtering.
enum ContentType: String, Codable, CaseIterable {
    case text
    case url
    case code
    case email
    case color   // hex color codes
    case other

    /// SF Symbol name for this content type.
    var iconName: String {
        switch self {
        case .text:  return "doc.text"
        case .url:   return "link"
        case .code:  return "chevron.left.forwardslash.chevron.right"
        case .email: return "envelope"
        case .color: return "paintpalette"
        case .other: return "doc"
        }
    }

    /// Human-readable label.
    var label: String {
        switch self {
        case .text:  return "Text"
        case .url:   return "URL"
        case .code:  return "Code"
        case .email: return "Email"
        case .color: return "Color"
        case .other: return "Other"
        }
    }

    /// Accent color for the type badge (as hex string).
    var accentHex: String {
        switch self {
        case .text:  return "#8B949E"
        case .url:   return "#58A6FF"
        case .code:  return "#F0883E"
        case .email: return "#A371F7"
        case .color: return "#3FB950"
        case .other: return "#8B949E"
        }
    }

    // MARK: - Detection

    /// Detect content type from a raw string.
    static func detect(from content: String) -> ContentType {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // URL detection
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https", "ftp", "ssh"].contains(scheme) {
            return .url
        }

        // Email detection
        let emailPattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        if trimmed.range(of: emailPattern, options: .regularExpression) != nil {
            return .email
        }

        // Hex color detection
        let colorPattern = #"^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"#
        if trimmed.range(of: colorPattern, options: .regularExpression) != nil {
            return .color
        }

        // Code detection heuristics
        if looksLikeCode(trimmed) {
            return .code
        }

        return .text
    }

    /// Heuristic: does the string look like a code snippet?
    private static func looksLikeCode(_ text: String) -> Bool {
        let codeIndicators: [String] = [
            "func ", "class ", "struct ", "enum ", "import ",
            "def ", "return ", "const ", "let ", "var ",
            "if (", "for (", "while (", "switch ",
            "SELECT ", "INSERT ", "UPDATE ", "DELETE ",
            "function ", "=>", "->", "console.log",
            "print(", "println(", "System.out",
        ]

        let indicatorCount = codeIndicators.filter { text.contains($0) }.count

        // Check for structural code patterns
        let hasBraces = text.contains("{") && text.contains("}")
        let hasSemicolons = text.filter({ $0 == ";" }).count >= 2
        let hasMultipleLines = text.components(separatedBy: .newlines).count > 2

        if indicatorCount >= 2 { return true }
        if indicatorCount >= 1 && (hasBraces || hasSemicolons) { return true }
        if hasBraces && hasMultipleLines && hasSemicolons { return true }

        return false
    }
}
