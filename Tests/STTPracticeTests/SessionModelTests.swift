import Foundation
import STTCore
import XCTest

@testable import STTPractice

@MainActor
final class SessionModelTests: XCTestCase {
    func testRecordStopEditAndCopy() async throws {
        let capture = FakeCapture()
        let clipboard = FakeClipboard()
        let model = makeModel(capture: capture, clipboard: clipboard)
        await model.checkSetup()
        XCTAssertEqual(model.state, .idle)
        model.record()
        await wait { model.state == .recording }
        model.stop()
        await wait { model.state == .ready }
        XCTAssertEqual(model.rawText, "No coronary obstruction.")
        model.editedText = "Edited note"
        model.copyNote()
        XCTAssertEqual(clipboard.text, "Edited note")
        XCTAssertEqual(model.copyStatus, .copied)
        model.editedText += "."
        XCTAssertEqual(model.copyStatus, .stale)
        model.record()
        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.rawText, "No coronary obstruction.")
        model.newNote()
        XCTAssertTrue(model.editedText.isEmpty)
        XCTAssertEqual(model.state, .idle)
        await model.shutdown()
        let discarded = await capture.discardCount
        XCTAssertEqual(discarded, 1)
    }

    func testSystemInputLabelRejectsStaleRecordingEvents() async {
        let capture = FakeCapture()
        let model = makeModel(capture: capture)
        await model.checkSetup()
        model.record()
        await wait { model.state == .recording }
        let identifier = await capture.identifier
        if let identifier {
            capture.continuation.yield(
                .inputDevice(recordingID: identifier, systemDefaultName: "Wireless mic"))
        }
        await wait { model.systemInputName == "Wireless mic" }
        capture.continuation.yield(
            .inputDevice(recordingID: UUID(), systemDefaultName: "Other mic"))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.systemInputName, "Wireless mic")
        model.cancel()
        await wait { model.state == .idle }
        model.newNote()
        XCTAssertNil(model.systemInputName)
        await model.shutdown()
    }

    func testMixedBlankAudioWarnsWithoutRemovingTranscript() async {
        let raw = "Findings. [BLANK_AUDIO] [BLANK_AUDIO]"
        let model = makeModel(engine: ImmediateTranscriber(text: raw))
        model.retainForExport = true
        await model.checkSetup()
        model.record()
        await wait { model.state == .recording }
        model.stop()
        await wait { model.state == .ready }
        XCTAssertEqual(model.rawText, raw)
        XCTAssertEqual(model.editedText, "Findings:\n[BLANK_AUDIO] [BLANK_AUDIO]")
        XCTAssertTrue(model.message.contains("Speech may be missing"))
        XCTAssertNotNil(model.exportSnapshot())
        await model.shutdown()
    }

    func testMissingSpeechWithoutExportExplainsHowToCaptureAudio() async {
        let model = makeModel(engine: ImmediateTranscriber(text: "Findings. [BLANK_AUDIO]"))
        await model.checkSetup()
        model.record()
        await wait { model.state == .recording }
        model.stop()
        await wait { model.state == .ready }
        XCTAssertNil(model.exportSnapshot())
        XCTAssertTrue(model.message.contains("enable optional export before a new recording"))
        await model.shutdown()
    }

    func testCancelRejectsLateTranscription() async {
        let engine = HeldTranscriber()
        let model = makeModel(engine: engine)
        await model.checkSetup()
        model.record()
        await wait { model.state == .recording }
        model.stop()
        await wait { model.state == .transcribing }
        model.cancel()
        await engine.finish()
        await wait { model.state == .idle }
        XCTAssertTrue(model.rawText.isEmpty)
        await model.shutdown()
    }

    func testCopyFailureAndEmptyNotesAreNotSuccess() async {
        let clipboard = FakeClipboard()
        clipboard.succeeds = false
        let model = makeModel(clipboard: clipboard)
        await model.checkSetup()
        model.copyNote()
        XCTAssertEqual(clipboard.writes, 0)
        model.record()
        await wait { model.state == .recording }
        model.stop()
        await wait { model.state == .ready }
        model.copyNote()
        XCTAssertEqual(model.copyStatus, .failed)
        await model.shutdown()
    }

    func testStaleEventsCannotStopNewRecording() async {
        let capture = FakeCapture()
        let model = makeModel(capture: capture)
        await model.checkSetup()
        model.record()
        await wait { model.state == .recording }
        capture.continuation.yield(.limitReached(recordingID: UUID()))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.state, .recording)
        let identifier = await capture.identifier
        if let identifier { capture.continuation.yield(.limitReached(recordingID: identifier)) }
        await wait { model.state == .ready }
        await model.shutdown()
    }

    func testPermissionFailureCanRetryWithoutErasingText() async {
        let capture = FakeCapture()
        await capture.setStartError(.permissionDenied)
        let model = makeModel(capture: capture)
        await model.checkSetup()
        model.record()
        await wait { model.state == .error }
        XCTAssertTrue(model.message.contains("Microphone access denied"))
        await capture.setStartError(nil)
        model.record()
        await wait { model.state == .recording }
        model.stop()
        model.stop()
        await wait { model.state == .ready }
        let stops = await capture.stopCount
        XCTAssertEqual(stops, 1)
        await model.shutdown()
    }

    func testSetupFailureAndChangedPathsRequireCheck() async {
        let model = makeModel()
        await model.checkSetup()
        model.configuration.modelPath = "/missing"
        model.record()
        XCTAssertEqual(model.state, .setupNeeded)
        await model.shutdown()
        let failed = SessionModel(
            capture: FakeCapture(), clipboard: FakeClipboard(),
            setup: { _ in throw AudioCaptureError.cleanupFailed },
            transcriber: { _ in ImmediateTranscriber() })
        await failed.checkSetup()
        XCTAssertEqual(failed.state, .setupNeeded)
        await failed.shutdown()
    }

    func testCancelWhileStartIsPendingWaitsForCleanup() async {
        let capture = FakeCapture()
        await capture.holdStart()
        let model = makeModel(capture: capture)
        await model.checkSetup()
        model.record()
        await wait { model.state == .starting }
        model.cancel()
        await capture.releaseStart()
        await wait { model.state == .idle }
        XCTAssertTrue(model.rawText.isEmpty)
        await model.shutdown()
    }

    func testCaptureFailureRejectsStopDuringCleanup() async {
        let capture = FakeCapture()
        let model = makeModel(capture: capture)
        await model.checkSetup()
        model.record()
        await wait { model.state == .recording }
        await capture.holdCleanup()
        let identifier = await capture.identifier
        if let identifier {
            capture.continuation.yield(.failed(recordingID: identifier, error: .captureFailed))
        }
        await wait { model.state == .cancelling }
        model.stop()
        let stops = await capture.stopCount
        XCTAssertEqual(stops, 0)
        await capture.releaseCleanup()
        await wait { model.state == .error }
        XCTAssertTrue(model.rawText.isEmpty)
        await model.shutdown()
    }

    func testExportSnapshotSurvivesNewNote() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer {
            do { try FileManager.default.removeItem(at: root) } catch {
                XCTFail("Test cleanup failed")
            }
        }
        let model = makeModel()
        model.retainForExport = true
        await model.checkSetup()
        model.record()
        await wait { model.state == .recording }
        model.stop()
        await wait { model.state == .ready }
        model.editedText = "Selected note"
        let sample = try XCTUnwrap(model.exportSnapshot())
        model.newNote()
        model.exportSample(sample, to: root)
        await wait { model.exportStatus == "Practice sample exported." }
        let directory = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).first
        )
        XCTAssertEqual(
            try String(
                contentsOf: directory.appendingPathComponent("reference.txt"), encoding: .utf8),
            "Selected note")
        XCTAssertTrue(model.editedText.isEmpty)
        await model.shutdown()
    }

    func testNoExportAudioIsRetainedByDefault() async {
        let model = makeModel()
        await model.checkSetup()
        model.record()
        await wait { model.state == .recording }
        model.stop()
        await wait { model.state == .ready }
        XCTAssertNil(model.exportSnapshot())
        await model.shutdown()
    }

    func testNonSpeechMarkerRemainsRawButCannotBeCopied() async {
        let clipboard = FakeClipboard()
        let model = makeModel(
            clipboard: clipboard, engine: ImmediateTranscriber(text: "[BLANK_AUDIO]"))
        await model.checkSetup()
        model.record()
        await wait { model.state == .recording }
        model.stop()
        await wait { model.state == .error }
        XCTAssertEqual(model.rawText, "[BLANK_AUDIO]")
        XCTAssertTrue(model.editedText.isEmpty)
        model.copyNote()
        XCTAssertEqual(clipboard.writes, 0)
        await model.shutdown()
    }

    func testFormattingPreservesRawAndCopiesCurrentEdits() async {
        let raw = "  Findings. sixteen french sheath. no paravalvular leak.  "
        let clipboard = FakeClipboard()
        let model = makeModel(clipboard: clipboard, engine: ImmediateTranscriber(text: raw))
        model.retainForExport = true
        await model.checkSetup()
        model.record()
        await wait { model.state == .recording }
        model.stop()
        await wait { model.state == .ready }
        XCTAssertEqual(model.rawText, raw)
        XCTAssertEqual(model.editedText, "Findings:\n16 Fr sheath. no paravalvular leak.")
        model.editedText = "  My exact manual edit  "
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.editedText, "  My exact manual edit  ")
        model.copyNote()
        XCTAssertEqual(clipboard.text, "  My exact manual edit  ")
        XCTAssertEqual(model.exportSnapshot()?.reference, "  My exact manual edit  ")
        XCTAssertEqual(model.rawText, raw)
        await model.shutdown()
    }

    private func makeModel(
        capture: FakeCapture = FakeCapture(), clipboard: FakeClipboard = FakeClipboard(),
        engine: any TranscriberService = ImmediateTranscriber()
    ) -> SessionModel {
        SessionModel(
            capture: capture, clipboard: clipboard, setup: { _ in }, transcriber: { _ in engine })
    }

    private func wait(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line)
        async
    {
        for _ in 0..<10_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Session did not reach the expected state", file: file, line: line)
    }
}

