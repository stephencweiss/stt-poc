import Foundation

public struct WordErrorScore: Codable, Sendable, Equatable {
    public let referenceWords: Int
    public let substitutions: Int
    public let insertions: Int
    public let deletions: Int

    public var edits: Int { substitutions + insertions + deletions }
    public var wordErrorRate: Double? {
        referenceWords == 0 ? nil : Double(edits) / Double(referenceWords)
    }

    public static func tokens(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    public static func compare(reference: String, hypothesis: String) -> Self {
        let expected = tokens(reference)
        let observed = tokens(hypothesis)
        var row = (0...observed.count).map {
            Self(referenceWords: expected.count, substitutions: 0, insertions: $0, deletions: 0)
        }
        for (index, word) in expected.enumerated() {
            var next = [
                Self(
                    referenceWords: expected.count, substitutions: 0, insertions: 0,
                    deletions: index + 1)
            ]
            for (column, candidate) in observed.enumerated() {
                if word == candidate {
                    next.append(row[column])
                } else {
                    let replace = row[column].adding(substitution: 1)
                    let insert = next[column].adding(insertion: 1)
                    let delete = row[column + 1].adding(deletion: 1)
                    next.append(
                        [replace, insert, delete].min(by: { $0.edits < $1.edits }) ?? replace)
                }
            }
            row = next
        }
        return row.last ?? Self(referenceWords: 0, substitutions: 0, insertions: 0, deletions: 0)
    }

    private func adding(substitution: Int = 0, insertion: Int = 0, deletion: Int = 0) -> Self {
        Self(
            referenceWords: referenceWords, substitutions: substitutions + substitution,
            insertions: insertions + insertion, deletions: deletions + deletion)
    }
}

public struct FactScore: Codable, Sendable {
    public let id: String
    public let matched: Bool
    public let unexpectedPhrases: [String]
}

public struct ExpectedFact: Codable, Sendable {
    public let id: String
    public let acceptedPhrases: [String]
    public let forbiddenPhrases: [String]

    public init(id: String, acceptedPhrases: [String], forbiddenPhrases: [String] = []) {
        self.id = id
        self.acceptedPhrases = acceptedPhrases
        self.forbiddenPhrases = forbiddenPhrases
    }

    public func evaluate(_ text: String) -> FactScore {
        let padded = " " + WordErrorScore.tokens(text).joined(separator: " ") + " "
        func contains(_ phrase: String) -> Bool {
            let tokens = WordErrorScore.tokens(phrase)
            return !tokens.isEmpty && padded.contains(" " + tokens.joined(separator: " ") + " ")
        }
        return FactScore(
            id: id, matched: acceptedPhrases.contains(where: contains),
            unexpectedPhrases: forbiddenPhrases.filter(contains))
    }
}
