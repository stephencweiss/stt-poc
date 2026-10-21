import Foundation
import STTAdapters
import STTCore
import XCTest

@testable import STTBenchmark

final class BenchmarkRunnerTests: XCTestCase {
    func testPairedRunsAndSummariesUseTheSameFixtureSet() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let suite = try BenchmarkFixtureLoader.load(
            root.appendingPathComponent("Fixtures/Benchmark/manifest.json"))
        let runner = BenchmarkRunner(transcriber: ConstantTranscriber())
        let rows = try await runner.measure(suite, modes: [false, true], repetitions: 1)
        XCTAssertEqual(rows.count, suite.cases.count * 2)
        XCTAssertEqual(Set(rows.map(\.invocation)).count, rows.count)
        let summary = BenchmarkRunner.summaries(rows)
        let all = try XCTUnwrap(summary.first { !$0.promptEnabled && $0.procedure == "all" })
        XCTAssertEqual(all.cases, suite.cases.count)
        XCTAssertEqual(all.medianSeconds, 0.25)
        XCTAssertEqual(all.nonSpeechInsertions, 4)
        let controls = try XCTUnwrap(
            summary.first { !$0.promptEnabled && $0.procedure == "control" })
        XCTAssertNil(controls.weightedWordErrorRate)
    }

    func testEngineFailureStopsTheBenchmark() async throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let suite = try BenchmarkFixtureLoader.load(
            root.appendingPathComponent("Fixtures/Benchmark/manifest.json"))
        do {
            _ = try await BenchmarkRunner(transcriber: FailingTranscriber()).measure(
                suite, modes: [false], repetitions: 1)
            XCTFail("A failed case must not be skipped")
        } catch is TestEngineError {
            // Expected engine error must reach the command, preventing a partial success report.
        }
    }
}

private struct ConstantTranscriber: TranscriberService {
    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        TranscriptionResult(
            text: "unexpected text", segments: [], elapsedSeconds: 0.25, modelID: "test")
    }
}

private enum TestEngineError: Error { case failed }

private struct FailingTranscriber: TranscriberService {
    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        throw TestEngineError.failed
    }
}
