import XCTest

@testable import STTPractice

final class PracticeStateTests: XCTestCase {
    func testEveryStateAndEventAgainstExpectedTransitions() {
        let inactive: [PracticeState] = [.setupNeeded, .idle, .ready, .error]
        let cancellable: [PracticeState] = [.starting, .recording, .stopping, .transcribing]
        let expected: [(PracticeEvent, [(PracticeState, PracticeState)])] = [
            (.checkSetup, inactive.map { ($0, .checkingSetup) }),
            (.setupSucceeded, [(.checkingSetup, .idle)]),
            (.setupFailed, [(.checkingSetup, .setupNeeded)]),
            (.configurationChanged, [(.idle, .setupNeeded), (.error, .setupNeeded)]),
            (.record, [(.idle, .starting), (.error, .starting)]),
            (.captureStarted, [(.starting, .recording)]),
            (.stop, [(.recording, .stopping)]),
            (.audioPrepared, [(.stopping, .transcribing)]),
            (.transcriptAccepted, [(.transcribing, .ready)]),
            (.transcriptRejected, [(.transcribing, .error)]),
            (.cancel, cancellable.map { ($0, .cancelling) }),
            (.failure, (cancellable + [.cancelling]).map { ($0, .cancelling) }),
            (.cancelled, [(.cancelling, .idle)]),
            (.failureCleaned, [(.cancelling, .error)]),
            (.cleanupFailed, [(.cancelling, .setupNeeded)]),
            (.newNoteReady, inactive.map { ($0, .idle) }),
            (.newNoteNeedsSetup, inactive.map { ($0, .setupNeeded) }),
        ]
        XCTAssertEqual(expected.count, PracticeEvent.allCases.count)
        for event in PracticeEvent.allCases {
            let allowed = expected.first { $0.0 == event }?.1 ?? []
            for state in PracticeState.allCases {
                let result = allowed.first { $0.0 == state }?.1
                XCTAssertEqual(state.next(after: event), result, "\(state) + \(event)")
            }
        }
    }

    func testBusyStatesMatchOperations() {
        let busy: [PracticeState] = [
            .checkingSetup, .starting, .recording, .stopping, .transcribing, .cancelling,
        ]
        for state in PracticeState.allCases {
            XCTAssertEqual(state.isBusy, busy.contains(state), "\(state)")
        }
    }
}
