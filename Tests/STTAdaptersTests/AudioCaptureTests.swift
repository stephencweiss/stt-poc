import AVFoundation
import Darwin
import Foundation
import STTCore
import XCTest
import os

@testable import STTAdapters

final class AudioCaptureTests: XCTestCase {
    func testConvertsStereoRatesAndFlushesLastFrames() throws {
        for rate in [44100.0, 48000.0] {
            let root = try makeRoot()
            defer { try? FileManager.default.removeItem(at: root) }
            let input = root.appendingPathComponent("input.caf")
            try writeTone(input, rate: rate, channels: 2, seconds: 0.517)
            let output = root.appendingPathComponent("output.wav")
            let result = try CaptureAudioConverter.convert(input: input, output: output)
            try CanonicalWAV.validate(output)
            let file = try AVAudioFile(forReading: output)
            XCTAssertEqual(file.fileFormat.sampleRate, 16000)
            XCTAssertEqual(file.fileFormat.channelCount, 1)
            XCTAssertEqual(file.fileFormat.settings[AVLinearPCMBitDepthKey] as? Int, 16)
            XCTAssertEqual(result.durationSeconds, 0.517, accuracy: 0.002)
            XCTAssertEqual(Double(file.length) / 16000, 0.517, accuracy: 0.002)
        }
    }

