# Verification and limits

Status: engineering foundation and application baseline implemented locally. The baseline has a setup window and a file-transcription benchmark. Microphone recording and note editing remain planned.

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
| Protected paths and symlinks | Implemented | Staged mode reads index paths; full mode covers tracked/nonignored paths |
| Redacted Gitleaks scan | Implemented | Staged mode materializes index blobs; scans current files, not all Git history; not a clinical-content detector |
| Fixture checksums and manifest integrity | Implemented | 15 committed fictional cases; missing or changed assets fail, with no silent skips |
| Repository policy and installed tool tests | Implemented | Fictional temporary files; no services or models |
| Swift format/SwiftLint | Implemented | Checks application/test source and temporary rule-test snippets |
| ShellCheck, shell syntax, actionlint | Implemented | Static workflow validation does not prove a hosted run |
| Swift app compiler, XCTest, packaging | Implemented | Swift 6, warnings as errors, and ad hoc signed local app; no distribution signing |
| Four-target dependency rules | Implemented | Package graph enforces target direction; file boundaries require review |
| Model accuracy/latency/memory | Planned: explicit local benchmark | Not a default CI or unit-test requirement |
| Microphone, hotkey, floating panel, clipboard | Planned: relevant application PR | Manual checks on the target Mac |
| Workflow map | Implemented | docs/agent/feature_map.json records benchmark and setup-window workflows; no automated UI test |
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

Local full checks pass with 36 Swift tests and 18 repository/tool tests. The compiler uses Swift 6 with warnings as errors. Tests cover phrase/word scoring, fixture validation, CLI options, paired reports, process errors, timeout, cancellation, signal handling, and session recovery. App packaging passes plist validation and ad hoc signature verification. The launch script was run locally; visual interaction and microphone behavior are not automated.

The first real-model run stopped on the 180-second timeout after the Mac entered clamshell sleep. No partial success report was written. A complete awake run is still required; no accuracy or latency result is claimed yet. References are inherited and not independently audited word-by-word; WER remains provisional. The fixed synthetic voice case is pipeline coverage, not human accuracy evidence. No microphone capture, clipboard, formatting, or Clean Up behavior is included in this PR.
