# Verification and limits

Status: engineering foundation and file benchmark are implemented. The usable dictation slice adds microphone capture, a note editor, manual copy, and optional sample export. Live microphone and cross-app paste acceptance remain manual.

## Commands

```sh
./scripts/setup-dev.sh --install-tools
./scripts/setup-dev.sh --hooks
./scripts/check.sh --quick
./scripts/check.sh
./scripts/format.sh
```

Setup verifies pinned Xcode/Swift and tool versions from tooling.json. Downloads are explicit and archive checksums are verified. Python 3.11+ is a compatible script runtime, not a pinned compiler dependency. Setup supports Apple Silicon macOS only. Existing hook configuration is preserved.

| Check | Status | Limit |
|---|---|---|
| Matching convention indexes and local document file links | Implemented | Anchor links and Markdown formatting are not checked; supplied PRD is preserved |
| Logging/catalog joint update | Implemented | Text-diff heuristic only; staged index in quick checks, current changes in full checks; no semantic catalog validation |
| Protected paths and symlinks | Implemented | Staged mode reads index paths; full mode covers tracked/nonignored paths |
| Redacted Gitleaks scan | Implemented | Staged mode materializes index blobs; scans current files, not all Git history; not a clinical-content detector |
| Fixture checksums and manifest integrity | Implemented | 15 committed fictional cases; missing or changed assets fail, with no silent skips |
| Repository policy and installed tool tests | Implemented | Fictional temporary files; no services or models |
| Logger-only API rule | Implemented | SwiftLint checks code identifiers; comments, strings, and OSLog module imports for Logger are allowed; lint inspects current files, not staged blobs |
| Swift format/SwiftLint | Implemented | Checks application/test source and temporary rule-test snippets |
| ShellCheck, shell syntax, actionlint | Implemented | Static workflow validation does not prove a hosted run |
| Swift app compiler, XCTest, packaging | Implemented | Swift 6, warnings as errors, and ad hoc signed local app; no distribution signing |
| Four-target dependency rules | Implemented | Package graph enforces target direction; file boundaries require review |
| Model accuracy/latency/memory | Measured locally | Full offline baseline completed; critical recognition errors remain; not a default CI requirement |
| Microphone capture, note editing, manual copy/export | Implemented; basic microphone → transcription → edit → copy trial complete (user report) | Export and detailed permission/device/offline/cleanup checks still require target-Mac manual results |
| Hotkey, floating panel, automatic copy, formatting, Clean Up | Planned: later application PRs | Outside the usable dictation slice |
| Workflow map | Implemented | docs/agent/feature_map.json records benchmark and local-dictation workflows; no automated UI test |
| Remote branch protection | Not configured/verified | Workflow and local hooks do not enforce merging |

## Hosted checks and freshness

Engineering checks runs on ready_for_review and workflow_dispatch only. It does not run on PR opening, commits, or base updates. Mark a draft ready to request a run; after another head/base revision, request a fresh run before merging. Do not reuse an old green result.

Manual dispatch needs the workflow on the default branch first. After bootstrap:

```sh
gh workflow run check.yml --ref main -f pr=PR_NUMBER
```

The resolver accepts an open same-repository PR and records current head/base/merge SHAs in the run summary. Checkout verifies merge parents. A manual run tests that PR, not an arbitrary selected branch. If merge computation is unavailable or parents differ, the run fails and must be retried/resolved. Same-repository branches only are supported initially; fork manual runs fail explicitly.

For the initial stacked PR, use a readiness event. After the planning PR merges, retarget the foundation to main and run checks again; the old stack-base result is stale. Do not merge or change repository settings as part of creating the stack.

One macOS job uses the pinned Xcode selection and shared local command. No model/service downloads, private artifacts, or broad workspace uploads. Runner image updates can remove an Xcode version; setup fails clearly rather than using a different compiler silently.

The remote is public, so standard hosted runner use is currently free under GitHub's published policy. Do not change visibility or budget settings implicitly. Protecting main and requiring checks is a separate repository configuration decision.

## Evidence

Local `./scripts/check.sh` passes with 18 policy/tool tests. The checks verified Xcode 26.2, Swift format 6.2.3, SwiftLint 0.63.2, ShellCheck 0.11.0, actionlint 1.7.12, and Gitleaks 8.30.1. Installed lint/formatter tests reject unsafe snippets; a synthetic staged credential is detected and redacted even with a clean working copy. Fixture tests reject unlisted files, changed checksums, missing pairs, path escapes, and staged mismatches. Document, secret, shell, and workflow checks pass.

