import Foundation
import Observation
import STTCore

struct PracticeConfiguration: Sendable, Equatable {
    var executablePath = "/opt/homebrew/bin/whisper-cli"
    var modelPath = "/opt/homebrew/share/whisper-cpp/ggml-medium.en.bin"
}

struct PracticeSample: Sendable {
    let audio: Data
    let reference: String
}

enum CopyStatus: Equatable { case none, copied, stale, failed }

/// Owns one note and its work. Only results from the current operation can change the note.
@MainActor @Observable
final class SessionModel {
    var configuration = PracticeConfiguration()
    var editedText = "" {
        didSet { if copyStatus == .copied { copyStatus = .stale } }
    }
    private(set) var state = PracticeState.setupNeeded
    private(set) var rawText = ""
    private(set) var message = "Check local setup before recording."
    private(set) var durationSeconds = 0.0
    private(set) var level: Float = 0
    private(set) var copyStatus = CopyStatus.none
    private(set) var exportWAV: Data?
    private let capture: any AudioCaptureService
    private let clipboard: any NoteCopying
    private let setup: @Sendable (PracticeConfiguration) async throws -> Void
    private let transcriber: @Sendable (PracticeConfiguration) -> any TranscriberService
    private var operation: Task<Void, Never>?
    private var exportTask: Task<Void, Never>?
    private(set) var exportStatus = ""
    private var eventTask: Task<Void, Never>?
    private var revision = UUID()
    private var recordingID: UUID?
    private var checkedConfiguration: PracticeConfiguration?
    private var closed = false

    init(
        capture: any AudioCaptureService, clipboard: any NoteCopying,
        setup: @escaping @Sendable (PracticeConfiguration) async throws -> Void,
        transcriber: @escaping @Sendable (PracticeConfiguration) -> any TranscriberService
    ) {
        self.capture = capture
        self.clipboard = clipboard
        self.setup = setup
        self.transcriber = transcriber
    }

    var canRecord: Bool {
        state.next(after: .record) != nil && rawText.isEmpty
            && checkedConfiguration == configuration && !closed
    }

    func requestSetupCheck() {
        guard state.next(after: .checkSetup) != nil else { return }
        operation = Task { await checkSetup() }
    }

    func checkSetup() async {
        guard !closed, rawText.isEmpty else { return }
        guard transition(.checkSetup) else { return }
        let snapshot = configuration
        let token = revision
        do {
            try await capture.cancel()
            try await setup(snapshot)
            guard token == revision, !closed else { return }
            guard transition(.setupSucceeded) else { return }
            checkedConfiguration = snapshot
            message = "Ready. Use fictional practice cases."
            listenForEvents()
        } catch {
            guard token == revision, !closed else { return }
            guard transition(.setupFailed) else { return }
            message = "Setup failed. Check executable, model, and temporary-folder permissions."
        }
    }

    func record() {
        guard rawText.isEmpty, !closed else { return }
        guard checkedConfiguration == configuration else {
            guard transition(.configurationChanged) else { return }
            message = "Setup paths changed. Check setup again."
            return
        }
        guard transition(.record) else { return }
        let token = UUID()
        revision = token
        recordingID = token
        durationSeconds = 0
        level = 0
        message = "Requesting microphone access…"
        operation = Task {
            do {
                try await capture.start(recordingID: token, retainForExport: true)
                try Task.checkCancellation()
                guard revision == token, !closed else { return }
                guard transition(.captureStarted) else { return }
                message =
                    "Recording. Maximum \(Int(RecordingConfiguration.maximumDurationSeconds)) seconds."
            } catch { await fail(error, token: token) }
        }
    }

    func stop() {
        guard let token = recordingID else { return }
        guard transition(.stop) else { return }
        message = "Preparing audio…"
        let engine = transcriber(configuration)
        operation = Task {
            do {
                let audio = try await capture.stop()
                try Task.checkCancellation()
                guard revision == token, !closed else { return }
                guard transition(.audioPrepared) else { return }
                durationSeconds = audio.durationSeconds
                message = "Transcribing locally…"
                let result = try await engine.transcribe(
                    TranscriptionRequest(
                        audioURL: audio.audioURL, prompt: CardiologyVocabulary.prompt))
                try Task.checkCancellation()
                try await capture.discard()
                guard revision == token, !closed else { return }
                recordingID = nil
                rawText = result.text
                let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let markers = ["[BLANK_AUDIO]", "[static]", "(water splashing)"]
                guard !text.isEmpty, !markers.contains(text) else {
                    guard transition(.transcriptRejected) else { return }
                    message = "No usable note returned. Select New Note to try again."
                    return
                }
                exportWAV = audio.exportWAV
                editedText = result.text
                guard transition(.transcriptAccepted) else { return }
                message = String(
                    format: "Transcribed in %.1f seconds. Review the text before copy.",
                    result.elapsedSeconds)
            } catch { await fail(error, token: token) }
        }
    }

