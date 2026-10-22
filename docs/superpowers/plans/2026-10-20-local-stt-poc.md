# Local Medical STT POC Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` to implement this plan task by task. Steps use checkboxes for tracking. Resolve the proposed scope changes with the user before implementation.

**Goal:** Run a local Mac app that accepts free-form general cardiology dictation, produces readable text with light formatting, and lets the user edit and copy each note.

**Architecture:** One Swift package with a core library, an adapter library, a benchmark command, and a SwiftUI macOS executable packaged as a local `.app`. Audio goes through a replaceable transcriber and a deterministic formatter. A separate local language model provides user-selected post-transcription Transforms. No hosted service or database is required; the proposed model runner uses a loopback-only local service.

**Tech Stack:** Swift 6, SwiftUI/AppKit, AVFoundation, XCTest; proposed initial engine: the installed `whisper-cli` with `medium.en`.

**Status:** Planning and engineering foundation are merged. Application PR 1 implements the local file-transcription baseline. Detailed evidence is in `docs/verification.md`; microphone recording starts in application PR 2.

## 1. Basis and decisions

The source is `medical_stt_procedure_log_mvp_specification.md`. Treat its code as examples, not tested implementation. Keep that source unchanged.

Local checks on 2026-10-20 found:

- Apple M3 Pro, 36 GB RAM; Swift 6.2.3 and Xcode are installed.
- `ffmpeg` and `/opt/homebrew/bin/whisper-cli` are installed.
- `/opt/homebrew/share/whisper-cpp/ggml-medium.en.bin` exists and is about 1.4 GB. It still needs a successful inference test.
- The file named `ggml-large-v3.bin` is only 15 bytes. Do not treat it as a usable model.
- Pulse Log has 12 `.m4a` recordings with reference text, plus audio, transcription, parser, and benchmark code.
- Its earlier report favored `medium.en`. Those results are historical and cover mixed cardiology procedures; they do not establish performance for this app.

### Options

| Option | Benefit | Cost or limit |
|---|---|---|
| **A. Reuse whisper.cpp first — recommended** | Existing tool and model; fastest route to local practice | Changes the PRD engine; a new process loads the model for each note |
| B. Start with WhisperKit | Matches the PRD; supports an in-process engine | Needs Swift package setup, separate Core ML models and tokenizer assets, and first-load testing |
| C. Add the new flow to Pulse Log | Existing UI and services | Brings database, security, and domain dependencies into a much smaller POC |

Use A for the first working loop, subject to user review. Keep a transcriber protocol so B remains possible. Do not build both engines in the first pass. If A has unacceptable latency or accuracy, stop and compare one WhisperKit model before further UI work.

### Scope changes from the PRD

1. **Confirmed:** Support general cardiology logs with a general note editor. Start tests with diagnostic catheterization, PCI, and TAVR. Do not require procedure-specific fields or classify procedures automatically.
2. **Confirmed:** Accept free-form dictation and preserve spoken order. Support explicit spoken headings without requiring them. Do not infer sections, extract fields, summarize, or add clinical facts.
3. **Confirmed:** Use a local language model for the **Clean Up** Transform only. Remove filler and improve punctuation and grammar while preserving meaning, order, explicit headings, meaningful repetition, and uncertainty. Do not guess how to resolve ambiguous false starts or corrections.
4. **Proposed:** Start with the installed whisper.cpp tools and record-then-transcribe, without live partial text.
5. **Proposed:** Defer separate Silero VAD integration until silence and noise tests show it is needed. Check for empty or near-silent audio, but do not treat an energy check as speech detection.
6. **Proposed:** Deliver the basic practice loop before the floating panel and global hotkey.
7. **Proposed:** Replace the claim of “zero hallucinations” with a tested requirement that formatting preserves clinical facts. Speech recognition and model Transforms can still introduce errors.
8. **Proposed:** Limit the first pass to English.

## 2. First practice workflow

