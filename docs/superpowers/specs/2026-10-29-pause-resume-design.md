# Pause and resume recording

Status: draft for user review. This document proposes a later application slice; it does not add pause/resume to the current app.

## Goal and delivery boundary

Let the operator pause to collect their thoughts, then continue the same note. Transcribe the complete recording only after the operator finishes.

The user requested a separate design on 2026-10-29. Stack this work on the light-formatting branch (`codex/light-formatting`, base commit `f0ab3cd`). Keep PR #5 focused on its current implementation. Use `codex/pause-resume-design` for this document and the later pause/resume work in the same worktree. Do not implement the feature until the user reviews this design.

This replaces the original POC restriction against continuing an unfinished recording. It does not allow adding audio to a note after transcription.

## Approach

| Approach | Benefit | Cost or limit |
|---|---|---|
| **Pause the existing recorder — recommended** | One file, one note, one final transcription; uses the existing AVAudioRecorder | Must manage paused state, timing, resources, and resume errors |
| Close a file at each pause and join segments at Finish | Each active interval has a finalized file | Adds file ordering, conversion/joining, boundary checks, and more cleanup paths |
| Transcribe each segment and append its text | Text is available during breaks | Adds recognition boundaries, partial-result ownership, and edit-merging rules; outside this request |

Use the first approach. Apple documents `pause()` and resumption through `record()`. `stop()` closes the file. Do not create another recorder or call `prepareToRecord()` to resume: explicit preparation can overwrite the file. These are framework capabilities, not proof that our complete workflow has been tested. See [Apple pause documentation](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/pause%28%29) and [file preparation documentation](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/preparetorecord%28%29).

## Operator workflow

**Record → Pause → Resume → Pause/Resume as needed → Finish & Transcribe → edit → Copy Note**

- Add a Pause button while recording. In the paused state, it becomes Resume.
- Rename the current Stop button to **Finish & Transcribe**. Enable it while recording or paused.
- Pause stops adding samples to the recording. It does not start transcription, conversion, formatting, or export.
- Show a clear Paused status, freeze the duration, and clear the input-level meter. Do not imply that pause releases the hardware microphone or turns off the macOS microphone indicator.
- Resume continues the same recording and timer. No silence for the thinking interval should appear in the final WAV.
- Disable Record, New Note, setup changes, and the export preference while a recording is active or paused. Retain the export choice made before Record.
- Cancel discards the whole unfinished note, including audio before every pause. Quit also cleans up unfinished audio. Paused audio does not survive app exit or a crash as a recoverable draft.
- Finishing runs the existing conversion → transcription → formatting → editing workflow exactly once. Pause does not produce an editable partial note.

## States and commands

Keep audio ownership in the capture actor and observable controls in the main-actor session model. Do not use independent recording/paused Boolean flags.

| Current state | Action or event | Result |
|---|---|---|
| Idle | Record | Existing start/permission flow, then Recording |
| Recording | Pause | Pausing, then Paused after the capture actor confirms the pause |
| Paused | Resume | Resuming, then Recording after successful framework resume |
| Paused | Resume fails before recording starts | Paused with an actionable error; prior audio remains owned |
| Recording or Paused | Finish & Transcribe | Stopping, conversion, then existing Transcribing → Ready flow |
| Recording | Total audio limit reached | Finish once and use the existing processing flow |
| Starting, Pausing, Recording, Paused, Resuming, Stopping, or Transcribing | Cancel | Existing cancellation/cleanup flow, then Idle when cleanup succeeds |
| Any state with owned work | Quit | Drain/cancel work, stop the recorder, remove owned files, then exit |

Only enable Pause in Recording and Resume in Paused. Disable Finish during Pausing/Resuming; enable it after the operation resolves. Ignore duplicate or invalid commands. A paused note remains an owned session, so it must block setup checks and New Note even though the recorder reports `isRecording == false`.

Extend `AudioCaptureService` with async throwing `pause()` and `resume()` commands. Keep `stop()` as the internal finalization operation, callable from either Recording or Paused. Extend `CaptureRecorder` with corresponding synchronous operations. A successful pause must provide a final duration snapshot to the session so a queued meter event cannot leave the displayed duration short.

