# Application log catalog

Status: definitions of current application logs. Review owns accuracy; the commit gate requires a joint catalog update, not semantic matching.

Use the [viewing guide](logging.md) to read logs and the [logging convention](conventions/logging.md) when changing them.

## Levels

| Level | Use |
|---|---|
| Debug | Details needed during development; retention is not assured |
| Info | Useful progress details; retention is not assured |
| Notice | Significant operational events that help explain application behavior |
| Warning | Unexpected conditions with a working recovery path |
| Error | An operation failed and needs diagnosis |
| Fault | A serious internal failure that needs investigation |

These are selection guidelines, not a requirement to log every operation. Only the error level is currently used by this app. The app uses Apple's unified logging system; benchmark stderr progress is a separate output.

## Recording cleanup failure

- Subsystem: `STTPOC`
- Category: `AudioCapture`
- Level: error
- Source: [AudioSessionDirectory.cleanOnDeinit](../Sources/STTAdapters/Audio/AudioSessionDirectory.swift)
- Message: `Audio session cleanup failed; abandoned-session recovery will retry after exit.`
- Trigger: removal of a temporary recording folder throws during capture-service destruction.
- Response: recovery can retry after the creator process exits. Check temporary-folder permissions if failures continue.
- Data policy: fixed text only; no audio, note, path, process ID, or raw error details.

## Transcription cleanup failure

- Subsystem: `STTPOC`
- Category: `WhisperSession`
- Level: error
- Source: [WhisperSessionRecovery.removeOwnedDirectory](../Sources/STTAdapters/Transcription/WhisperSessionRecovery.swift)
- Message: `Whisper session cleanup failed; recovery will retry after this process exits.`
- Trigger: removal of an owned temporary transcription folder throws. This can occur during normal session cleanup or destruction.
- Response: recovery can retry after the creator process exits. Check temporary-folder permissions if failures continue.
- Data policy: fixed text only; no audio, transcript, prompt, path, or engine diagnostics.

## Expected silence

Normal recording, transcription, and successful cleanup produce no application log entries. Setup and transcription failures can appear in the UI without a log entry. An empty stream is therefore not proof of a logging problem.
