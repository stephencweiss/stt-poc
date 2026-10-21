import Darwin
import Foundation
import XCTest

final class BenchmarkSignalTests: XCTestCase {
    func testTerminationStopsEngineAndRemovesSessionWithoutWritingReport() async throws {
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }  // Test-owned temporary files only.
        let engine = root.appendingPathComponent("fake-engine")
        let marker = root.appendingPathComponent("session")
        let script = """
            #!/bin/sh
            while [ "$#" -gt 0 ]; do
              case "$1" in -of) shift; printf '%s' "$1" > '\(marker.path)' ;; esac
              shift
            done
            trap '' TERM
            exec /bin/sleep 30
            """
        try Data(script.utf8).write(to: engine)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: engine.path)
        let model = root.appendingPathComponent("model.bin")
        try Data([1]).write(to: model)
        let report = root.appendingPathComponent("report.json")
        let command = Process()
        command.executableURL = project.appendingPathComponent(".build/debug/STTBenchmark")
        command.currentDirectoryURL = project
        command.arguments = [
            "--report", report.path, "--executable", engine.path, "--model", model.path,
        ]
        command.standardOutput = FileHandle.nullDevice
        command.standardError = FileHandle.nullDevice
        try command.run()
        defer {
            if command.isRunning { kill(command.processIdentifier, SIGKILL) }
        }
        try await wait { FileManager.default.fileExists(atPath: marker.path) }
        let session = URL(fileURLWithPath: try String(contentsOf: marker, encoding: .utf8))
            .deletingLastPathComponent()
        XCTAssertTrue(FileManager.default.fileExists(atPath: session.path))
        kill(command.processIdentifier, SIGTERM)
        try await wait { !command.isRunning }
        XCTAssertEqual(command.terminationStatus, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: report.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: session.path))
    }

    private func wait(until condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(15))
        while !condition() {
            guard ContinuousClock.now < deadline else { throw CocoaError(.executableNotLoadable) }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
