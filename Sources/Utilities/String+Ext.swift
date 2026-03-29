import Foundation

extension String {
    /// Truncate to a max number of characters with ellipsis.
    func truncated(to maxLength: Int = 200) -> String {
        if count <= maxLength { return self }
        return String(prefix(maxLength)) + "…"
    }

    /// Truncate to a max number of lines.
    func truncatedLines(_ maxLines: Int = 2) -> String {
        let lines = components(separatedBy: .newlines)
        if lines.count <= maxLines {
            return self.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let truncated = lines.prefix(maxLines).joined(separator: "\n")
        return truncated.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    /// Check if this string looks like a URL.
    var isURL: Bool {
        guard let url = URL(string: self.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased() else {
            return false
        }
        return ["http", "https", "ftp", "ssh"].contains(scheme)
    }

    /// Heuristic check for code-like content.
    var isCodeSnippet: Bool {
        let indicators = ["func ", "class ", "struct ", "def ", "return ",
                          "const ", "import ", "var ", "let ", "if (",
                          "for (", "=>", "->", "print(", "console.log"]
        let matches = indicators.filter { contains($0) }.count
        let hasBraces = contains("{") && contains("}")
        return matches >= 2 || (matches >= 1 && hasBraces)
    }

    /// Extract the domain from a URL string.
    var urlDomain: String? {
        guard let url = URL(string: self.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host else {
            return nil
        }
        // Remove www. prefix
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
