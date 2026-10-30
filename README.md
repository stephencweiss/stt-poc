# STT POC

A local macOS practice app for free-form cardiology dictation, editing, copying, and an optional local Clean Up Transform. The app records from the microphone, transcribes locally, and lets you edit and copy a note. A file benchmark provides fixed regression inputs. Formatting and Clean Up remain later application PRs.

Read the [document guide](docs/README.md) for accepted scope, plans, and verification status.

## Development

Apple Silicon macOS, Xcode 26.2 / Swift 6.2.3, and Python 3.11+ are required. Exact tool versions and verified archive checksums are in tooling.json. No Node runtime or paid service is required for the foundation.

```sh
./scripts/setup-dev.sh --install-tools
./scripts/setup-dev.sh --hooks
./scripts/check.sh
```

Setup downloads only missing/mismatched tools into ignored .tools; it does not download speech/language models. Use ./scripts/setup-dev.sh to verify an existing setup, ./scripts/check.sh --quick for fast checks, and ./scripts/format.sh for explicit Swift formatting. Checks do not stage files. Run the app with `./scripts/run-local.sh`. The window checks local file paths; model loading occurs when transcription starts. Custom app paths do not change benchmark CLI options.

## Local dictation

```sh
./scripts/run-local.sh
```

Use **Record → Stop → edit → Copy Note**. Allow microphone access when macOS asks. If access is denied, allow STT Practice under System Settings → Privacy & Security → Microphone, then retry. Open **Local setup** to change the executable or model path and select **Check setup**.

Each recording stops at 120 seconds and processes the full captured audio. This short-note policy comes from `RecordingConfiguration.maximumDurationSeconds` in [the shared recording configuration](Sources/STTCore/Audio/RecordingConfiguration.swift); it is not a Whisper model limit. Increasing it does not add long-session support: transcription still starts after Stop, has a 180-second processing timeout, and has no saved partial transcript. **Cancel** stops work and removes temporary recording files. **New Note** clears the current note. Raw text remains available for comparison; edits do not change it. Copy uses the current edited text. The app marks the clipboard as stale after another edit.

Use fictional practice cases. Notes remain in memory and are lost at quit. Audio files are removed after processing, cancel, or failure; abandoned sessions are checked at launch. Deletion is not secure erase. No network service or model download is used. The vocabulary prompt is on, based on the measured baseline; recognition still has known value and drug-name errors.

The current recording stays in memory for optional export after transcription. **Export practice sample…** writes a new directory containing audio.wav and reference.txt (the current edited note). New Note, cancel, or quit releases the session audio; recordings do not survive an app restart. An export already selected keeps its snapshot until that export completes. Temporary recording files are still deleted after processing. Review the reference against the audio before treating it as a regression input. Files are saved only when you export. The app does not add samples to Git. See the [retention decision](docs/decisions/2026-10-29-current-recording-export.md).

See the [manual practice checklist](docs/practice-checklist.md) for device, permission, copy, offline, and cleanup checks. Ordinary tests use fake capture and clipboard boundaries; they do not prove microphone quality or cross-app paste behavior.

## Local benchmark

```sh
swift run STTBenchmark --report .local/baseline.json
```

This runs 15 fixed cases with the vocabulary prompt both off and on (30 local inferences). Progress appears immediately on stderr as `Progress: 0/30 inferences complete.` and advances after each successful inference. The total includes prompt modes and repetitions. Wait for `Completed 30 inferences. Report: …` before reading the JSON; cancelling or failing a run does not write a partial report. Every call launches whisper.cpp and loads the model; total wait can be several minutes. No model download or network service is used. Reports include fictional fixture text; do not publish reports made from private recordings.

Defaults are /opt/homebrew/bin/whisper-cli and /opt/homebrew/share/whisper-cpp/ggml-medium.en.bin. Override them with `--executable PATH` and `--model PATH`. Use `--manifest PATH`, `--prompt off|on|both`, and `--repetitions 1...10` as needed. Run `swift run STTBenchmark --help` for usage. Use a fresh report filename; existing reports and the fixture directory are protected from accidental overwrite. Invalid setup or any failed case returns a nonzero exit instead of skipping a case.

Read [fixture provenance and scoring](Fixtures/Benchmark/README.md) before changing the suite. Read the [measured baseline and failures](docs/benchmarks/2026-10-22-whisper-cpp-medium-en.md). Real-model evaluations run locally; CI builds, tests, checks fixture integrity, and packages the app without a model or microphone.

## Conventions

- [Maintain conventions and indexes](docs/conventions/writing-conventions.md)
- [Keep clear targets and reuse boundaries](docs/conventions/structure-and-reuse.md)
- [Use clear Swift contracts and errors](docs/conventions/swift-and-interfaces.md)
- [Own concurrent work and resources](docs/conventions/concurrency-and-resources.md)
- [Test behavior and version regression inputs](docs/conventions/testing-and-fixtures.md)
- [Verify model and prompt changes](docs/conventions/model-changes.md)
- [Run pinned local and hosted checks](docs/conventions/quality-checks.md)
- [Keep private data out of Git and logs](docs/conventions/private-data.md)
- [Define and maintain application logs](docs/conventions/logging.md)

## CI

[Verification](docs/verification.md) owns check status and manual CI instructions. CI runs when a PR becomes ready for review, or by manual request; new commits and base changes require a fresh run. Local hooks and passing old checks do not block unsafe merges.
