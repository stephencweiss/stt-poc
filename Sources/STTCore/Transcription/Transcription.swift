import Foundation

public struct TranscriptionRequest: Sendable {
    public let audioURL: URL
    public let prompt: String?

    public init(audioURL: URL, prompt: String? = nil) {
        self.audioURL = audioURL
        self.prompt = prompt
    }
}

public struct TranscriptSegment: Codable, Sendable, Equatable {
    public let text: String
    public let startSeconds: Double
    public let endSeconds: Double

    public init(text: String, startSeconds: Double, endSeconds: Double) {
        self.text = text
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
    }
}

public struct TranscriptionResult: Sendable {
    public let text: String
    public let segments: [TranscriptSegment]
    public let elapsedSeconds: Double
    public let modelID: String

    public init(
        text: String, segments: [TranscriptSegment], elapsedSeconds: Double, modelID: String
    ) {
        self.text = text
        self.segments = segments
        self.elapsedSeconds = elapsedSeconds
        self.modelID = modelID
    }
}

public protocol TranscriberService: Sendable {
    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult
}
