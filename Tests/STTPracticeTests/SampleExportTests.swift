import Foundation
import XCTest

@testable import STTPractice

final class SampleExportTests: XCTestCase {
    func testExportsSnapshotIntoSeparatePrivateDirectories() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer {
            do { try FileManager.default.removeItem(at: root) } catch {
                XCTFail("Test cleanup failed")
            }
        }
        let writer = SampleWriter()
        try await writer.write(audio: Data([1, 2]), reference: "First", directory: root)
        try await writer.write(audio: Data([3, 4]), reference: "Second", directory: root)
        let samples = try FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil)
        XCTAssertEqual(samples.count, 2)
        var references = Set<String>()
        for sample in samples {
            references.insert(
                try String(
                    contentsOf: sample.appendingPathComponent("reference.txt"), encoding: .utf8))
            let attributes = try FileManager.default.attributesOfItem(atPath: sample.path)
            XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o700)
        }
        XCTAssertEqual(references, ["First", "Second"])
    }

    func testMissingDestinationIsAnError() async {
        let absent = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)
        do {
            try await SampleWriter().write(audio: Data([1]), reference: "Test", directory: absent)
            XCTFail("Missing destination must fail")
        } catch { XCTAssertFalse(FileManager.default.fileExists(atPath: absent.path)) }
    }
}
