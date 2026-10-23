import AVFoundation
import Foundation
import STTCore
import os

struct RecorderSnapshot: Sendable {
    let isRecording: Bool
    let durationSeconds: Double
    let rms: Float
    let failure: AudioCaptureError?
}

/// Synchronous calls stay on the capture actor. AVFoundation owns realtime callbacks and file writes.
protocol CaptureRecorder: Sendable {
    func start() throws
    func stop()
    func snapshot() -> RecorderSnapshot
}

struct FrameworkAudioRecorder: CaptureRecorder {
    private let recorder: AVAudioRecorder
    private let delegate: RecorderDelegate
    private let deviceID: String
    private let started = ContinuousClock.now

    init(url: URL) throws {
        guard let device = AVCaptureDevice.default(for: .audio), device.isConnected else {
            throw AudioCaptureError.unavailableDevice
        }
        deviceID = device.uniqueID
        delegate = RecorderDelegate()
        let sampleRate =
            CMAudioFormatDescriptionGetStreamBasicDescription(
                device.activeFormat.formatDescription)?.pointee.mSampleRate ?? 48000
        guard sampleRate.isFinite, sampleRate > 0 else { throw AudioCaptureError.unavailableDevice }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
        ]
        do { recorder = try AVAudioRecorder(url: url, settings: settings) } catch {
            throw AudioCaptureError.writeFailed
        }
        recorder.delegate = delegate
        recorder.isMeteringEnabled = true
    }

    func start() throws {
        guard AVCaptureDevice(uniqueID: deviceID)?.isConnected == true else {
            throw AudioCaptureError.unavailableDevice
        }
        guard recorder.prepareToRecord(),
            recorder.record(forDuration: RecordingConfiguration.maximumDurationSeconds)
        else {
            throw AudioCaptureError.captureFailed
        }
    }

    func stop() { recorder.stop() }

    func snapshot() -> RecorderSnapshot {
        recorder.updateMeters()
        let duration = started.duration(to: .now).components
        let elapsed = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        let failure =
            AVCaptureDevice(uniqueID: deviceID)?.isConnected == true
            ? delegate.failure.withLock { $0 } : .unavailableDevice
        return RecorderSnapshot(
            isRecording: recorder.isRecording,
            durationSeconds: recorder.isRecording ? recorder.currentTime : elapsed,
            rms: pow(10, recorder.averagePower(forChannel: 0) / 20), failure: failure)
    }

}

/// The callback bridge stores only an immutable lock with a typed error, never audio or diagnostics.
private final class RecorderDelegate: NSObject, AVAudioRecorderDelegate, Sendable {
    let failure = OSAllocatedUnfairLock<AudioCaptureError?>(initialState: nil)

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        failure.withLock { $0 = .writeFailed }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag { failure.withLock { $0 = .captureFailed } }
    }
}
