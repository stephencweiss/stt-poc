import Foundation

/// Only complete numeric-unit expressions are changed. Unsupported constructions block
/// the whole clause (sentence punctuation, semicolon, or newline; commas stay inside).
/// French requires a sheath/catheter, a size prefix, or a standalone size clause.
enum NumericUnitFormatter {
    static func format(_ text: String) -> String {
        var output = ""
        var clause = ""
        let characters = Array(text)
        for (index, character) in characters.enumerated() {
            let decimalPoint =
                character == "." && index + 1 < characters.count && characters[index + 1].isNumber
            if "\n;!?".contains(character) || (character == "." && !decimalPoint) {
                output += formatClause(clause) + String(character)
                clause = ""
            } else {
                clause.append(character)
            }
        }
        return output + formatClause(clause)
    }

    private static func formatClause(_ clause: String) -> String {
        guard !hasUnsupportedConstruction(clause) else { return clause }
        // Take all adjacent number words before checking their grammar. This prevents
        // replacing a valid suffix inside an invalid phrase such as 'one twenty six'.
        let pattern =
            #/(?i)(?<number>[+-]?\d+(?:\.\d+)?|(?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)(?:[ -](?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety))*) (?<unit>french|fr|millimeters?|mm)\b/#
        var replacements: [(Range<String.Index>, String)] = []
        for match in clause.matches(of: pattern) {
            let prefix = clause[..<match.range.lowerBound]
            guard
                prefix.last.map({ !$0.isLetter && !$0.isNumber && !"_.+-/–—".contains($0) }) ?? true
            else { return clause }
            let number = String(match.output.number)
            guard let value = normalizedNumber(number) else { return clause }
            let unit = String(match.output.unit).lowercased()
            if unit == "french" || unit == "fr" {
                let suffix = clause[match.range.upperBound...]
                guard hasFrenchContext(prefix: String(prefix), suffix: String(suffix)) else {
                    return clause
                }
            }
            replacements.append(
                (match.range, value + " " + (unit == "french" || unit == "fr" ? "Fr" : "mm")))
        }
        guard !hasUnmatchedNumber(in: clause, matchedRanges: replacements.map(\.0)) else {
            return clause
        }
        var output = clause
        for (range, replacement) in replacements.reversed() {
            output.replaceSubrange(range, with: replacement)
        }
        return output
    }

    /// A number outside a complete size expression can be part of a correction,
    /// fraction, or other unsupported grammar. Keep that whole clause unchanged.
    private static func hasUnmatchedNumber(in text: String, matchedRanges: [Range<String.Index>])
        -> Bool
    {
        for token in text.matches(of: #/[\p{L}\p{N}_]+/#) {
            let word = String(token.output).lowercased()
            let numeric =
                word.contains(where: \.isNumber) || small.contains(word) || tens[word] != nil
            if numeric
                && !matchedRanges.contains(where: {
                    $0.lowerBound <= token.range.lowerBound
                        && token.range.upperBound <= $0.upperBound
                })
            {
                return true
            }
        }
        return false
    }

    private static func hasFrenchContext(prefix: String, suffix: String) -> Bool {
        let before = prefix.trimmingCharacters(in: .whitespaces).lowercased()
        let after = suffix.trimmingCharacters(in: .whitespaces).lowercased()
        let nextWord = after.split(whereSeparator: { !$0.isLetter }).first.map(String.init)
        if nextWord == "sheath" || nextWord == "catheter" { return true }
        if after.isEmpty && (before.isEmpty || before == "size" || before.hasSuffix(" size")) {
            return true
        }
        return false
    }

    private static func hasUnsupportedConstruction(_ text: String) -> Bool {
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        let continuation: Set<String> = [
            "point", "hundred", "thousand", "million", "billion", "half", "quarter",
            "to", "through", "by", "x", "over", "or", "no", "sorry", "correction", "rather",
            "and", "minus", "plus", "negative", "positive", "dot", "decimal", "dash", "hyphen",
            "until", "times", "mean", "actually", "make", "instead", "third", "thirds", "fourth",
            "fourths", "halves", "quarters",
        ]
        if words.contains(where: continuation.contains) { return true }
        if text.contains("/") || text.contains("–") || text.contains("—") || text.contains("−")
            || text.contains("⁄")
        {
            return true
        }
        if text.contains(" - ") || text.contains(#/\d\s*[-,]\s*\d/#) { return true }
        return false
    }

    private static let small = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen",
        "nineteen",
    ]
    private static let tens = [
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70,
        "eighty": 80, "ninety": 90,
    ]

    private static func normalizedNumber(_ text: String) -> String? {
        if text.contains(where: \.isNumber) { return text }
        let parts = text.lowercased().split(whereSeparator: { $0 == " " || $0 == "-" }).map(
            String.init)
        guard let first = parts.first else { return nil }
        if parts.count == 1 {
            return small.firstIndex(of: first).map(String.init) ?? tens[first].map(String.init)
        }
        guard parts.count == 2, let ten = tens[first], let one = small.firstIndex(of: parts[1]),
            (1...9).contains(one)
        else { return nil }
        return String(ten + one)
    }
}