## Audio and time ownership

Retain the same AVAudioRecorder, CAF file, recording identity, export choice, and private session directory across pauses. Conversion starts only after final stop closes the file. Cancel, failure, quit, and abandoned-session recovery must still cover paused files.

The existing 120-second limit remains shared app policy. It applies to **total captured audio**, not elapsed time since Record and not each resumed interval. For example, 40 seconds recorded, a five-minute pause, then 30 seconds recorded yields about 70 seconds of audio and 50 seconds remaining.

- Use captured duration for the timer and limit. Remove the recorder snapshot's current wall-clock fallback for states where pause is expected; it would count thinking time as audio.
- Preserve a final active-interval duration when entering Paused. Paused wall time must not advance it.
- Resume must retain the remaining allowance. It must not grant another 120 seconds.
- Keep a native recorder duration stop and the cumulative capture-actor limit guard. Verify how `record(forDuration:)` behaves across resume before choosing the exact adapter calls; do not assume whether its argument is cumulative or remaining time. If necessary, isolate duration control in the recorder adapter. Do not silently remove the existing native stop or relax converter bounds to make tests pass.
- At or above the total limit, do not resume. Finalize the existing recording once. Handle a pause/limit race by rechecking total duration on the capture actor.
- Do not impose a separate thinking-time limit in this slice. No wake lock or automatic resume is added. After sleep while paused, Resume must perform the same input and recorder checks as any other resume.

The native duration behavior is an implementation gate: run an explicit framework check on the target Mac before completing the adapter. Ordinary tests cannot establish AVAudioRecorder's real pause, resume, or duration semantics.

## Microphone changes and errors

The current recorder uses the macOS default input. Its UI name is a setup-time snapshot. A matching name alone is not sufficient to establish device identity.

For this slice, require the same input on resume. Extend the adapter's read-only system-input metadata to include a stable device UID and the relevant input format. Store these at initial setup and validate them before resuming. Keep this metadata inside STTAdapters; do not add an application device selector or change system settings.

- If the original input is absent, the default has changed, the format has changed, or identity cannot be verified, reject Resume and remain Paused. Ask the operator to restore the original input or finish the existing note. Do not erase prior audio or silently switch sources.
- Refresh the displayed input name after a successful resume. Treat it as metadata, not proof of the source of every frame.
- If AVAudioRecorder rejects resume before adding samples, remain Paused when the existing file is still valid. The session must handle this recoverable error without its current generic failure path, which cancels and deletes capture files.
- Finish from Paused must be possible even when the original microphone is disconnected. It finalizes already captured audio; it must not require a live input device.
- A write failure or an uncertain recorder/file state is a fatal capture error. Use explicit failure and cleanup rather than presenting incomplete audio as a successful note. Recovering damaged recordings is separate work.
- Zero-length or near-silent finalized audio keeps the existing typed error. Recognition markers keep the current warning behavior.

This does not add complete route monitoring during active recording. Existing device-removal behavior still requires manual verification. No assumption is made that a device can resume across every wireless disconnect or OS interruption.

## Concurrency and cleanup

Serialize recorder commands on the capture actor. Retain pause/resume tasks in the session model, with the existing cancellation and revision rules. Check identity/revision after each await before changing controls.

Recording identity stays the same across pauses. Add an active-interval generation to monitoring and its telemetry so a queued level or device event from before Pause cannot affect a later resumed interval. The capture actor remains the authority for cumulative duration and limit completion. Persistent recorder errors must still be checked at command boundaries; discarding stale telemetry must not hide a real write error.

Stop or suspend meter polling while paused. A paused recorder's `isRecording == false` is expected and must not enter the current unexpected-stop failure path. On resume, start one monitor for the new interval. Reject stale monitor callbacks after pause, resume, cancellation, or a new note.

Keep paused files under their existing owner. Include the paused case in state-derived `directory` and `recorder` accessors, cancellation, deinit, quit, and recovery. A failed deletion retains ownership for retry as it does now. No new detached tasks, audio callbacks, buffer queues, model calls, or persistent storage are needed.

