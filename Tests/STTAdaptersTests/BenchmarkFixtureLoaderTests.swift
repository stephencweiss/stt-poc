import Foundation
import STTCore
import STTTestSupport
import XCTest

@testable import STTAdapters

final class BenchmarkFixtureLoaderTests: XCTestCase {
    func testCommittedSuiteLoadsCanonicalAudioAndReferences() throws {
        let root = try TestPackageRoot.find()
        let suite = try BenchmarkFixtureLoader.load(
            root.appendingPathComponent("Fixtures/Benchmark/manifest.json"))
        XCTAssertGreaterThanOrEqual(suite.cases.count, 14)
        XCTAssertTrue(suite.cases.allSatisfy { $0.durationSeconds > 0 })
        XCTAssertTrue(suite.cases.contains { $0.definition.procedure == "tavr" })
    }

    func testCommittedExpectedFactsAgreeWithTheirReference() throws {
        let root = try TestPackageRoot.find()
        let suite = try BenchmarkFixtureLoader.load(
            root.appendingPathComponent("Fixtures/Benchmark/manifest.json"))
        for entry in suite.cases {
            for fact in entry.definition.expectedFacts {
                let result = fact.evaluate(entry.referenceText)
                XCTAssertTrue(
                    result.matched,
                    "\(entry.definition.id): \(fact.id) is absent from its reference")
                XCTAssertTrue(
                    result.unexpectedPhrases.isEmpty,
                    "\(entry.definition.id): \(fact.id) forbids reference text")
            }
        }
    }

    func testChecksumChangeAndUnlistedAudioAreRejected() throws {
        let root = try TestPackageRoot.find()
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)
        try FileManager.default.copyItem(
            at: root.appendingPathComponent("Fixtures/Benchmark"), to: temporary)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let manifest = temporary.appendingPathComponent("manifest.json")
        try Data([0]).write(to: temporary.appendingPathComponent("audio/extra.wav"))
        XCTAssertThrowsError(try BenchmarkFixtureLoader.load(manifest))
        try FileManager.default.removeItem(at: temporary.appendingPathComponent("audio/extra.wav"))
        try Data("changed".utf8).write(
            to: temporary.appendingPathComponent("references/cardio_01.txt"))
        XCTAssertThrowsError(try BenchmarkFixtureLoader.load(manifest))
    }

    func testPathTraversalIsRejected() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertThrowsError(try BenchmarkFixtureLoader.resolve("../escape", under: base))
        XCTAssertThrowsError(try BenchmarkFixtureLoader.resolve("/etc/passwd", under: base))
    }
}
