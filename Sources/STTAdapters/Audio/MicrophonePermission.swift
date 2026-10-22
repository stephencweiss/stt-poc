import AVFoundation
import Foundation
import os

/// Cancellation resolves our waiter immediately; the system may still deliver its decision later.
enum MicrophonePermission {
    static func request() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: true
        case .notDetermined:
            await waitForDecision { reply in
                AVCaptureDevice.requestAccess(for: .audio, completionHandler: reply)
            }
        default: false
        }
    }

    static func waitForDecision(
        request: @Sendable (@escaping @Sendable (Bool) -> Void) -> Void
    ) async -> Bool {
        let gate = PermissionDecision()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if gate.install(continuation) { request { gate.resolve($0) } }
            }
        } onCancel: {
            gate.resolve(false)
        }
    }
}

private struct PermissionDecision: Sendable {
    private let lock = OSAllocatedUnfairLock<DecisionState>(initialState: .pending)

    func install(_ continuation: CheckedContinuation<Bool, Never>) -> Bool {
        let resolved = lock.withLock { state -> Bool? in
            if case .resolved(let result) = state { return result }
            state = .waiting(continuation)
            return nil
        }
        if let resolved {
            continuation.resume(returning: resolved)
            return false
        }
        return true
    }

    func resolve(_ result: Bool) {
        let continuation = lock.withLock { state -> CheckedContinuation<Bool, Never>? in
            if case .resolved = state { return nil }
            let waiter: CheckedContinuation<Bool, Never>?
            if case .waiting(let continuation) = state {
                waiter = continuation
            } else {
                waiter = nil
            }
            state = .resolved(result)
            return waiter
        }
        continuation?.resume(returning: result)
    }
}

private enum DecisionState: Sendable {
    case pending
    case waiting(CheckedContinuation<Bool, Never>)
    case resolved(Bool)
}
