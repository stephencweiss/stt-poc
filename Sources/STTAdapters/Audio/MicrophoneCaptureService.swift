import Foundation
import STTCore

/// Owns one microphone session and its files. Call discard after transcription, or cancel on exit.
/// Export data is retained in the returned value only when start explicitly opts in.
public actor MicrophoneCaptureService: AudioCaptureService {
    public nonisolated let events: AsyncStream<AudioCaptureEvent>
    private let continuation: AsyncStream<AudioCaptureEvent>.Continuation
    private let directoryRoot: URL
    private let permission: @Sendable () async -> Bool
    private let makeRecorder: @Sendable (URL) throws -> any CaptureRecorder
    private let automaticMonitoring: Bool
    private var state = CaptureState.idle
    private var monitorTask: Task<Void, Never>?
    private var permissionTask: Task<Bool, Never>?

    public init() {
        let stream = AsyncStream.makeStream(
            of: AudioCaptureEvent.self, bufferingPolicy: .bufferingNewest(8))
        events = stream.stream
        continuation = stream.continuation
        directoryRoot = FileManager.default.temporaryDirectory
        permission = MicrophonePermission.request
        makeRecorder = { try FrameworkAudioRecorder(url: $0) }
        automaticMonitoring = true
    }

    init(
        directoryRoot: URL, permission: @escaping @Sendable () async -> Bool,
        makeRecorder: @escaping @Sendable (URL) throws -> any CaptureRecorder,
        automaticMonitoring: Bool = false
    ) {
        let stream = AsyncStream.makeStream(
            of: AudioCaptureEvent.self, bufferingPolicy: .bufferingNewest(8))
        events = stream.stream
        continuation = stream.continuation
        self.directoryRoot = directoryRoot
        self.permission = permission
        self.makeRecorder = makeRecorder
        self.automaticMonitoring = automaticMonitoring
    }

    deinit {
        monitorTask?.cancel()
        permissionTask?.cancel()
        continuation.finish()
        state.recorder?.stop()
        if let directory = state.directory { AudioSessionDirectory.cleanOnDeinit(directory) }
    }

    public nonisolated static func recoverAbandonedSessions() throws {
        try AudioSessionDirectory.recover(in: FileManager.default.temporaryDirectory)
    }

    public func start(recordingID: UUID, retainForExport: Bool) async throws {
        guard case .idle = state else { throw AudioCaptureError.alreadyRecording }
        try Task.checkCancellation()
        let token = UUID()
        state = .starting(token)
        let permission = self.permission
        let pending = Task { await permission() }
        permissionTask = pending
        let granted = await withTaskCancellationHandler {
            await pending.value
        } onCancel: {
            pending.cancel()
        }
        guard case .starting(let current) = state, current == token else {
            throw CancellationError()
        }
        permissionTask = nil
        state = .idle
        try Task.checkCancellation()
        guard granted else { throw AudioCaptureError.permissionDenied }
        try AudioSessionDirectory.recover(in: directoryRoot)
        let directory = try AudioSessionDirectory.create(in: directoryRoot)
        state = .retained(directory)
        do {
            let recorder = try makeRecorder(directory.appendingPathComponent("capture.caf"))
            let capture = OwnedCapture(
                recordingID: recordingID, directory: directory, retainForExport: retainForExport)
            state = .recording(capture, recorder)
            try Task.checkCancellation()
            try recorder.start()
            beginMonitoring(recordingID: recordingID)
        } catch {
            try cleanUp()
            throw error
        }
    }

    public func stop() async throws -> CapturedAudio {
        let capture: OwnedCapture
        switch state {
        case .recording(let owned, let recorder):
            let status = recorder.snapshot()
            recorder.stop()
            if let error = status.failure {
                try cleanUp()
                throw error
            }
            capture = owned
        case .finished(let owned): capture = owned
        default: throw AudioCaptureError.noRecording
        }
        monitorTask?.cancel()
        monitorTask = nil
        state = .retained(capture.directory)
        do {
            try Task.checkCancellation()
            let output = capture.directory.appendingPathComponent("recording.wav")
            let result = try CaptureAudioConverter.convert(
                input: capture.directory.appendingPathComponent("capture.caf"), output: output)
            let bytes = try exportBytes(output, enabled: capture.retainForExport)
            try Task.checkCancellation()
            return CapturedAudio(
                audioURL: output, durationSeconds: result.durationSeconds, exportWAV: bytes)
        } catch {
            try cleanUp()
            throw error
        }
    }

    public func cancel() async throws { try cleanUp() }
    public func discard() async throws { try cleanUp() }

    /// Polling reads framework meters; it never handles audio buffers or writes capture samples.
    func poll(recordingID: UUID? = nil) {
        guard case .recording(let capture, let recorder) = state else { return }
        guard recordingID == nil || recordingID == capture.recordingID else { return }
        let snapshot = recorder.snapshot()
        if let failure = snapshot.failure {
            fail(capture, recorder: recorder, error: failure)
            return
        }
        if snapshot.durationSeconds >= 120
            || (!snapshot.isRecording && snapshot.durationSeconds >= 119.5)
        {
            recorder.stop()
            monitorTask?.cancel()
            monitorTask = nil
            state = .finished(capture)
            continuation.yield(.limitReached(recordingID: capture.recordingID))
            return
        }
        guard snapshot.isRecording else {
            fail(capture, recorder: recorder, error: .captureFailed)
            return
        }
        continuation.yield(
            .level(
                recordingID: capture.recordingID, rms: min(1, max(0, snapshot.rms)),
                durationSeconds: snapshot.durationSeconds))
    }

    private func beginMonitoring(recordingID: UUID) {
        guard automaticMonitoring else { return }
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                guard let self else { return }
                await self.poll(recordingID: recordingID)
            }
        }
    }

    private func fail(
        _ capture: OwnedCapture, recorder: any CaptureRecorder, error: AudioCaptureError
    ) {
        recorder.stop()
        do {
            try cleanUp()
            continuation.yield(.failed(recordingID: capture.recordingID, error: error))
        } catch {
            continuation.yield(.failed(recordingID: capture.recordingID, error: .cleanupFailed))
        }
    }

    private func cleanUp() throws {
        permissionTask?.cancel()
        permissionTask = nil
        monitorTask?.cancel()
        monitorTask = nil
        state.recorder?.stop()
        if let directory = state.directory {
            state = .retained(directory)
            try AudioSessionDirectory.remove(directory)
        }
        state = .idle
    }

    private func exportBytes(_ url: URL, enabled: Bool) throws -> Data? {
        guard enabled else { return nil }
        do { return try Data(contentsOf: url) } catch { throw AudioCaptureError.writeFailed }
    }
}

private struct OwnedCapture: Sendable {
    let recordingID: UUID
    let directory: URL
    let retainForExport: Bool
}

private enum CaptureState: Sendable {
    case idle
    case starting(UUID)
    case recording(OwnedCapture, any CaptureRecorder)
    case finished(OwnedCapture)
    case retained(URL)

    var directory: URL? {
        switch self {
        case .recording(let capture, _), .finished(let capture): capture.directory
        case .retained(let directory): directory
        default: nil
        }
    }

    var recorder: (any CaptureRecorder)? {
        if case .recording(_, let recorder) = self { recorder } else { nil }
    }
}
