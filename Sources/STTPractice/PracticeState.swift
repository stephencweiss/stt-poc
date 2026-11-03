/// Events describe why a session can change state. Effects remain in SessionModel.
enum PracticeEvent: CaseIterable {
    case checkSetup, setupSucceeded, setupFailed, configurationChanged, record, captureStarted,
        stop, audioPrepared, transcriptAccepted, transcriptRejected, cancel, failure,
        cancelled, failureCleaned, cleanupFailed, newNoteReady, newNoteNeedsSetup
}

/// Owns allowed state transitions. A rejected event returns nil and must not start effects.
enum PracticeState: Equatable, CaseIterable {
    case setupNeeded, checkingSetup, idle, starting, recording, stopping, transcribing, cancelling,
        ready, error

    var isBusy: Bool {
        switch self {
        case .checkingSetup, .starting, .recording, .stopping, .transcribing, .cancelling: true
        default: false
        }
    }

    func next(after event: PracticeEvent) -> PracticeState? {
        operationTransitions[event]
    }

    private var operationTransitions: [PracticeEvent: PracticeState] {
        switch self {
        case .setupNeeded, .ready:
            [
                .checkSetup: .checkingSetup,
                .newNoteReady: .idle,
                .newNoteNeedsSetup: .setupNeeded,
            ]
        case .idle, .error:
            [
                .checkSetup: .checkingSetup,
                .newNoteReady: .idle,
                .newNoteNeedsSetup: .setupNeeded,
                .record: .starting,
                .configurationChanged: .setupNeeded,
            ]
        case .checkingSetup:
            [
                .setupSucceeded: .idle,
                .setupFailed: .setupNeeded,
            ]
        case .starting: withCleanup([.captureStarted: .recording])
        case .recording: withCleanup([.stop: .stopping])
        case .stopping: withCleanup([.audioPrepared: .transcribing])
        case .transcribing:
            withCleanup([
                .transcriptAccepted: .ready,
                .transcriptRejected: .error,
            ])
        case .cancelling:
            [
                .failure: .cancelling,
                .cancelled: .idle,
                .failureCleaned: .error,
                .cleanupFailed: .setupNeeded,
            ]
        }
    }

    private func withCleanup(_ progress: [PracticeEvent: PracticeState]) -> [PracticeEvent:
        PracticeState]
    {
        progress.merging([.cancel: .cancelling, .failure: .cancelling]) { _, cleanup in cleanup }
    }
}
