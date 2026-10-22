import Darwin
import Foundation
import XCTest

@testable import STTAdapters

final class WhisperSessionRecoveryTests: XCTestCase {
    func testRemovesOnlyDeadOwnedSessionDirectories() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let dead = try makeSession(root, pid: 12345)
        let active = try makeSession(root, pid: 12346)
        let unknown = try makeSession(root, pid: 12347)
        let current = try makeSession(root, pid: getpid())
        let unrelated = root.appendingPathComponent("stt-whisper-old-format")
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: false)
        try WhisperSessionRecovery.removeAbandoned(in: root) { pid in
            switch pid {
            case 12345: false
            case 12346: true
            default: nil
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: dead.path))
        for url in [active, unknown, current, unrelated] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func testPreservesCurrentProcessEvenWhenLivenessSaysDead() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let current = try makeSession(root, pid: getpid())
        try WhisperSessionRecovery.removeAbandoned(in: root) { _ in false }
        XCTAssertTrue(FileManager.default.fileExists(atPath: current.path))
    }

    func testPreservesForeignOwnerAndSymlinkDirectories() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let foreign = try makeSession(root, pid: 12345)
        try WhisperSessionRecovery.removeAbandoned(in: root, currentUID: getuid() + 1) { _ in false
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: foreign.path))
        let destination = root.appendingPathComponent("outside-session")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        let link = root.appendingPathComponent("stt-whisper-12346-\(UUID())")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: destination)
        try WhisperSessionRecovery.removeAbandoned(in: root) { _ in false }
        XCTAssertTrue(FileManager.default.fileExists(atPath: link.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    func testCreatesPrivateSessionWithCreatorPID() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let session = try WhisperSessionRecovery.createDirectory(in: root)
        XCTAssertTrue(session.lastPathComponent.hasPrefix("stt-whisper-\(getpid())-"))
        let attributes = try FileManager.default.attributesOfItem(atPath: session.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o700)
    }

    func testInvalidRecoveryRootHasTypedError() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertThrowsError(try WhisperSessionRecovery.removeAbandoned(in: root) { _ in false }) {
            error in
            XCTAssertEqual(error as? WhisperCppTranscriberError, .sessionUnavailable)
        }
    }

    func testConcurrentRecoveryAlreadyRemovedDirectoryIsSuccess() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let session = try makeSession(root, pid: 12345)
        try WhisperSessionRecovery.removeAbandoned(in: root) { _ in
            do { try FileManager.default.removeItem(at: session) } catch {
                XCTFail("Concurrent recovery setup must remove the directory: \(error)")
            }
            return false
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: session.path))
    }

    func testRecoveryStillReportsPermissionFailure() throws {
        let root = try makeRoot()
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: root)
        }
        _ = try makeSession(root, pid: 12345)
        XCTAssertThrowsError(
            try WhisperSessionRecovery.removeAbandoned(in: root) { _ in
                do {
                    try FileManager.default.setAttributes(
                        [.posixPermissions: 0o500], ofItemAtPath: root.path)
                } catch { XCTFail("Permission fixture setup failed: \(error)") }
                return false
            }
        ) { error in
            XCTAssertEqual(error as? WhisperCppTranscriberError, .sessionUnavailable)
        }
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }

    private func makeSession(_ root: URL, pid: Int32) throws -> URL {
        let session = root.appendingPathComponent("stt-whisper-\(pid)-\(UUID())")
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: false)
        try Data("fictional output".utf8).write(
            to: session.appendingPathComponent("transcript.json"))
        return session
    }
}
