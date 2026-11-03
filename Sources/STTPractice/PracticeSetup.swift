import Foundation
import STTAdapters

actor PracticeSetup {
    enum SetupError: Error { case invalidFiles }
    private let recover: @Sendable () throws -> Void

    init(
        recover: @escaping @Sendable () throws -> Void = {
            try WhisperSessionRecovery.removeAbandoned()
            try MicrophoneCaptureService.recoverAbandonedSessions()
        }
    ) { self.recover = recover }

    func check(_ configuration: PracticeConfiguration) throws {
        try recover()
        let files = FileManager.default
        let model = URL(fileURLWithPath: configuration.modelPath)
        guard files.isExecutableFile(atPath: configuration.executablePath),
            files.isReadableFile(atPath: model.path),
            let size = try model.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 15
        else { throw SetupError.invalidFiles }
    }
}