    func testConversionPreservesSignalAcrossThirtySecondBoundary() throws {
        for rate in [16000.0, 44100.0, 48000.0] {
            let root = try makeRoot()
            defer { try? FileManager.default.removeItem(at: root) }
            let input = root.appendingPathComponent("input.caf")
            try writeTone(input, rate: rate, channels: 2, seconds: 36.25)
            let output = root.appendingPathComponent("output.wav")
            _ = try CaptureAudioConverter.convert(input: input, output: output)
            let file = try AVAudioFile(forReading: output)
            XCTAssertEqual(Double(file.length) / 16000, 36.25, accuracy: 0.002)
            let buffer = try XCTUnwrap(
                AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 1600))
            for second in [0, 1, 15, 29, 30, 31, 35, 36] {
                file.framePosition = AVAudioFramePosition(second * 16000)
                try file.read(into: buffer, frameCount: 1600)
                XCTAssertEqual(buffer.frameLength, 1600)
                let samples = try XCTUnwrap(buffer.floatChannelData?[0])
                let energy = (0..<Int(buffer.frameLength)).reduce(0.0) {
                    $0 + Double(samples[$1]) * Double(samples[$1])
                }
                XCTAssertGreaterThan(sqrt(energy / Double(buffer.frameLength)), 0.1)
            }
        }
    }

    func testRetainsFullConfiguredDuration() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("input.caf")
        try writeTone(
            input, rate: 48000, channels: 1, seconds: RecordingConfiguration.maximumDurationSeconds)
        let result = try CaptureAudioConverter.convert(
            input: input, output: root.appendingPathComponent("output.wav"))
        XCTAssertEqual(
            result.durationSeconds, RecordingConfiguration.maximumDurationSeconds, accuracy: 0.002)
    }

    func testEmptySilentInvalidAndWriteFailuresAreTyped() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("input.caf")
        let output = root.appendingPathComponent("output.wav")
        for amplitude in [Float(0), Float(0.00001)] {
            try writeTone(input, rate: 48000, channels: 1, seconds: 0.1, amplitude: amplitude)
            XCTAssertThrowsError(try CaptureAudioConverter.convert(input: input, output: output)) {
                error in
                XCTAssertEqual(error as? AudioCaptureError, .emptyRecording)
            }
        }
        try writeTone(input, rate: 48000, channels: 1, seconds: 0)
        XCTAssertThrowsError(try CaptureAudioConverter.convert(input: input, output: output)) {
            error in
            XCTAssertEqual(error as? AudioCaptureError, .emptyRecording)
        }
        try Data("invalid audio".utf8).write(to: input)
        XCTAssertThrowsError(try CaptureAudioConverter.convert(input: input, output: output)) {
            error in
            XCTAssertEqual(error as? AudioCaptureError, .conversionFailed)
        }
        try writeTone(input, rate: 48000, channels: 1, seconds: 0.1)
        XCTAssertThrowsError(
            try CaptureAudioConverter.convert(
                input: input, output: root.appendingPathComponent("missing/output.wav"))
        ) { error in
            XCTAssertEqual(error as? AudioCaptureError, .writeFailed)
        }
    }

    func testCaptureReportsSystemInputAtStart() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = makeService(root: root, recorder: FakeCaptureRecorder())
        var events = service.events.makeAsyncIterator()
        let identifier = UUID()
        try await service.start(recordingID: identifier, retainForExport: false)
        await service.poll()
        guard case .inputDevice(let id, let name) = await events.next() else {
            try await service.cancel()
            return XCTFail("Expected input name before meter events")
        }
        XCTAssertEqual(id, identifier)
        XCTAssertEqual(name, "Test input")
        try await service.cancel()
    }

    func testCaptureOwnershipExportAndDiscard() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = FakeCaptureRecorder()
        let service = makeService(root: root, recorder: recorder)
        for retain in [false, true] {
            try await service.start(recordingID: UUID(), retainForExport: retain)
            let audio = try await service.stop()
            XCTAssertEqual(audio.durationSeconds, 0.25, accuracy: 0.002)
            XCTAssertEqual(audio.exportWAV != nil, retain)
            XCTAssertTrue(FileManager.default.fileExists(atPath: audio.audioURL.path))
            let directory = audio.audioURL.deletingLastPathComponent()
            let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
            XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o700)
            try await service.discard()
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        }
    }

    func testCancelDuringPermissionCannotStartLater() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let permission = PermissionGate()
        let recorder = FakeCaptureRecorder()
        let service = MicrophoneCaptureService(
            directoryRoot: root, permission: { await permission.wait() },
            makeRecorder: { _ in recorder })
        let start = Task { try await service.start(recordingID: UUID(), retainForExport: false) }
        await permission.waitUntilRequested()
        try await service.cancel()
        await permission.resolve(true)
        do {
            try await start.value
            XCTFail("Cancelled permission request must not start recording")
        } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(recorder.starts.withLock { $0 }, 0)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    func testPermissionDenialAndUnavailableDeviceCleanUp() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let denied = MicrophoneCaptureService(
            directoryRoot: root, permission: { false }, makeRecorder: { _ in FakeCaptureRecorder() }
        )
        do {
            try await denied.start(recordingID: UUID(), retainForExport: false)
            XCTFail("Permission denied")
        } catch { XCTAssertEqual(error as? AudioCaptureError, .permissionDenied) }
        let unavailable = MicrophoneCaptureService(
            directoryRoot: root, permission: { true },
            makeRecorder: { _ in throw AudioCaptureError.unavailableDevice })
        do {
            try await unavailable.start(recordingID: UUID(), retainForExport: false)
            XCTFail("Device missing")
        } catch { XCTAssertEqual(error as? AudioCaptureError, .unavailableDevice) }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    func testDeviceFailureAndLimitEventsKeepRecordingID() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = FakeCaptureRecorder()
        let service = makeService(root: root, recorder: recorder)
        var events = service.events.makeAsyncIterator()
        let first = UUID()
        try await service.start(recordingID: first, retainForExport: false)
        _ = await events.next()
        recorder.status.withLock {
            $0 = .init(isRecording: false, durationSeconds: 1, rms: 0, failure: .unavailableDevice)
        }
        await service.poll()
        guard case .failed(let id, let error) = await events.next() else {
            return XCTFail("Expected device failure")
        }
        XCTAssertEqual(id, first)
        XCTAssertEqual(error, .unavailableDevice)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        let second = UUID()
        try await service.start(recordingID: second, retainForExport: false)
        _ = await events.next()
        recorder.status.withLock {
            $0 = .init(
                isRecording: false, durationSeconds: RecordingConfiguration.maximumDurationSeconds,
                rms: 0.2, failure: nil)
        }
        await service.poll()
        guard case .limitReached(let id) = await events.next() else {
            return XCTFail("Expected duration limit")
        }
        XCTAssertEqual(id, second)
        _ = try await service.stop()
        try await service.discard()
    }

    func testPermissionBridgeCancellationDoesNotWaitForSystemDecision() async throws {
        let callback = OSAllocatedUnfairLock<(@Sendable (Bool) -> Void)?>(initialState: nil)
        let requested = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        let permission = Task {
            await MicrophonePermission.waitForDecision { reply in
                callback.withLock { $0 = reply }
                requested.continuation.yield(())
            }
        }
        var iterator = requested.stream.makeAsyncIterator()
        _ = await iterator.next()
        permission.cancel()
        let granted = await permission.value
        XCTAssertFalse(granted)
        callback.withLock { $0 }?(true)
        requested.continuation.finish()
    }

    func testSilentStopAndCancellationRemoveOwnedFiles() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = FakeCaptureRecorder()
        let service = MicrophoneCaptureService(
            directoryRoot: root, permission: { true },
            makeRecorder: { url in
                try writeTone(url, rate: 48000, channels: 1, seconds: 0.1, amplitude: 0)
                return recorder
            })
        try await service.start(recordingID: UUID(), retainForExport: true)
        do {
            _ = try await service.stop()
            XCTFail("Silent recording must fail")
        } catch { XCTAssertEqual(error as? AudioCaptureError, .emptyRecording) }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        try await service.start(recordingID: UUID(), retainForExport: false)
        try await service.cancel()
        try await service.cancel()
        try await service.discard()
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    func testOldPollCannotStopANewRecording() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = FakeCaptureRecorder()
        let service = makeService(root: root, recorder: recorder)
        let old = UUID()
        try await service.start(recordingID: old, retainForExport: false)
        try await service.cancel()
        try await service.start(recordingID: UUID(), retainForExport: false)
        recorder.status.withLock {
            $0 = .init(isRecording: false, durationSeconds: 0, rms: 0, failure: .unavailableDevice)
        }
        await service.poll(recordingID: old)
        recorder.status.withLock {
            $0 = .init(isRecording: true, durationSeconds: 0.25, rms: 0.2, failure: nil)
        }
        _ = try await service.stop()
        try await service.discard()
    }

    func testAudioRecoveryKeepsActiveCurrentUnknownAndSymlinkSessions() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let stale = root.appendingPathComponent("stt-audio-12345-\(UUID())")
        let active = root.appendingPathComponent("stt-audio-12346-\(UUID())")
        let unknown = root.appendingPathComponent("stt-audio-12347-\(UUID())")
        for url in [stale, active, unknown] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        }
        let current = try AudioSessionDirectory.create(in: root)
        let symlink = root.appendingPathComponent("stt-audio-12348-\(UUID())")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: current)
        try AudioSessionDirectory.recover(in: root) { pid in
            switch pid {
            case 12346: true
            case 12347: nil
            default: false
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        for url in [active, unknown, current, symlink] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }

    func testRecorderStartFailureStopsRecorderAndRemovesFiles() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = FakeCaptureRecorder(startFailure: .captureFailed)
        let service = makeService(root: root, recorder: recorder)
        do {
            try await service.start(recordingID: UUID(), retainForExport: false)
            XCTFail("Expected start failure")
        } catch { XCTAssertEqual(error as? AudioCaptureError, .captureFailed) }
        XCTAssertEqual(recorder.stops.withLock { $0 }, 1)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    func testCancelledStopRemovesOwnedFiles() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = makeService(root: root, recorder: FakeCaptureRecorder())
        try await service.start(recordingID: UUID(), retainForExport: false)
        let gate = PermissionGate()
        let stop = Task {
            _ = await gate.wait()
            return try await service.stop()
        }
        await gate.waitUntilRequested()
        stop.cancel()
        await gate.resolve(true)
        do {
            _ = try await stop.value
            XCTFail("Expected cancellation")
        } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    func testCleanupFailureIsReportedAndCanBeRetried() async throws {
        let root = try makeRoot()
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: root)
        }
        let service = makeService(root: root, recorder: FakeCaptureRecorder())
        try await service.start(recordingID: UUID(), retainForExport: false)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: root.path)
        do {
            try await service.cancel()
            XCTFail("Expected cleanup failure")
        } catch { XCTAssertEqual(error as? AudioCaptureError, .cleanupFailed) }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        try await service.cancel()
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "capture-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        return root
    }

    private func makeService(root: URL, recorder: FakeCaptureRecorder) -> MicrophoneCaptureService {
        MicrophoneCaptureService(
            directoryRoot: root, permission: { true },
            makeRecorder: { url in
                try writeTone(url, rate: 48000, channels: 2, seconds: 0.25)
                return recorder
            })
    }
}

