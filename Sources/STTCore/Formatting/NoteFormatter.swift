import Foundation

/// Applies fixed display rules without changing the source transcript or using a model.
public enum NoteFormatter {
    public static func format(_ text: String) -> String {
        normalizeWhitespace(
            formatSpelling(NumericUnitFormatter.format(formatHeadings(normalizeWhitespace(text)))))
    }

    private static func formatSpelling(_ text: String) -> String {
        var output = text
        for match in text.matches(of: #/\b[\p{L}\p{N}_]+\b/#).reversed() {
            if let spelling = FormattingVocabulary.spelling[String(match.output).lowercased()] {
                output.replaceSubrange(match.range, with: spelling)
            }
        }
        return output
    }

    private static func formatHeadings(_ text: String) -> String {
        var output = text
        var replacements: [(Range<String.Index>, String)] = []
        var previousHeadingEnd: String.Index?
        let pattern = #/(?im)(?:(?:heading) )?(?<label>[a-z]+)(?:[.:]|(?=\n|$))[ \t]*/#
        for match in text.matches(of: pattern) {
            guard let title = FormattingVocabulary.headings[String(match.output.label).lowercased()]
            else { continue }
            let prefix = text[..<match.range.lowerBound]
            let marker = String(text[match.range]).lowercased()
            let explicitLineLabel =
                prefix.last == "\n"
                && (marker.hasPrefix("heading ") || marker.contains(":"))
            let followsHeading =
                previousHeadingEnd.map {
                    text[$0..<match.range.lowerBound].allSatisfy(\.isWhitespace)
                } ?? false
            guard explicitLineLabel || followsHeading || isSectionBoundary(prefix) else { continue }
            let suffix = text[match.range.upperBound...]
            let separator = suffix.isEmpty || suffix.first == "\n" ? "" : "\n"
            replacements.append((match.range, title + ":" + separator))
            previousHeadingEnd = match.range.upperBound
        }
        for (range, replacement) in replacements.reversed() {
            output.replaceSubrange(range, with: replacement)
        }
        return output
    }

    private static func isSectionBoundary(_ prefix: Substring) -> Bool {
        if prefix.isEmpty || prefix.hasSuffix("\n\n") { return true }
        if prefix.last == "\n" {
            // A wrapped sentence is not a section boundary, especially after negation.
            let previous = String(prefix).trimmingCharacters(in: .whitespacesAndNewlines)
            return previous.last.map { ".!?:".contains($0) } ?? true
        }
        return prefix.count >= 2 && [". ", "! ", "? "].contains(String(prefix.suffix(2)))
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        var result: [String] = []
        for line in lines {
            let normalized = line.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            if !normalized.isEmpty || result.last.map({ !$0.isEmpty }) == true {
                result.append(normalized)
            }
        }
        if result.last == "" { result.removeLast() }
        return result.joined(separator: "\n")
    }
}