Open the app → Record → Stop → wait for transcription → inspect and edit text → optionally run a Transform → compare and accept or discard → Copy Note → paste into a local text editor.

- No streaming, patient records, history, accounts, analytics, billing, cloud services, or EHR connection.
- Transforms use a local language model. Keep the raw transcript unchanged and create a separate candidate from a snapshot of the current editable note. Accept replaces the editable note; discard leaves it unchanged. Preserve an undo copy. A failed, cancelled, or stale Transform cannot overwrite text or trigger automatic copy.
- The Transform prompt must preserve clinical facts, values, units, side, negation, and uncertainty. Model compliance is measured, not guaranteed. Treat note content as input data, not model instructions. Show changes for review; never claim that rule checks prove clinical equivalence.
- A new note starts a separate recording. Appending recordings and spoken correction commands are out of scope.
- Proposed recording limit: 120 seconds, shown in the UI. At the limit, stop and process the full captured recording; do not silently truncate it.
- Raw text is read-only. Formatted text is editable. Formatting runs once after transcription and cannot overwrite later edits.
- Free-form dictation is the default. Preserve spoken order and use the transcriber's punctuation with conservative whitespace cleanup. Do not summarize, reorder statements, or infer paragraphs from clinical meaning. Add a section break only for an explicit supported spoken heading. Do not infer sections, fields, or results.
- Initially use manual Copy Note. Add the PRD's automatic copy as a setting in Task 7, with clear status. A later edit requires another copy.
- No audio or transcript network traffic. Initial tool/model setup may need the internet; normal use must work with networking off.
- Use fictional practice cases. User recordings and notes stay out of source control and console logs. Reviewed fictional regression fixtures are versioned separately.
- Keep notes in memory. Store required CLI audio/output files in a private session directory outside the repository. Delete them after processing, cancel, error, and app exit; remove stale session files at the next launch. Deletion is not a secure erase guarantee.
- Exporting a test recording or report is an explicit local action. The clipboard is a separate system output and can be read by other software; copy only when the user chooses manual or automatic copy.

## 3. Reuse from Pulse Log

Review these Pulse Log files and copy useful code or assets into this project during implementation. Adapt and test the copies here. Do not use cross-project imports, symlinks, or runtime paths into Pulse Log:

- `Sources/PulseLogCore/Speech/WhisperTranscriber.swift`: process invocation and output handling. Rework its error paths; malformed JSON must be an error, not displayed as a transcript.
- `Sources/PulseLogCore/Speech/AudioRecorder.swift`: microphone flow. Rework conversion and errors: use a persistent converter and do not ignore write failures.
- `spike/0-whisper-cpp/audio/`: seed recordings and references, subject to content review before reuse.
- `spike/0-whisper-cpp/calculate_wer.py`: metric definitions only. Its word-set term score does not reliably measure multiword terms, values, or negation.
- `dictionary/cardio.json`: review general cardiology terms and procedure-specific groups, including TAVR; avoid broad fuzzy corrections.

Review selected Pulse Log recordings and references for use as fictional regression fixtures, then copy accepted fixtures into `Fixtures/Benchmark/` in this project and version them in Git. If their origin or content is unsuitable, create fictional replacements. Store manifest paths relative to the manifest. After setup, builds, tests, and normal use must work without the Pulse Log checkout. Do not import persistence, authentication, telemetry, subscriptions, or the old procedure parser. Do not change Pulse Log.

## 4. Planned files

All paths below are relative to this project root. `Sources/` is the standard Swift Package Manager source directory, similar to `src/` in a Node project. Each child directory is a build target/module; `Tests/` contains test targets.

