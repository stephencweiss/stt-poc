# Usable Dictation App Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans. Check each step after its verification passes.

**Goal:** Deliver Record → Stop → Transcribe → Edit → Copy on this Mac, using the installed whisper.cpp engine.

**Architecture:** STTCore defines capture snapshots and service contracts. STTAdapters owns audio capture, conversion, and temporary files. The app owns pasteboard access. A main-actor session model owns app state and tasks; SwiftUI renders controls and note views. Keep raw text separate from edited text. Keep the benchmark unchanged.

**Tech stack:** Swift 6, SwiftUI/AppKit, AVFoundation, XCTest; no new dependency or model download.

## Accepted scope and sequence

The user chose the usable practice app first on 2026-10-22. This replaces the earlier comparison-before-UI gate. WhisperKit comparison/migration remains deferred until after the first practice trial and tracked in docs/TODO.md. Existing recognition failures remain documented; this app is for fictional local practice.

Use the existing medium.en model and general cardiology vocabulary prompt. No formatting, inferred structure, local language model, hotkey, floating panel, automatic copy, or history in this PR. Manual copy must use the current edited text. A new recording requires an explicit New Note action after a completed note.

## 1. Capture and conversion

**Files:** `Sources/STTCore/Audio/AudioCapture.swift`, `Sources/STTAdapters/Audio/`, `Tests/STTAdaptersTests/AudioCaptureTests.swift`.

- [x] Define Sendable captured-audio and event types plus an async capture service protocol.
- [x] Assign a recording UUID at start and include it on every event. Both adapter and session model reject stale events after cancel/New Note.
- [x] Write failing tests for canonical conversion from 44.1/48 kHz stereo, duration/end flushing, invalid/empty input, propagated write errors, and owned-file cleanup.
- [x] Request microphone permission. Capture with Apple frameworks; do no disk writes, inference, large allocations, or blocking locks in application audio callbacks. Use a persistent converter when explicit conversion is needed.
- [x] Bound capture to 120 seconds; stop and retain the complete captured audio. Send level/duration and limit/error events. Reject empty/near-silent input without claiming speech detection.
- [x] Test device and recorder failures: stop capture, report a typed error, and remove owned files. Use AVAudioRecorder with framework-managed capture; no application buffer queue exists to overflow.
- [x] Own private session files outside Git. Delete after processing/cancel/error/quit and recover only verified abandoned sessions at launch. Support repeated start/stop/cancel without stale callbacks affecting a new recording.
- [x] Keep optional sample export explicit: `start(retainForExport:)` decides whether `CapturedAudio` also contains bounded in-memory WAV data. Default false; files are still deleted after transcription.
- [x] Run focused audio tests without hardware or models. Keep live microphone checks manual.

## 2. Session state and copy

**Files:** `Sources/STTPractice/SessionModel.swift`, `Sources/STTPractice/Clipboard.swift`, `Sources/STTPractice/PracticeSetup.swift`, `Tests/STTPracticeTests/`, `Package.swift`.

- [x] Write failing state tests with fake capture, setup, transcription, and clipboard services.
- [x] Track setup-needed, idle, starting, recording, stopping, transcribing, cancelling, ready, and error states. Keep status messages distinct from note content.
- [x] Retain/cancel tasks and invalidate stale work by generation. Test duplicate Stop, failure, cancellation before startup completes, late results, duration-limit events, New Note, and retry.
- [x] Preserve raw text, editable text, timing, and the selected configuration snapshot. Use the installed prompt-on configuration; show errors without putting diagnostics in notes.
- [x] Copy only nonempty current edited text. Report success only after a successful pasteboard write; show edits made since the last copy. Use a fake pasteboard in ordinary tests.
- [x] Snapshot optional export bytes before recording files are discarded. Export a WAV and current corrected text only through an explicit user-selected local destination; never promote a sample into Git fixtures automatically.
- [x] Run session tests without microphone, model, or system clipboard access.

## 3. UI and lifecycle

**Files:** `Sources/STTPractice/App.swift`, `ContentView.swift`, `PracticeAppDelegate.swift`, `SampleExport.swift`.

- [x] Replace the setup shell with real controls, a visible recording limit/duration/level, raw text, editable output, timing, and status/error messages.
- [x] Keep Record disabled until setup succeeds. Disable conflicting actions while work is active. Make permission-denial recovery clear.
- [x] Require New Note before another recording can replace a completed note. Keep accepted user edits intact after copy/export failures.
- [x] On quit, cancel and drain owned work, clean up audio files, and reap the CLI process before allowing termination. Do not leave an untracked background task as the shutdown strategy.
- [x] Build, sign, and launch through the existing scripts.

## 4. Review and evidence

**Files:** `README.md`, `docs/verification.md`, `docs/practice-checklist.md`, `docs/agent/feature_map.json`, existing plan/TODO sequence notes.

- [x] Review scope, resource ownership, state transitions, and tests; fix material findings.
- [x] Run `./scripts/check.sh` and confirm all compiler/test/lint/package checks pass.
- [x] Run available local smoke checks. Distinguish synthetic audio/fixture integration from a real microphone/clipboard UI trial; never claim the latter from fake tests.
- [x] Document launch, permissions, errors, temporary-file handling, export, and known recognition failures. Provide a short manual trial checklist.
- [ ] Commit and open the next application PR, attach it to this task, and run fresh hosted checks. Do not merge it.

Live microphone, physical device removal, offline dictation, and cross-app paste remain pending in docs/practice-checklist.md. The launch smoke check confirms the signed app starts; it does not establish those manual results.