## Files and responsibilities

| Path | Proposed change |
|---|---|
| `Sources/STTCore/Audio/AudioCapture.swift` | Pause/resume service contract, confirmed capture status, and interval-aware events/errors |
| `Sources/STTAdapters/Audio/FrameworkAudioRecorder.swift` | Framework pause/resume, captured-time snapshots, and tested remaining-duration behavior |
| `Sources/STTAdapters/Audio/SystemAudioInput.swift` | Read-only device UID/name/format metadata for resume validation |
| `Sources/STTAdapters/Audio/MicrophoneCaptureService.swift` | Paused ownership, serialized commands, interval monitoring, recoverable resume failures, finalization from Paused |
| `Sources/STTPractice/SessionModel.swift` | Pausing/Paused/Resuming states, actions, duration updates, recovery messages, and command guards |
| `Sources/STTPractice/ContentView.swift` | Pause/Resume and Finish & Transcribe controls, paused status, and meter/timer display |
| `Tests/STTAdaptersTests/AudioCaptureTests.swift` | Actor transitions, ownership, duration, device validation, and failure regressions with fake boundaries |
| `Tests/STTPracticeTests/SessionModelTests.swift` | Control states, ordering, stale events/results, cancellation, final transcription, copy/export preservation |
| `README.md`, `docs/practice-checklist.md`, `docs/verification.md`, `docs/agent/feature_map.json` | Update actual workflow and evidence when implementation is complete |

Keep transcription engines, formatting rules, prompts, benchmark scoring, and fixture references unchanged. The converter should still accept one finalized WAV; it does not need a segment-joining feature.

## Validation and delivery outline

Use one focused pause/resume implementation PR stacked on the formatting work. The design can be reviewed first in draft form. Retarget and rerun checks when its base changes. No implementation or completed live check is claimed by this design.

1. Verify the native recorder's pause/resume and duration semantics with an explicit target-Mac check using fictional speech. Check distinct speech before and after two pauses, a long thinking interval, and a short test limit. Record actual results before relying on API timing assumptions.
2. Write failing adapter tests, then implement paused ownership and commands. Cover duplicate Pause/Resume, Finish from Paused, stale interval callbacks, unchanged file ownership, resume rejection, cancellation, and cleanup. Use fake clocks/devices/recorders for ordinary tests.
3. Write failing session tests, then connect the controls. Prove no transcription occurs at Pause, one full transcription occurs at Finish, and late commands/results cannot replace a newer note.
4. Verify capture duration across multiple intervals, a long pause, limit races, and rejection of resume with no time left. Prove recorded time does not reset and wall time does not consume the allowance.
5. Verify input change/disconnection while paused, successful recovery after restoring the input, rejected framework resume, Finish without the input, and fatal write errors. Test cancellation while resume is pending and quit from Paused.
6. Run `./scripts/format.sh` and `./scripts/check.sh`. Request hosted checks for the final PR head/base. Ordinary CI must not require a microphone or model.
7. Run the full live workflow offline. Export one opt-in sample and listen across pause boundaries for missing endings, duplicated speech, or inserted thinking-time silence. Check input labels, the combined duration, and the final transcript. Include one maximum-duration trial, quit while paused, and paused sleep/wake recovery. Audit text against audio; successful app control tests do not prove recognition accuracy.
8. Update the workflow documentation and verification evidence with results actually observed. Keep unresolved hardware failures visible. Obtain user trial feedback before marking the feature ready.

## Acceptance and exclusions

Accept when the operator can pause and resume the same unfinished note multiple times, paused time adds no audio, the total limit remains enforced, Finish transcribes the full recording once, and ownership/cancellation rules pass. Existing raw-text preservation, formatting, editing, copy, and optional export behavior must remain intact.

Excluded: resuming after Finish/transcription, editing partial transcripts, streaming recognition, automatic silence detection, joining separate recordings, changing input devices within a note, long-session support, saved drafts, and recovery after app exit. These need separate designs if requested.