| Path | Purpose |
|---|---|
| `Package.swift` | Core, benchmark, app, and test targets |
| `.gitignore` | Build files, models, private recordings, scratch reports; retain curated fixtures |
| `README.md` | Setup and local practice instructions |
| `Resources/Info.plist` | Stable app ID and microphone purpose text |
| `scripts/build-app.sh` | Build and package a local .app |
| `scripts/run-local.sh` | Open that .app |
| `Sources/STTCore/Transcription/Transcription.swift` | Engine-independent TranscriberService protocol and result types |
| `Sources/STTAdapters/Transcription/WhisperCppTranscriber.swift` | whisper.cpp adapter: runs whisper-cli, decodes JSON, handles cancellation |
| `Sources/STTAdapters/AudioCapture.swift` | Capture, conversion, level, duration limit |
| `Sources/STTAdapters/Transcription/WhisperSessionRecovery.swift` | Temporary files and cleanup |
| `Sources/STTCore/NoteFormatter.swift` | Ordered, conservative formatting rules |
| `Sources/STTCore/TransformService.swift` | Transform protocol, preset, request/result types |
| `Sources/STTAdapters/OllamaTransform.swift` | Local-only model calls, errors, cancellation |
| `Sources/STTCore/Transcription/CardiologyVocabulary.swift` | General terms, procedure groups, exact aliases |
| `Sources/STTCore/Benchmark/BenchmarkScoring.swift` | Shared word and selected-phrase scoring |
| `Sources/STTCore/Benchmark/BenchmarkManifest.swift` | Manifest schema and validation |
| `Sources/STTAdapters/Benchmark/BenchmarkFixtureLoader.swift` | File, checksum, inventory, and audio checks |
| `Sources/STTBenchmark/BenchmarkRunner.swift` | Engine-independent paired measurements and summaries |
| `Sources/STTBenchmark/BenchmarkCommand.swift` | CLI entry point; selects a transcriber and calls shared benchmark code |
| `Sources/STTPractice/App.swift` | macOS app entry point; selects transcription and Transform services |
| `Sources/STTPractice/SessionModel.swift` | Recording, transcription, editing, Transform, and review state |
| `Sources/STTPractice/ContentView.swift` | Practice controls and text views |
| `Sources/STTPractice/TransformReview.swift` | Candidate comparison, accept, discard, undo |
| `Sources/STTPractice/FloatingPanel.swift` | Optional floating window |
| `Sources/STTPractice/GlobalHotkey.swift` | Register and release Cmd+Shift+R |
| `Sources/STTPractice/Clipboard.swift` | Copy current edited text and report success |
| `Tests/STTCoreTests/` | Pure formatter, request validation, and metric tests |
| `Tests/STTBenchmarkTests/` | CLI options, paired reports, and process signals |
| `Tests/STTAdaptersTests/` | Audio, process, and local-model adapter contract tests |
| `Tests/STTPracticeTests/` | Session and clipboard behavior tests |
| `Fixtures/Benchmark/manifest.json` | Versioned fixture IDs, paths, checksums, categories, and expected facts |
| `Fixtures/Benchmark/audio/` | Fixed fictional audio inputs, including silence and noise controls |
| `Fixtures/Benchmark/references/` | Reviewed verbatim reference transcripts and expected cleanup examples |
| `Fixtures/Benchmark/README.md` | Fixture origin, recording/conversion settings, scoring, and change rules |
| `docs/benchmarks/` | Reviewed baseline reports with model, prompt, and dataset versions |
| `docs/practice-checklist.md` | Manual acceptance checks |

### Engine and application boundaries

`TranscriberService` is the engine-independent interface. `WhisperCppTranscriber` is intentionally specific: it implements that interface using whisper.cpp's `whisper-cli` executable. Engine-specific process arguments and JSON decoding belong there; the UI and shared benchmark code use only the interface.

`STTBenchmark` is a command-line executable and `STTPractice` is the macOS app. Both depend on `STTCore`. The benchmark command does not depend on app state or views. The app's session model covers recording, transcription, edits, and Transform review. The basic practice PR implements recording through copy; the Transform PR extends that same model.

Deterministic formatting handles exact units, approved aliases, and explicit headings. The separate model-based Clean Up Transform handles filler, grammar, and punctuation on request. Neither layer infers sections or clinical facts.

