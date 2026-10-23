import AppKit

/// Delay quit until capture and inference release their files and child process.
@MainActor
final class PracticeAppDelegate: NSObject, NSApplicationDelegate {
    weak var session: SessionModel?
    private var termination: Task<Void, Never>?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard termination == nil else { return .terminateLater }
        guard let session else { return .terminateNow }
        termination = Task {
            await session.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
