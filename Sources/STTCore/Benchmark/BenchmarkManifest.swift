import Foundation

public struct BenchmarkCase: Codable, Sendable {
    public let id: String
    public let audio: String
    public let reference: String
    public let audioSha256: String
    public let referenceSha256: String
    public let category: String
    public let origin: String
    public let procedure: String
    public let expectedFacts: [ExpectedFact]
}

public struct BenchmarkManifest: Codable, Sendable {
    public let version: Int
    public let cases: [BenchmarkCase]

    public func validate() throws {
        guard version == 1, !cases.isEmpty else { throw ManifestError.invalidSuite }
        guard Set(cases.map(\.id)).count == cases.count else { throw ManifestError.duplicateID }
        for entry in cases {
            try validate(entry)
        }
    }

    private func validate(_ entry: BenchmarkCase) throws {
        let required = [entry.id, entry.category, entry.origin, entry.procedure]
        guard required.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
            Set(entry.expectedFacts.map(\.id)).count == entry.expectedFacts.count
        else { throw ManifestError.invalidSuite }
        for hash in [entry.audioSha256, entry.referenceSha256] {
            guard hash.count == 64, hash.allSatisfy({ $0.isHexDigit }) else {
                throw ManifestError.invalidSuite
            }
        }
        for fact in entry.expectedFacts {
            guard !fact.id.isEmpty, !fact.acceptedPhrases.isEmpty,
                (fact.acceptedPhrases + fact.forbiddenPhrases).allSatisfy({
                    !WordErrorScore.tokens($0).isEmpty
                })
            else { throw ManifestError.invalidSuite }
        }
    }
}

public enum ManifestError: Error, Sendable {
    case invalidSuite
    case duplicateID
    case unsafePath
    case checksumMismatch(String)
    case invalidAudio(String)
    case inventoryMismatch
}