The local hook is enabled with core.hooksPath=.githooks. The initial [hosted foundation run](https://github.com/stephencweiss/stt-poc/actions/runs/39602887351) passed for engineering code commit `35a3b6d`, using the proposed merge with the planning branch. Current acceptance evidence is the latest check on [engineering PR #2](https://github.com/stephencweiss/stt-poc/pull/2); later head/base changes require another run. Those foundation results predate the application baseline. Application evidence follows below.

## Application baseline

Local full checks pass with 40 Swift tests and 18 repository/tool tests. The compiler uses Swift 6 with warnings as errors. Tests cover phrase/word scoring, fixture validation, CLI options, paired reports, process errors, timeout, cancellation, signal handling, and session recovery. Shared test-only root discovery finds the nearest ancestor containing a Package.swift file; tests cover nested paths, directory-marker rejection, and a clear missing-manifest error. App packaging passes plist validation and ad hoc signature verification. The launch script was run locally; visual interaction and microphone behavior are not automated.

The full awake run on 2026-10-22 completed all 30 inferences with network access denied, without changing the timeout. The [reviewed baseline](benchmarks/2026-10-22-whisper-cpp-medium-en.md) includes raw JSON, identities, sampled memory, and case-by-case failures. Prompt-on raw WER was 19.16% (19.44% on human recordings only), median transcription time 1.60 seconds, maximum 6.63 seconds. Critical value and drug-name errors remain. Earlier sleep-interrupted attempts wrote no partial success report.

Review also found incorrect expected facts in the fixture manifest. They were corrected against unchanged references, and a new regression checks reference/fact consistency. WER remains provisional until an independent audio/reference audit. The synthetic voice case is pipeline coverage only. Quiet speech, background conversation, true cold-cache startup, microphone capture, clipboard, formatting, and Clean Up remain untested or unimplemented. The user chose to build the practice app first on 2026-10-22, then compare WhisperKit after the first trial. Recognition failures remain open.

## Usable dictation slice

The app uses AVAudioRecorder for framework-managed capture. No application audio tap or custom audio-buffer queue is used. One converter processes the finalized recording off the main actor into the canonical CLI WAV format. Recorder failures and device availability checks produce typed errors. Level measurements detect energy only, not speech. Permission and physical device behavior still require the manual checklist.

The session owns start/stop/inference/cancel work and rejects old events/results by recording identity and revision. Quit delays termination until owned work drains and files are removed. Recording files are temporary; the app retains bounded WAV bytes for the current successful note in memory for optional export. New Note, cancel, or quit releases session audio. An export already selected owns its snapshot until completion; saving files still requires explicit export. Notes and audio are not logged.

The final local ./scripts/check.sh passed on 2026-10-22 with 68 Swift tests and 18 repository/tool tests, lint, compiler warnings as errors, plist validation, and ad hoc signature verification. Conversion tests pass output through the same canonical WAV validator used by whisper.cpp. The capture-failure cleanup test fails when its state fix is removed and passes with the fix.

Local launch via ./scripts/run-local.sh built and opened the signed app on 2026-10-22. On 2026-10-29, the user confirmed completion of the basic microphone → transcription → edit → copy trial reported in PR #4. This does not establish offline operation, cross-app paste, or the other detailed manual results. Hosted evidence must be from the current PR head/base. The [practice checklist](practice-checklist.md) records the completed basic trial and owns the remaining manual checks. No hardware test is claimed from fake-service tests.


## Logging catalog and executable state transitions

Local `./scripts/check.sh` passed on 2026-10-30 with 71 Swift tests and 25 repository/tool tests, document and secret checks, Swift format/SwiftLint, shell/workflow checks, compiler warnings as errors, plist validation, and app signature verification.

The transition test checks all 170 state/event combinations against an independent expectation table. Existing session tests still cover recording, cancellation, stale events/results, failed cleanup sequencing, copy, export, and shutdown. These are fake-service tests, not new hardware acceptance evidence.

Seven logging gate tests cover added, changed, removed, and renamed logging source; partial staging; rejected empty/deleted/whitespace-only catalog edits; unrelated source; untracked files; and initial commits. The initial-commit full-mode regression failed before the fix and passed after it. The gate requires a joint catalog update and does not validate its meaning. See the [logging convention](conventions/logging.md) for detection limits.


## Logger-only policy

Local `./scripts/check.sh` passed on 2026-10-30 with 71 Swift tests and 28 repository/tool tests, lint, build, and app packaging after adding `logger_only`. Installed-tool regressions reject legacy constructors, type aliases, default-log access, function references, and calls. They permit Logger, names in comments and strings, and the OSLog module import/qualification used to access Logger. The rejection test failed before the rule was added and passed afterward.

The Logger-only rule uses SwiftLint syntax kinds to exclude comments and strings. Like the other Swift lint rules, quick and full checks inspect current source; staged catalog checks remain a separate index-based text rule. A catalog update cannot make a forbidden API pass lint. False positives require a detector regression and correction, not a dummy catalog edit or blanket hook bypass.