private actor FakeCapture: AudioCaptureService {
    nonisolated let events: AsyncStream<AudioCaptureEvent>
    nonisolated let continuation: AsyncStream<AudioCaptureEvent>.Continuation
    var identifier: UUID?
    private var retainForExport = false
    var discardCount = 0
    var stopCount = 0
    private var cleanupHeld = false
    private var cleanupContinuation: CheckedContinuation<Void, Never>?
    func holdCleanup() { cleanupHeld = true }
    func releaseCleanup() {
        cleanupHeld = false
        cleanupContinuation?.resume()
        cleanupContinuation = nil
    }
    private var startError: AudioCaptureError?
    private var startHeld = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    func setStartError(_ error: AudioCaptureError?) { startError = error }
    func holdStart() { startHeld = true }
    func releaseStart() {
        startHeld = false
        startContinuation?.resume()
        startContinuation = nil
    }
    init() { (events, continuation) = AsyncStream.makeStream() }
    func start(recordingID: UUID, retainForExport: Bool) async throws {
        if startHeld { await withCheckedContinuation { startContinuation = $0 } }
        if let startError { throw startError }
        identifier = recordingID
        self.retainForExport = retainForExport
    }
    func stop() -> CapturedAudio {
        stopCount += 1
        return CapturedAudio(
            audioURL: URL(fileURLWithPath: "/unused-test.wav"), durationSeconds: 2,
            exportWAV: retainForExport ? Data([1, 2]) : nil)
    }
    func cancel() async {
        if cleanupHeld { await withCheckedContinuation { cleanupContinuation = $0 } }
        identifier = nil
    }
    func discard() { discardCount += 1 }
}

@MainActor
private final class FakeClipboard: NoteCopying {
    var text = ""
    var writes = 0
    var succeeds = true
    func copy(_ text: String) -> Bool {
        writes += 1
        self.text = text
        return succeeds
    }
}

private struct ImmediateTranscriber: TranscriberService {
    var text = "No coronary obstruction."
    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        TranscriptionResult(
            text: text, segments: [], elapsedSeconds: 1, modelID: "fake")
    }
}

private actor HeldTranscriber: TranscriberService {
    private var continuation: CheckedContinuation<TranscriptionResult, Never>?
    private var finished = false
    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        if finished { return result }
        return await withCheckedContinuation { continuation = $0 }
    }
    func finish() {
        finished = true
        continuation?.resume(returning: result)
        continuation = nil
    }
    private var result: TranscriptionResult {
        TranscriptionResult(text: "Late note", segments: [], elapsedSeconds: 1, modelID: "fake")
    }
}