private struct FakeCaptureRecorder: CaptureRecorder {
    let systemInputName: String? = "Test input"
    let starts = OSAllocatedUnfairLock(initialState: 0)
    let status = OSAllocatedUnfairLock(
        initialState: RecorderSnapshot(
            isRecording: true, durationSeconds: 0.25, rms: 0.2, failure: nil))
    let stops = OSAllocatedUnfairLock(initialState: 0)
    let startFailure: AudioCaptureError?
    init(startFailure: AudioCaptureError? = nil) { self.startFailure = startFailure }
    func start() throws {
        starts.withLock { $0 += 1 }
        if let startFailure { throw startFailure }
    }
    func stop() { stops.withLock { $0 += 1 } }
    func snapshot() -> RecorderSnapshot { status.withLock { $0 } }
}

private actor PermissionGate {
    var waiter: CheckedContinuation<Bool, Never>?
    var requested: CheckedContinuation<Void, Never>?
    func wait() async -> Bool {
        await withCheckedContinuation { continuation in
            waiter = continuation
            requested?.resume()
            requested = nil
        }
    }
    func waitUntilRequested() async {
        if waiter != nil { return }
        await withCheckedContinuation { requested = $0 }
    }
    func resolve(_ granted: Bool) {
        waiter?.resume(returning: granted)
        waiter = nil
    }
}

private func writeTone(
    _ url: URL, rate: Double, channels: AVAudioChannelCount, seconds: Double, amplitude: Float = 0.2
) throws {
    let format = try XCTUnwrap(
        AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels))
    var settings = format.settings
    settings[AVLinearPCMIsNonInterleaved] = false
    let file = try AVAudioFile(forWriting: url, settings: settings)
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096))
    let samples = try XCTUnwrap(buffer.floatChannelData)
    let total = Int(rate * seconds)
    var position = 0
    while position < total {
        let count = min(4096, total - position)
        buffer.frameLength = AVAudioFrameCount(count)
        for channel in 0..<Int(channels) {
            for frame in 0..<count {
                samples[channel][frame] = amplitude * sin(Float(position + frame) * 0.12)
            }
        }
        try file.write(from: buffer)
        position += count
    }
}
