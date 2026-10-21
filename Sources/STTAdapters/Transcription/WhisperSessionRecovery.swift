import Darwin
import Foundation
import os

/// Removes private session directories only when their creator has definitely exited.
/// Call at launch; each transcription also runs recovery before creating its session.
public enum WhisperSessionRecovery {
    private static let prefix = "stt-whisper-"
    private static let logger = Logger(subsystem: "STTPOC", category: "WhisperSession")

    public static func removeAbandoned() throws {
        try removeAbandoned(
            in: FileManager.default.temporaryDirectory, isProcessAlive: processIsAlive)
    }

    static func removeAbandoned(
        in root: URL, currentUID: UInt32 = getuid(), isProcessAlive: (Int32) -> Bool?
    ) throws {
        do {
            let entries = try FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil)
            for entry in entries {
                guard let pid = creatorPID(entry.lastPathComponent), pid != getpid(),
                    isOwnedDirectory(entry, uid: currentUID), isProcessAlive(pid) == false
                else { continue }
                do { try FileManager.default.removeItem(at: entry) } catch let error as CocoaError
                    where error.code == .fileNoSuchFile
                {
                    // Another process can finish the same recovery after this directory was checked.
                    continue
                }
            }
        } catch { throw WhisperCppTranscriberError.sessionUnavailable }
    }

    static func createDirectory(in root: URL) throws -> URL {
        let directory = root.appendingPathComponent("\(prefix)\(getpid())-\(UUID())")
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700])
        } catch { throw WhisperCppTranscriberError.sessionUnavailable }
        return directory
    }

    static func removeOwnedDirectory(_ directory: URL) {
        do { try FileManager.default.removeItem(at: directory) } catch {
            // No path, transcript, prompt, or engine diagnostics enter the log.
            logger.error(
                "Whisper session cleanup failed; recovery will retry after this process exits.")
        }
    }

    private static func creatorPID(_ name: String) -> Int32? {
        guard name.hasPrefix(prefix) else { return nil }
        let parts = name.dropFirst(prefix.count).split(separator: "-", maxSplits: 1)
        guard parts.count == 2, let pid = Int32(parts[0]), pid > 0,
            UUID(uuidString: String(parts[1])) != nil
        else { return nil }
        return pid
    }

    private static func isOwnedDirectory(_ directory: URL, uid: UInt32) -> Bool {
        // Unreadable or concurrently removed entries have no verified owner and must be left alone.
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: directory.path)
        else {
            return false
        }
        return attributes[.type] as? FileAttributeType == .typeDirectory
            && (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == uid
    }

    private static func processIsAlive(_ pid: Int32) -> Bool? {
        if kill(pid, 0) == 0 { return true }
        return errno == ESRCH ? false : nil
    }
}
