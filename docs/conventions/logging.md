# Define and maintain application logs

Status: required working standard. Automated enforcement is listed in [verification](../verification.md).

Keep log definitions in the [application log catalog](../log-catalog.md). Keep commands for reading logs in the [viewing guide](../logging.md). Do not copy definitions into viewing instructions.

Use Apple's `Logger` for all application logs. Do not use the `OSLog` type, `NSLog`, `NSLogv`, or the `os_log` family. The `logger_only` SwiftLint rule rejects those identifiers in code. Comments and string literals can name them. Importing the OSLog module to use `Logger` is allowed; the module and the legacy `OSLog` type are different. Choose a Logger level according to the catalog rather than choosing another API.

Add a log when an operational failure needs diagnosis, cleanup fails, or a significant event helps explain application behavior. Choose the level using the catalog. Do not log every UI action, meter poll, audio sample, or successful operation by default. A user-facing error does not always need a log; add one only when it helps diagnosis. Follow the [private-data rules](private-data.md).

When adding, changing, moving, or removing a logger or log call, update the catalog in the same commit. Each active definition must include subsystem, category, level, exact message or message template, source, trigger, expected response, and data policy. Remove obsolete definitions. Review message text, severity, recovery claims, and private data together.

The pre-commit hook runs `python3 scripts/logging_policy.py --staged` through the quick check. It scans changed Swift source under Sources with five lines of diff context. Logger construction and common log methods are text triggers. Legacy logging APIs are rejected separately by SwiftLint. Detected changes require a nonempty catalog update in the index; whitespace-only changes do not count. Partial staging is supported. A working-copy catalog edit cannot satisfy a staged requirement.

This is a conservative text check, not a Swift parser. Nearby nonlogging edits or similarly named methods can trigger it. Logging wrappers, aliases, computed methods, unusual formatting, or changes far inside long multiline calls can escape detection. Keep calls short and explicit; update detection and its tests when adopting another logging form. Review must still check completeness and meaning. Do not weaken the check to bypass a required update.

## False positives

If no logging definition changed, do not make a dummy catalog update to satisfy the gate. Keep the failing diff and diagnostic, add a focused regression test, and narrow the detector so that case passes while real logging changes still fail without a catalog update. Rerun the check and the policy tests. The gate has no per-commit override; do not bypass all hooks to work around it. Use the same regression-test approach for a false positive in the Logger-only lint rule.

Full local checks apply the same rule to current changes against HEAD and untracked source, then run gate regression tests. They do not compare catalog prose with code or validate committed catalog semantics. A clean checkout has no diff to inspect. Hooks can be bypassed; this gate is not merge enforcement.
