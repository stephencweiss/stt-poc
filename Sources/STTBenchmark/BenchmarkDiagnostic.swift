import Foundation
import STTAdapters
import STTCore

/// Keeps decoder payloads and private transcript contents out of command diagnostics.
enum BenchmarkDiagnostic {
    static func message(_ error: any Error) -> String {
        if error is CancellationError { return "Cancelled; the child process has been stopped." }
        if let engine = error as? WhisperCppTranscriberError { return engineMessage(engine) }
        if error is OptionError {
            return "Use valid options and a fresh report path outside the fixture directory."
        }
        if error is ManifestError {
            return
                "Fixture validation failed. Check schema, paths, checksums, inventory, and audio format."
        }
        if error is DecodingError {
            return "The fixture manifest does not match the required schema."
        }
        return
            "A required file could not be read or the report could not be written. Check the supplied paths and permissions."
    }

    private static func engineMessage(_ error: WhisperCppTranscriberError) -> String {
        switch error {
        case .invalidExecutable:
            return "The executable is missing or cannot run. Check --executable."
        case .invalidModel: return "The model is missing, empty, or unreadable. Check --model."
        case .invalidAudio: return "Audio must be a complete 16 kHz mono PCM16 WAV."
        case .invalidTimeout: return "The timeout must be finite and positive."
        case .sessionUnavailable, .launchFailed:
            return "Could not create a private session or launch whisper.cpp."
        case .processFailed(let code):
            return "whisper.cpp exited with status \(code). Verify the model and input audio."
        case .timedOut: return "Transcription exceeded its timeout; the child process was stopped."
        case .invalidOutput: return "whisper.cpp did not produce valid bounded transcript JSON."
        }
    }
}