### Regression fixtures and private recordings

| Data | Storage | Version control |
|---|---|---|
| Reviewed fictional regression audio, references, expected facts, and manifest | `Fixtures/Benchmark/` | Commit together in normal Git; these are fixed test inputs |
| Reviewed baseline reports | `docs/benchmarks/` | Commit metrics and exact dataset/model/prompt/settings identifiers |
| Private practice recordings, user notes, scratch exports, and generated reports | `.local/` or private temporary session storage | Ignore; never promote automatically into fixtures |
| Model weights and build/cache files | Configured local model storage and build directories | Ignore; record model revision/checksum in reports |

The existing 12 compressed Pulse Log clips total about 1.6 MB. A small curated suite can use ordinary Git; no LFS or external storage is needed initially. Record checksums for the exact benchmark audio files and pin any conversion settings. Commit canonical model-ready WAV inputs when conversion is needed so decoder/converter changes cannot silently change the regression input. Do not regenerate audio during ordinary test runs.

Fixture changes need review of the audio, reference text, and expected facts together. Give each case a stable ID and record its origin and purpose. Do not rewrite a reference to match a model error. Reports identify the fixture manifest checksum and source commit, model/version, prompt/version, decoding settings, and hardware. Missing files or checksum mismatches fail the suite. Keep lightweight fixture/scoring tests in `swift test`; run real-model accuracy and latency benchmarks explicitly on the target Mac so ordinary tests do not download models or require local services.

Installed model and tool paths may remain machine-specific; none may depend on the Pulse Log checkout.

## 5. Build order

### Pull request sequence

Use one planning PR, an engineering-foundation PR, then five application PRs. The [engineering standards proposal](../specs/2026-10-20-engineering-standards.md) defines the foundation and a proposed core/adapter target split; review it before implementing those changes. Merge each implementation PR before starting the next. The delivery sequence below groups the task checklist into reviewable results; task numbers identify the detailed work, not separate PRs.

| PR | Scope | Review and acceptance |
|---|---|---|
| Planning | This plan, source PRD, and TODO list | Scope and delivery sequence are reviewed; no application code |
| Engineering foundation | Agent guide, convention indexes, pinned format/lint tools, repository checks, hooks, readiness/manual CI | Local checks and policy tests pass; planned versus active enforcement is documented; hosted execution verified once a remote exists |
| 1. Local transcription baseline | Task 1 foundation and Tasks 2–3: Swift package, app shell, CLI adapter, copied local test assets, benchmark command | Package builds; adapter and metric tests pass; real clips produce an accuracy and timing report offline |
| 2. Usable dictation app | Tasks 4 and 6: microphone capture, recording controls, raw text, editing, copy, cancellation, cleanup | Record → stop → transcribe → edit → copy works in the packaged app; session tests and permission/error checks pass |
| 3. Light formatting | Task 5 and its connection to the practice loop | Formatting tests pass; raw text stays available; explicit headings and units work without generated structure |
| 4. Local Clean Up Transform | Task 6A: local model adapter, cleanup prompt, comparison, accept/discard, undo | Transform tests and offline trial pass; factual changes and latency are reported; model failure preserves the note |
| 5. Convenience and final trial | Tasks 7–8: floating panel, hotkey, optional automatic copy, full benchmark, documentation | All regression checks pass; user can repeat the full practice workflow; remaining accuracy limits are documented |

PR 2 connects capture directly to transcription and editable raw text; PR 3 adds formatting. Keep the raw-text path usable throughout. Each PR includes its own tests and setup notes; do not defer error handling or file cleanup to PR 5. Add VAD work to PR 5 only if measurements justify it; use a separate focused PR if it becomes substantial.

Start local practice after PR 2 and test again after PRs 3 and 4. This gives early feedback before the convenience work. These are proposed PR boundaries, not PRs already created.

### Task 1: Establish a runnable local app

