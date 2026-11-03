# Define and maintain application logs

Status: required working standard. Automated enforcement is listed in [verification](../verification.md).

Keep log definitions in the [application log catalog](../log-catalog.md). Keep commands for reading logs in the [viewing guide](../logging.md). Do not copy definitions into viewing instructions.

Use Apple's `Logger` for all application logs. Do not use the `OSLog` type, `NSLog`, `NSLogv`, or the `os_log` family. The `logger_only` SwiftLint rule rejects those identifiers in code. Comments and string literals can name them. Importing the OSLog module to use `Logger` is allowed; the module and the legacy `OSLog` type are different. Choose a Logger level according to the catalog rather than choosing another API.

Add a log when an operational failure needs diagnosis, cleanup fails, or a significant event helps explain application behavior. Choose the level using the catalog. Do not log every UI action, meter poll, audio sample, or successful operation by default. A user-facing error does not always need a log; add one only when it helps diagnosis. Follow the [private-data rules](private-data.md).

When adding, changing, moving, or removing a logger or log call, update the catalog in the same commit. Each active definition must include event ID, subsystem, category, level, exact message or message template, field names/types/permitted values, source, trigger, expected response, and data policy. Remove obsolete definitions. Review message text, severity, recovery claims, and private data together.

## Event format

Use a stable event ID and explicit fields rather than prose that consumers must interpret. The message format is `event=<id> key=value`, with one ASCII space between fields and no leading or trailing whitespace. Put event first. Keys use lower snake case (`[a-z][a-z0-9_]*`); string values are nonempty tokens (`[a-z0-9_][a-z0-9_.-]*`). Do not repeat keys. This format has no quoting or escaping; values cannot contain spaces, equals signs, or line breaks. Keep human explanations in the catalog.

Event IDs use a domain and an event name, such as `audio.cleanup_failed`. Keep the ID stable when human explanations change. If an event's meaning or field contract changes incompatibly, use a new event ID. Do not silently reuse an existing ID for a different event.

Define each field's type and allowed values in the catalog. Add fields only when they help diagnosis. If correlation is needed, use an opaque operation ID with a documented lifetime and data policy. Define numeric measurements with explicit units in their keys, such as duration_ms, and specify their numeric representation and range before use. Do not insert private paths, notes, audio, prompts, or raw error descriptions.

The current cleanup events use only fixed string tokens: event identifies the failure and recovery identifies the recovery policy. `recovery=retry_after_exit` means a later recovery attempt is allowed after the creator process exits; it does not promise an immediate retry or successful removal.

Logger already supplies time, process, subsystem, category, and level metadata. Do not repeat those fields in the message. In JSON/NDJSON exports, these application fields remain in the eventMessage string; they are not separate JSON properties. The catalog gate still checks joint edits only, not message grammar or schema semantics.

The pre-commit hook runs `python3 scripts/logging_policy.py --staged` through the quick check. It scans changed Swift source under Sources with five lines of diff context. Logger construction and common log methods are text triggers. Legacy logging APIs are rejected separately by SwiftLint. Detected changes require a nonempty catalog update in the index; whitespace-only changes do not count. Partial staging is supported. A working-copy catalog edit cannot satisfy a staged requirement.

This is a conservative text check, not a Swift parser. Nearby nonlogging edits or similarly named methods can trigger it. Logging wrappers, aliases, computed methods, unusual formatting, or changes far inside long multiline calls can escape detection. Keep calls short and explicit; update detection and its tests when adopting another logging form. Review must still check completeness and meaning. Do not weaken the check to bypass a required update.

## False positives

If no logging definition changed, do not make a dummy catalog update to satisfy the gate. Keep the failing diff and diagnostic, add a focused regression test, and narrow the detector so that case passes while real logging changes still fail without a catalog update. Rerun the check and the policy tests. The gate has no per-commit override; do not bypass all hooks to work around it. Use the same regression-test approach for a false positive in the Logger-only lint rule.

Full local checks apply the same rule to current changes against HEAD and untracked source, then run gate regression tests. They do not compare catalog prose with code or validate committed catalog semantics. A clean checkout has no diff to inspect. Hooks can be bypassed; this gate is not merge enforcement.
