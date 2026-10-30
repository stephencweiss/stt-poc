import Darwin
import Foundation
import STTCore
import os

/// Creates and removes temporary recording folders and recovers abandoned sessions.
enum AudioSessionDirectory {
    /// Identifies recording folders named stt-audio-<process ID>-<UUID>.
    /// Recovery also checks the name, folder type, owner, and creator process before removal.
    private static let prefix = "stt-audio-"
    private static let logger = Logger(subsystem: "STTPOC", category: "AudioCapture")

    static func create(in root: URL) throws -> URL {
        let directory = root.appendingPathComponent("\(prefix)\(getpid())-\(UUID())")
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700])
        } catch { throw AudioCaptureError.writeFailed }
        return directory
    }

    static func remove(_ directory: URL) throws {
        do { try FileManager.default.removeItem(at: directory) } catch let error as CocoaError
            where error.code == .fileNoSuchFile
        { return } catch { throw AudioCaptureError.cleanupFailed }
    }

    static func recover(in root: URL, isProcessAlive: (Int32) -> Bool? = processIsAlive) throws {
        do {
            for directory in try FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil)
            {
                guard let pid = creatorPID(directory.lastPathComponent), pid != getpid(),
                    isOwnedDirectory(directory),
                    isProcessAlive(pid) == false
                else { continue }
                try remove(directory)
            }
        } catch { throw AudioCaptureError.cleanupFailed }
    }

    static func cleanOnDeinit(_ directory: URL) {
        do { try remove(directory) } catch {
            logger.error(
                "Audio session cleanup failed; abandoned-session recovery will retry after exit.")
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

    private static func isOwnedDirectory(_ directory: URL) -> Bool {
        // An unverified or concurrently removed entry is left alone; symlinks are not directories here.
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: directory.path)
        else { return false }
        return attributes[.type] as? FileAttributeType == .typeDirectory
            && (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid()
    }

    private static func processIsAlive(_ pid: Int32) -> Bool? {
        if kill(pid, 0) == 0 { return true }
        return errno == ESRCH ? false : nil
    }
}