**Files:** `Package.swift`, `.gitignore`, `Resources/Info.plist`, both scripts, `Sources/STTPractice/App.swift`, `ContentView.swift`, `README.md`.

- [x] Create the package with a core library, adapter library, app executable, benchmark executable, and test targets. Use Apple frameworks first; do not add third-party packages for the shell.
- [x] Package the executable into a `.app` with a stable bundle ID and microphone usage description. Apply local ad hoc signing. Do not add App Store distribution or a paid signing requirement.
- [x] Define `./scripts/run-local.sh` as the single build-and-launch command. Resolve paths from the script location.
- [x] Add startup checks for the configured CLI and model paths. Show a clear missing-file error; do not download automatically.
- [x] Run `swift build`, `./scripts/build-app.sh`, and `./scripts/run-local.sh`. Expected: the app opens from Finder/Launch Services with Record disabled until setup is valid.

**Exit:** The user can open the app without entering Xcode. Record the installed CLI version and model path in setup instructions.

### Task 2: Validate local transcription before more UI work

**Files:** `Transcription.swift`, `WhisperCppTranscriber.swift`, `WhisperSessionRecovery.swift`, engine tests.

- [x] Define an async transcriber interface with transcription and cancellation. The result includes raw text, segments when available, model identity, and elapsed time.
- [x] Test a fake process runner for successful JSON, missing model, nonzero exit, invalid JSON, timeout, and cancellation. Expected: tests fail before the adapter exists.
- [x] Invoke `Process` with an argument array, never a shell string. Use unique output paths, English transcription, JSON output, and an optional short general cardiology vocabulary prompt. Do not apply the PRD's TAVR-only prompt to all recordings.
- [x] Drain stdout and stderr without deadlock. Terminate and reap the child on timeout/cancel. Default timeout: 180 seconds; expose it as local configuration for tests.
- [x] Run `swift test --filter WhisperCppTranscriberTests`. Expected: all adapter cases pass and diagnostics never become clinical text.
- [x] Copy one reviewed fictional clip and its reference into `Fixtures/Benchmark/`; if conversion is needed, commit the canonical 16 kHz mono WAV and record its checksum and conversion settings. Run actual inference with `medium.en`; inspect text and full command duration, including model loading.

**Exit:** A valid local transcript exists, with networking off. If the model fails to load, verify the model file before downloading a replacement. Do not use the 15-byte large-model file.

### Task 3: Build the benchmark and choose the engine

**Files:** `Benchmark.swift`, `Sources/STTBenchmark/BenchmarkCommand.swift`, metric tests, `Fixtures/Benchmark/manifest.json`, README.

- [x] Copy reviewed fictional test assets into `Fixtures/Benchmark/` and version audio, references, and manifest together; do not reference the source checkout at runtime. Define manifest entries with a stable ID, audio/reference paths, checksums, expected key phrases/values, test category, and origin. Reject duplicate IDs, missing pairs, checksum mismatches, and an empty suite.
- [x] Add known-answer tests for WER substitutions, deletions, insertions, repeated words, and empty references. Score silence separately; do not divide by zero.
- [x] Measure raw WER using a fixed documented tokenizer: lowercase, separate punctuation, collapse whitespace. Keep number words as spoken; report formatted results separately.
- [x] Measure complete phrase capture, valve size/type, access side, gradients, units, and negation. Count missing and unexpected critical facts. Do not use word-set membership as clinical accuracy.
- [x] Add duration, full transcription time, real-time factor, dataset checksum/source commit, prompt version, CLI/model version, decoding settings, and per-clip results to a local JSON report. Commit reviewed baseline reports under `docs/benchmarks/`; keep scratch reports ignored. Separate process/model startup where measurable.
- [x] Support `swift run STTBenchmark --manifest /absolute/path/manifest.json --report /absolute/path/report.json`. Run paired prompt-on/prompt-off tests on identical audio.
- [ ] Start with three clips covering diagnostic catheterization, PCI, and TAVR. Expand to at least 10 spoken clips across those groups, including clear speech, jargon/values, and quiet/negation cases, plus silence and background-only controls. Report results by procedure group as well as overall; do not claim coverage of untested procedures.

