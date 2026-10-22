import Foundation
import STTAdapters
import STTCore

struct BenchmarkMeasurement: Codable {
    let id: String
    let procedure: String
    let category: String
    let promptEnabled: Bool
    let trial: Int
    let invocation: Int
    let audioSeconds: Double
    let transcriptionSeconds: Double
    let realTimeFactor: Double
    let score: WordErrorScore
    let wordErrorRate: Double?
    let facts: [FactScore]
    let reference: String
    let transcript: String
}

struct BenchmarkSummary: Codable {
    let promptEnabled: Bool
    let procedure: String
    let cases: Int
    let weightedWordErrorRate: Double?
    let medianSeconds: Double
    let maximumSeconds: Double
    let missingFacts: Int
    let unexpectedPhrases: Int
    let nonSpeechInsertions: Int
}

struct BenchmarkReport: Codable {
    let schemaVersion: Int
    let createdAt: String
    let sourceCommit: String
    let workingTreeDirty: Bool
    let hardware: String
    let operatingSystem: String
    let manifestSha256: String
    let modelID: String
    let modelSha256: String
    let executableSha256: String
    let decodingSettings: String
    let scoringVersion: String
    let promptVersion: String
    let prompt: String
    let timingNotes: String
    let measurements: [BenchmarkMeasurement]
    let summaries: [BenchmarkSummary]
}

struct BenchmarkRunner {
    let transcriber: any TranscriberService

    func measure(
        _ suite: LoadedBenchmarkSuite, modes: [Bool], repetitions: Int,
        progress: (_ completed: Int, _ total: Int) -> Void = { _, _ in }
    ) async throws
        -> [BenchmarkMeasurement]
    {
        try Task.checkCancellation()
        let total = suite.cases.count * modes.count * repetitions
        progress(0, total)
        var rows: [BenchmarkMeasurement] = []
        for trial in 1...repetitions {
            for entry in suite.cases {
                for enabled in modes {
                    try Task.checkCancellation()
                    rows.append(
                        try await measureCase(
                            entry, enabled: enabled, trial: trial, invocation: rows.count + 1))
                    progress(rows.count, total)
                }
            }
        }
        return rows
    }

    private func measureCase(
        _ entry: LoadedBenchmarkCase, enabled: Bool, trial: Int, invocation: Int
    )
        async throws -> BenchmarkMeasurement
    {
        let result = try await transcriber.transcribe(
            TranscriptionRequest(
                audioURL: entry.audioURL, prompt: enabled ? CardiologyVocabulary.prompt : nil))
        let score = WordErrorScore.compare(reference: entry.referenceText, hypothesis: result.text)
        return BenchmarkMeasurement(
            id: entry.definition.id, procedure: entry.definition.procedure,
            category: entry.definition.category,
            promptEnabled: enabled, trial: trial, invocation: invocation,
            audioSeconds: entry.durationSeconds,
            transcriptionSeconds: result.elapsedSeconds,
            realTimeFactor: result.elapsedSeconds / entry.durationSeconds,
            score: score, wordErrorRate: score.wordErrorRate,
            facts: entry.definition.expectedFacts.map { $0.evaluate(result.text) },
            reference: entry.referenceText, transcript: result.text)
    }

    static func summaries(_ rows: [BenchmarkMeasurement]) -> [BenchmarkSummary] {
        [false, true].flatMap { enabled in
            let matching = rows.filter { $0.promptEnabled == enabled }
            guard !matching.isEmpty else { return [BenchmarkSummary]() }
            return (["all"] + Set(matching.map(\.procedure)).sorted()).map { procedure in
                summarize(
                    matching.filter { procedure == "all" || $0.procedure == procedure },
                    enabled: enabled, procedure: procedure)
            }
        }
    }

    private static func summarize(_ rows: [BenchmarkMeasurement], enabled: Bool, procedure: String)
        -> BenchmarkSummary
    {
        let words = rows.reduce(0) { $0 + $1.score.referenceWords }
        let edits = rows.filter { $0.score.referenceWords > 0 }.reduce(0) { $0 + $1.score.edits }
        let times = rows.map(\.transcriptionSeconds).sorted()
        let middle = times.count / 2
        let median =
            times.count.isMultiple(of: 2) ? (times[middle - 1] + times[middle]) / 2 : times[middle]
        return BenchmarkSummary(
            promptEnabled: enabled, procedure: procedure, cases: rows.count,
            weightedWordErrorRate: words == 0 ? nil : Double(edits) / Double(words),
            medianSeconds: median, maximumSeconds: times.last ?? 0,
            missingFacts: rows.flatMap(\.facts).filter { !$0.matched }.count,
            unexpectedPhrases: rows.flatMap(\.facts).flatMap(\.unexpectedPhrases).count,
            nonSpeechInsertions: rows.filter { $0.score.referenceWords == 0 }.reduce(0) {
                $0 + $1.score.insertions
            })
    }
}
