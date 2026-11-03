import Foundation

public struct CapturedAudio: Sendable {
    public let audioURL: URL
    public let durationSeconds: Double
    public let exportWAV: Data?

    public init(audioURL: URL, durationSeconds: Double, exportWAV: Data? = nil) {
        self.audioURL = audioURL
        self.durationSeconds = durationSeconds
        self.exportWAV = exportWAV
    }
}

public enum AudioCaptureEvent: Sendable {
    case level(recordingID: UUID, rms: Float, durationSeconds: Double)
    case limitReached(recordingID: UUID)
    case failed(recordingID: UUID, error: AudioCaptureError)
}

public enum AudioCaptureError: Error, Sendable, Equatable {
    case permissionDenied
    case unavailableDevice
    case alreadyRecording
    case noRecording
    case emptyRecording
    case captureFailed
    case conversionFailed
    case writeFailed
    case cleanupFailed
}

/// Owns recording files until discard or cancel. Only the session model consumes its event stream.
public protocol AudioCaptureService: Sendable {
    var events: AsyncStream<AudioCaptureEvent> { get }
    func start(recordingID: UUID, retainForExport: Bool) async throws
    func stop() async throws -> CapturedAudio
    func cancel() async throws
    func discard() async throws
}