**Exit:** Choose the best measured configuration. Proposed target: median stop-to-text under 5 seconds and every warm run under 10 seconds for 15-second clips. Report first-use time separately. These are discussion targets, not measured results. Any wrong value, side, device, or negation is a listed failure, regardless of WER. Do not claim clinical readiness from this small suite.

**Decision gate:** If results are poor, compare one WhisperKit configuration on the same clips before building more features. Do not add formatter rules to hide recognition errors.


**2026-10-22 result:** The corrected fixed suite completed all 30 inferences offline. See the [baseline and failures](../../benchmarks/2026-10-22-whisper-cpp-medium-en.md). Prompt on improves aggregate WER, but critical value and drug-name errors remain. Compare WhisperKit before Task 4. Controlled quiet speech and background-conversation coverage are still pending; the final coverage checkbox remains open.

### Task 4: Capture microphone audio

**Files:** `AudioCapture.swift`, `SessionFiles.swift`, audio tests, app controls.

- [ ] Test conversion from 44.1/48 kHz stereo to 16 kHz mono, frame count/duration, cancellation, cleanup, and propagated write errors.
- [ ] Request microphone access from the packaged app. Show instructions when denied; allow another attempt after the user changes System Settings.
- [ ] Capture the hardware format and use a persistent `AVAudioConverter`. Keep blocking disk work and inference outside the audio callback.
- [ ] Produce the WAV sample format accepted by the CLI. Flush conversion buffers at stop. Show recording duration and level.
- [ ] Enforce the visible 120-second limit and handle no input device, unplugged microphone, empty capture, and disk failure.
- [ ] Run `swift test --filter AudioCaptureTests`; then record and play a fictional clip manually. Expected: no clipping, repeated frames, dropped ending, or duration mismatch.

**Exit:** Stop returns complete usable audio; cancel removes session files.

### Task 5: Add conservative formatting

**Files:** `NoteFormatter.swift`, `CardiologyVocabulary.swift`, formatter tests.

- [ ] Add tests before implementation for empty text, exact device aliases, numbers and units, explicit headings, unknown words, and negation.
- [ ] Test the same clinical facts as free-form speech and with explicit headings. Free-form output must retain the spoken order without generated section labels; headed output may add line breaks at the spoken labels. Keep ordinary uses such as `the procedure was uncomplicated` as narrative text, not a heading.
- [ ] Use an ordered rule list with escaped patterns and word boundaries. Limit aliases to approved unambiguous forms. Do not map ambiguous `bae` to `BAV`.
- [ ] Keep generic units and layout separate from procedure vocabulary. Organize reviewed terms by procedure group without adding a required procedure selector. Preserve unsupported terminology verbatim; do not infer a procedure or expand ambiguous abbreviations.
- [ ] Convert number words only in supported numeric-unit contexts: e.g. `sixteen french` → `16 Fr`, `twenty six millimeters` → `26 mm`. Preserve unsupported decimals/ranges rather than guessing.
- [ ] Preserve values, laterality, device variants, uncertainty, and negation. Never add a default procedure, normal finding, or missing heading.
- [ ] Test `no paravalvular leak`, `cannot exclude coronary obstruction`, decimal gradients, and repeated formatting. Require `format(format(x)) == format(x)`.
- [ ] Run `swift test --filter NoteFormatterTests`. Expected: exact output matches fixtures; raw text remains available.

**Exit:** The formatter changes notation and explicit layout only. No clinical inference or fuzzy medical substitution.

### Task 6: Deliver the practice loop

**Files:** `SessionModel.swift`, `ContentView.swift`, `Clipboard.swift`, session tests.

