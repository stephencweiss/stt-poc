# Verification and limits

Status: engineering foundation implemented locally; final check evidence and hosted results are recorded below. Application source does not exist yet.

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
| Fixture checksums and manifest integrity | Implemented | Reports suite not installed until application PR 1; existing suite cannot silently skip missing assets |
| Repository policy and installed tool tests | Implemented | Fictional temporary files; no services or models |
| Swift format/SwiftLint | Implemented | Config tested on temporary Swift snippets; no app source yet |
| ShellCheck, shell syntax, actionlint | Implemented | Static workflow validation does not prove a hosted run |
| Swift app compiler, XCTest, packaging | Planned: application PR 1 | Check reports NOT INSTALLED; source without a package fails |
| Four-target dependency rules | Planned: application PR 1 | Package graph enforces target direction; app file boundaries need review |
| Model accuracy/latency/memory | Planned: explicit local benchmark | Not a default CI or unit-test requirement |
| Microphone, hotkey, floating panel, clipboard | Planned: relevant application PR | Manual checks on the target Mac |
| Workflow map | Planned: first working workflow | No empty map or unverified UI automation |
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

The local hook is enabled with core.hooksPath=.githooks. The initial [hosted foundation run](https://github.com/stephencweiss/stt-poc/actions/runs/39602887351) passed for engineering code commit `35a3b6d`, using the proposed merge with the planning branch. Current acceptance evidence is the latest check on [engineering PR #2](https://github.com/stephencweiss/stt-poc/pull/2); later head/base changes require another run. No application build, model benchmark, or medical accuracy has been claimed.
