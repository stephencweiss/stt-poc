# Own concurrent work and resources

Status: required working standard. Automated enforcement is listed in [verification](../verification.md).

Use @MainActor for observable UI/session state. Keep blocking I/O, process waits, inference, and expensive scoring off it. An async function does not by itself move work off the main actor.

Use Sendable snapshots across isolation boundaries. A struct containing mutable references is not necessarily an independent snapshot. Do not use unchecked Sendable, nonisolated(unsafe), or preconcurrency as blanket fixes; a narrow bridge needs a documented ownership argument and review.

Retain and cancel tasks. Use session/source revisions so late results cannot replace later edits. Avoid untracked detached tasks. Initially serialize conflicting model work and measure before adding concurrency.

Each engine, converter, process, and temporary directory has one owner and explicit cleanup. Test repeated start/stop, failures, and cancellation. Drain process outputs concurrently and terminate/reap cancelled processes. Diagnostics are never transcript text.

Audio callbacks must not run models, perform disk/network work, allocate large buffers, or block on tasks/locks. Use a bounded handoff and report overflow. Manual and automated verification have different limits; see the verification guide.