- [ ] Define states: setup needed, idle, recording, transcribing, ready, error. Test legal transitions, duplicate Stop, New Note, cancel, and late engine results.
- [ ] In PR 2, connect Record/Stop to capture → transcription → editable raw text. In PR 3, insert deterministic formatting after transcription. Disable conflicting actions while processing; cancel invalidates any later result.
- [ ] Show raw text, editable output, timing, and clear errors. A new recording does not silently erase an edited note; require an explicit New Note action.
- [ ] Add Copy Note and verify it copies the current edited text. Copy success appears only after the pasteboard write succeeds. Do not copy empty/error output.
- [ ] Add optional local export for a practice clip and its corrected reference. Do not save practice content by default.
- [ ] Run `swift test`, then use the packaged app to dictate fictional diagnostic catheterization, PCI, and TAVR cases with networking off and paste each edited note into TextEdit.

**Exit:** The user can practice locally. Stop here for a user trial before convenience features.

### Task 6A: Add local model Transforms

**Files:** `TransformService.swift`, `OllamaTransform.swift`, `TransformReview.swift`, `SessionModel.swift`, Transform tests, README, benchmark report.

- [ ] Implement the confirmed Clean Up preset only: filler removal and punctuation/grammar cleanup, preserving meaning, spoken order, and explicit headings. Do not add inferred sections, summaries, or a preset selector for a single preset.
- [ ] Inspect the installed Ollama version and local model inventory. Its CLI exists on this Mac, but the planning sandbox could not access the loopback endpoint; service status and installed models are unverified. Do not start a service or download models as part of planning.
- [ ] Compare runner choices: reuse Ollama for low setup cost, or use embedded MLX/llama.cpp for a single app process with more integration work. Proposed runner: Ollama bound to `127.0.0.1`, with local models only and no cloud fallback. Verify local processing offline.
- [ ] Test one already-installed suitable instruction model first. If none is usable, choose one small quantized model after confirming its actual download size, license, and hardware support. Do not download several candidates in advance.
- [ ] Define request fields: preset ID/version, source text snapshot, model ID, and timeout. Define result fields: candidate text, model identity, elapsed time, and source revision. Use plain text output for cleanup; no structured-field extraction is needed.
- [ ] Add tests with a fake service for successful generation, unavailable runner, missing model, empty output, timeout, cancellation, and edits made while generation runs. Then implement loopback-only requests without transcript logging or automatic model pulls.
- [ ] Extend SessionModel with transforming and review states; test cancellation and stale results against source revisions. Add Transform, compare, accept, discard, and undo controls. Keep transcription and manual copy usable if the model runner is absent. Do not automatically replace a note or copy an unaccepted candidate.
- [ ] Benchmark Transforms separately on corrected source text, then on actual STT output, to distinguish model changes from recognition errors. Include filler removal, false starts, uncertainty, negation, numbers, side, device variants, and text that resembles model instructions. Inspect every factual change; a missing or added fact is a failure.
- [ ] Measure first-load and warm Transform latency and combined STT/model memory use on this Mac. Bound input and output sizes; report an error rather than silently truncate a note. Keep the original available on any error.
- [ ] Run `swift test --filter Transform`, then complete record → edit → Transform → compare → accept/discard → copy with networking off.

**Exit:** A local model can produce a reviewable Clean Up candidate. The source remains available, manual dictation works without the runner, and errors preserve the current note. Model selection follows measured results, not a promise of zero hallucinations.

### Task 7: Add PRD convenience features

**Files:** `FloatingPanel.swift`, `GlobalHotkey.swift`, `Clipboard.swift`, session tests, manual checklist.

- [ ] Add an editable floating `NSPanel`. Verify keyboard focus, text selection, and copy/paste across normal app windows.
- [ ] Register Cmd+Shift+R with a system-wide hotkey API, release it at shutdown, and show a conflict error. Keep buttons usable if registration fails.
- [ ] Use the same session actions for buttons and hotkey. Ignore repeated key events and do not start another job while transcribing.
- [ ] Add an automatic-copy preference, initially off. When enabled, copy the successful formatted result once; edits use Copy Note to update it. Clearly show when clipboard text is stale.
- [ ] Manually test with TextEdit and a browser focused, including Spaces/full-screen behavior. Document limits; do not assume “always on top” covers all macOS windows.

