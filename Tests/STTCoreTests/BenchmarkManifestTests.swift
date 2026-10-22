import Foundation
import XCTest

@testable import STTCore

final class BenchmarkManifestTests: XCTestCase {
    private func entry(id: String = "one") -> BenchmarkCase {
        BenchmarkCase(
            id: id, audio: "audio/one.wav", reference: "references/one.txt",
            audioSha256: String(repeating: "a", count: 64),
            referenceSha256: String(repeating: "b", count: 64),
            category: "clear", origin: "fictional", procedure: "pci", expectedFacts: [])
    }

    func testRejectsEmptyUnsupportedAndDuplicateSuites() {
        XCTAssertThrowsError(try BenchmarkManifest(version: 1, cases: []).validate())
        XCTAssertThrowsError(try BenchmarkManifest(version: 2, cases: [entry()]).validate())
        XCTAssertThrowsError(
            try BenchmarkManifest(version: 1, cases: [entry(), entry()]).validate())
        XCTAssertNoThrow(try BenchmarkManifest(version: 1, cases: [entry()]).validate())
    }
}
