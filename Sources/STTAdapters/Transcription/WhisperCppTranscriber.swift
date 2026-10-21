import Darwin
import Foundation
import STTCore
import os

public enum WhisperCppTranscriberError: Error, Sendable, Equatable {
    case invalidExecutable
    case invalidModel
    case invalidAudio
    case invalidTimeout
    case sessionUnavailable
    case launchFailed
    case processFailed(exitCode: Int32)
    case timedOut
    case invalidOutput
}

/// Runs one private whisper.cpp session per request. Input must be 16 kHz mono PCM16 WAV.
/// Diagnostic streams are discarded. Only the JSON transcript is read.
public struct WhisperCppTranscriber: TranscriberService {
    private let executableURL: URL
    private let modelURL: URL
    private let timeoutSeconds: Double

    public init(executableURL: URL, modelURL: URL, timeoutSeconds: Double = 180) {
        self.executableURL = executableURL
        self.modelURL = modelURL
        self.timeoutSeconds = timeoutSeconds
    }

    public func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        try await WhisperSession().run(
            request, executable: executableURL, model: modelURL, timeout: timeoutSeconds
        )
    }
}

/// All Process and file resources stay on this actor, including cancellation and reaping.
private actor WhisperSession {
    func run(
        _ request: TranscriptionRequest, executable: URL, model: URL, timeout: Double
    ) async throws -> TranscriptionResult {
        try Task.checkCancellation()
        let executable = executable.resolvingSymlinksInPath()
        let model = model.resolvingSymlinksInPath()
        try validate(request, executable: executable, model: model, timeout: timeout)
        try WhisperSessionRecovery.removeAbandoned()
        let directory = try WhisperSessionRecovery.createDirectory(
            in: FileManager.default.temporaryDirectory)
        defer {
            WhisperSessionRecovery.removeOwnedDirectory(directory)
        }
        let output = directory.appendingPathComponent("transcript")
        let process = configuredProcess(
            request, executable: executable, model: model, output: output)
        let completion = OSAllocatedUnfairLock<Int32?>(initialState: nil)
        process.terminationHandler = { process in
            completion.withLock { $0 = process.terminationStatus }
        }
        try Task.checkCancellation()
        let start = ContinuousClock.now
        do { try process.run() } catch { throw WhisperCppTranscriberError.launchFailed }
        do {
            try await wait(completion, start: start, timeout: timeout, output: output)
        } catch {
            await stopAndReap(process, completion: completion)
            throw error
        }
        try Task.checkCancellation()
        guard process.terminationStatus == 0 else {
            throw WhisperCppTranscriberError.processFailed(exitCode: process.terminationStatus)
        }
        let segments = try readSegments(output.appendingPathExtension("json"))
        let elapsed = start.duration(to: .now)
        let seconds =
            Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        return TranscriptionResult(
            text: segments.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines),
            segments: segments, elapsedSeconds: seconds, modelID: model.lastPathComponent
        )
    }

    private func validate(
        _ request: TranscriptionRequest, executable: URL, model: URL, timeout: Double
    ) throws {
        guard timeout.isFinite, timeout > 0 else { throw WhisperCppTranscriberError.invalidTimeout }
        guard regularFile(executable), FileManager.default.isExecutableFile(atPath: executable.path)
        else {
            throw WhisperCppTranscriberError.invalidExecutable
        }
        guard regularFile(model), FileManager.default.isReadableFile(atPath: model.path),
            (try? model.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 > 0
        else { throw WhisperCppTranscriberError.invalidModel }
        guard regularFile(request.audioURL) else { throw WhisperCppTranscriberError.invalidAudio }
        do { try CanonicalWAV.validate(request.audioURL) } catch {
            throw WhisperCppTranscriberError.invalidAudio
        }
    }

    private func regularFile(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        // Failure to inspect external assets is a validation failure, not an I/O recovery path.
        return (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private func configuredProcess(
        _ request: TranscriptionRequest, executable: URL, model: URL, output: URL
    ) -> Process {
        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "-m", model.path, "-f", request.audioURL.path, "-l", "en", "-oj", "-of", output.path,
            "-np",
        ]
        if let prompt = request.prompt {
            process.arguments?.append(contentsOf: ["--prompt", prompt])
        }
        // No pipes can fill and no diagnostic or private content is retained.
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        return process
    }

    private func wait(
        _ completion: OSAllocatedUnfairLock<Int32?>,
        start: ContinuousClock.Instant, timeout: Double, output: URL
    ) async throws {
        while completion.withLock({ $0 }) == nil {
            try Task.checkCancellation()
            let elapsed = start.duration(to: .now).components
            let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
            guard seconds < timeout else { throw WhisperCppTranscriberError.timedOut }
            try validateOutputSize(output.appendingPathExtension("json"))
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func stopAndReap(_ process: Process, completion: OSAllocatedUnfairLock<Int32?>) async {
        if process.isRunning {
            process.terminate()
            // SIGKILL also handles engines that ignore SIGTERM. Reap before deleting session files.
            kill(process.processIdentifier, SIGKILL)
        }
        // Foundation reaps the child before it calls terminationHandler. Do not call
        // waitUntilExit from a cooperative executor: its run loop can stall indefinitely.
        while completion.withLock({ $0 }) == nil { await Task.yield() }
    }

    private func validateOutputSize(_ url: URL) throws {
        // A missing output is normal while whisper.cpp runs. Final reads still require the file.
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= 16 * 1024 * 1024 else { throw WhisperCppTranscriberError.invalidOutput }
    }

    private func readSegments(_ url: URL) throws -> [TranscriptSegment] {
        do {
            try validateOutputSize(url)
            let payload = try JSONDecoder().decode(WhisperOutput.self, from: Data(contentsOf: url))
            return try payload.transcription.map { entry in
                guard entry.offsets.from >= 0, entry.offsets.to >= entry.offsets.from else {
                    throw WhisperCppTranscriberError.invalidOutput
                }
                return TranscriptSegment(
                    text: entry.text,
                    startSeconds: Double(entry.offsets.from) / 1000,
                    endSeconds: Double(entry.offsets.to) / 1000
                )
            }
        } catch { throw WhisperCppTranscriberError.invalidOutput }
    }
}

private struct WhisperOutput: Decodable {
    let transcription: [WhisperEntry]
}

private struct WhisperEntry: Decodable {
    let text: String
    let offsets: WhisperOffsets
}

private struct WhisperOffsets: Decodable {
    let from: Int
    let to: Int
}