**Exit:** The PRD hotkey, floating view, and optional automatic copy work on this Mac.

### Task 8: Trial, error review, and handoff

**Files:** `README.md`, `docs/practice-checklist.md`, benchmark tests/configuration where justified.

- [ ] Run the full benchmark and `swift test`. Report missing fixtures and checksum mismatches as failures, never silent skips. Compare against the versioned baseline using the same fixture manifest.
- [ ] Check silence, background speech/noise, fast speech, device names, sizes, side, units, and negation. Background speech can be transcribed; VAD does not identify the intended speaker.
- [ ] If silence/noise results fail, test a compatible local VAD model with speech padding and compare against the unfiltered recording. Add it only if measured results improve without losing quiet words.
- [ ] Verify no network requests during a normal run and an offline cold launch. Check temporary files after success, failure, cancel, quit, and a simulated crash/relaunch.
- [ ] Document the single launch command, microphone permission steps, model path, benchmark command, recording limit, known failures, and how to reset local data.
- [ ] Have the user dictate 10 fictional cases. Record corrections and wait time locally. Use that review to decide whether to improve the engine, vocabulary, or workflow.

**Exit:** Repeatable local practice is documented, with measured limits and no required paid service.

## 6. Downloads and cost

- **Now:** No download needed to write this plan or attempt the installed `medium.en` baseline.
- **Initial build:** Xcode tools are already installed. Reusing whisper.cpp needs no hosted inference service. Local use has no planned API or hosting charge; development time is the main cost.
- **WhisperKit path:** Fetch only the WhisperKit product and one compatible Core ML model plus tokenizer assets. Existing `.bin` models cannot be used directly. Pin a tested package version and exact model revision; record the actual download size before setup.
- **Silero path:** One extra compatible VAD asset only if Task 8 shows it is needed. The PRD's 2 MB figure is not a verified download size.
- **Transforms:** Ollama CLI is already installed. Local models and service status are not yet verified. A separate language-model download may be needed; choose one model after checking available assets and state its size before setup. Local inference has no planned per-request API charge.
- Do not download multiple models in advance. Verify existing assets before requesting any replacement.

## 7. Open questions and assumptions

1. **Confirmed:** General cardiology procedure logs. Initial benchmark groups are diagnostic catheterization, PCI, and TAVR; no required procedure-specific template.
2. **Confirmed:** Free-form dictation with readable text, optional spoken headings, and a local language model for the Clean Up Transform only. Preserve meaning and spoken order; inferred structure, summaries, and field extraction remain deferred.
3. **Proposed:** Use the installed whisper.cpp engine first, with WhisperKit gated on benchmark results.
4. **Proposed:** English, one speaker, separate notes, recordings up to 120 seconds, and fictional practice content.
5. **Proposed:** No automatic retention; manual Copy first, optional automatic copy later.

Resolve these during plan review. There is no need to settle future distribution, database, or iOS choices for this POC.

## 8. Technical references

- [WhisperKit official repository](https://github.com/argmaxinc/argmax-oss-swift): current package products and model options. Import WhisperKit alone, not the umbrella package.
- [WhisperKit configuration source](https://github.com/argmaxinc/argmax-oss-swift/blob/main/Sources/WhisperKit/Core/Configurations.swift): local model/tokenizer folders, download control, and token-based prompts. Recheck against the pinned release before implementation.
- [Apple microphone purpose key](https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription): packaged app permission setup.
- [Ollama documentation](https://docs.ollama.com/): verify the pinned runner's local API, model setup, and offline configuration before integration.

For a WhisperKit replacement, explicitly disable automatic downloads during normal use and provide local tokenizer assets too. Test startup offline; setting a model folder alone is not sufficient evidence of offline operation.