    func cancel() {
        guard transition(.cancel) else { return }
        revision = UUID()
        recordingID = nil
        let previous = operation
        previous?.cancel()
        message = "Cancelling…"
        operation = Task {
            var cleaned = true
            do { try await capture.cancel() } catch { cleaned = false }
            await previous?.value
            do { try await capture.cancel() } catch { cleaned = false }
            guard !closed else { return }
            level = 0
            if cleaned {
                guard transition(.cancelled) else { return }
                message = "Cancelled. Recording files removed."
            } else {
                guard transition(.cleanupFailed) else { return }
                message = "Cleanup failed. Quit and check temporary-folder permissions."
            }
        }
    }

    func newNote() {
        guard !closed else { return }
        let event: PracticeEvent =
            checkedConfiguration == configuration ? .newNoteReady : .newNoteNeedsSetup
        guard transition(event) else { return }
        rawText = ""
        editedText = ""
        exportWAV = nil
        copyStatus = .none
        durationSeconds = 0
        level = 0
        message = "Ready for a new note."
    }

    func copyNote() {
        guard state == .ready, !editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        copyStatus = clipboard.copy(editedText) ? .copied : .failed
    }

    func exportSnapshot() -> PracticeSample? {
        guard state == .ready, let audio = exportWAV else { return nil }
        return PracticeSample(audio: audio, reference: editedText)
    }

    func exportSample(_ sample: PracticeSample, to directory: URL) {
        guard !closed, exportTask == nil else { return }
        exportStatus = "Exporting…"
        exportTask = Task {
            do {
                try await SampleWriter().write(
                    audio: sample.audio, reference: sample.reference, directory: directory)
                exportStatus = "Practice sample exported."
            } catch { exportStatus = "Export failed." }
            exportTask = nil
        }
    }

    func shutdown() async {
        closed = true
        revision = UUID()
        operation?.cancel()
        eventTask?.cancel()
        do { try await capture.cancel() } catch {
            message = "Recording cleanup failed at shutdown."
        }
        await operation?.value
        await eventTask?.value
        await exportTask?.value
        do { try await capture.cancel() } catch {
            message = "Recording cleanup failed at shutdown."
        }
        exportWAV = nil
    }

    /// All state writes pass through the transition contract before effects continue.
    private func transition(_ event: PracticeEvent) -> Bool {
        guard let next = state.next(after: event) else { return false }
        state = next
        return true
    }

    private func listenForEvents() {
        guard eventTask == nil else { return }
        let events = capture.events
        eventTask = Task { [weak self] in
            for await event in events {
                guard !Task.isCancelled else { break }
                self?.receive(event)
            }
        }
    }

    private func receive(_ event: AudioCaptureEvent) {
        switch event {
        case .level(let identifier, let rms, let duration):
            guard identifier == recordingID, state == .recording else { return }
            level = rms
            durationSeconds = duration
        case .limitReached(let identifier):
            guard identifier == recordingID else { return }
            stop()
        case .failed(let identifier, let error):
            guard identifier == recordingID, state == .starting || state == .recording else {
                return
            }
            guard transition(.failure) else { return }
            revision = UUID()
            let token = revision
            recordingID = nil
            let previous = operation
            previous?.cancel()
            operation = Task {
                await previous?.value
                await fail(error, token: token)
            }
        }
    }

    private func fail(_ error: Error, token: UUID) async {
        guard token == revision, !closed else { return }
        guard transition(.failure) else { return }
        do { try await capture.cancel() } catch {
            guard token == revision, !closed else { return }
            guard transition(.cleanupFailed) else { return }
            message = "Recording cleanup failed. Quit and check temporary-folder permissions."
            return
        }
        guard token == revision, !closed else { return }
        recordingID = nil
        guard transition(.failureCleaned) else { return }
        level = 0
        if error as? AudioCaptureError == .permissionDenied {
            message =
                "Microphone access denied. Allow STT Practice in System Settings → Privacy & Security → Microphone, then retry."
        } else if error as? AudioCaptureError == .emptyRecording {
            message = "Recording was empty or near-silent. Check the microphone and retry."
        } else {
            message =
                "Recording or transcription failed. Check the microphone and local setup, then retry."
        }
    }
}
