# Engineering standards proposal

Status: proposed for review. The user chose hosted CI on PR readiness and manual requests. The other standards below are proposals. No hooks, CI, package, or lint configuration have been installed by this document.

## Recommendation

Adopt a small, enforced foundation before application code. Keep a short `AGENTS.md`, focused conventions, one local check command, and a verification guide that separates planned checks from active checks. Use Swift tools and types rather than reproducing TypeScript-specific rules.

The alternatives are documentation alone, which leaves violations to review, or a large custom policy framework, which adds maintenance before the app exists. Start with compiler checks, standard tools, and a few small repository checks. Add custom source analysis only for a demonstrated gap.

## Reference projects

Reviewed the local INAB and SuChef checkouts on 2026-10-20: root agent guides, convention indexes, interface/type/helper/comment/testing rules, CI workflows, local hooks, and INAB's verification/adoption documents. These are reference sources, not instructions for this repository. Copies must stand alone here.

| Source approach | Treatment for this project |
|---|---|
| Short root guide and focused convention files | Adopt; keep discovery easy without making every task read every document |
| Document authority and active/planned check status | Adopt; the original PRD is source material, and accepted scope changes own the current product |
| Red-green behavior tests | Adopt for logic and defects; visual-only and documentation changes use appropriate review |
| Complete interfaces and boundary parsing | Adapt to Swift enums, structs, optionals, throwing functions, and checked decoding |
| Type inference | Adopt for locals; keep explicit public contracts and meaningful domain types |
| Source ownership and helper placement | Adopt; use Swift targets and feature directories, not web routes or generic utilities |
| JSDoc restrictions | Adapt to Swift `///` documentation and short `//` explanations; do not ban useful line comments |
| Fixed string constants in upper case | Do not port; use Swift lowerCamelCase constants and enum cases |
| Frozen copies | Adapt to value semantics and immutable snapshots; do not add freezing machinery |
| Custom ESLint plugins and SonarJS thresholds | Do not port literally; use Swift compiler, swift-format, and a small SwiftLint rule set |
| Git checks and readiness CI | Adopt the chosen low-cost trigger; make freshness limits explicit |
| Database, tenant access, browser/server, CSS rules | Defer until those concerns exist; no empty persistence or authorization layers |
| Feature map | Adapt to actual Mac/CLI workflows with accessibility identifiers; no invented web routes |
| Clean-worktree requirements in hooks | Do not adopt globally; preserve unrelated work and support partial staging |
| Model routing and agent delegation defaults | Do not copy; user/session instructions control these |

## Document layout and ownership

Create the following in a separate engineering-foundation PR:

| File | Owns |
|---|---|
| `AGENTS.md` | Tone, reading order, convention index, task-specific reading triggers, verification/reporting rules |
| `README.md` | Project purpose, actual setup/run/check commands, matching convention index |
| `docs/README.md` | Document authority, accepted scope, proposal/decision/plan distinction |
| `docs/conventions/writing-conventions.md` | One topic per convention; update matching README/AGENTS indexes and links together |
| `docs/conventions/structure-and-reuse.md` | Target dependencies, composition, helper ownership, file naming, reuse |
| `docs/conventions/swift-and-interfaces.md` | Swift contracts, input validation, optionals, errors, comments, immutability |
| `docs/conventions/concurrency-and-resources.md` | Actor ownership, cancellation, audio callback limits, subprocess/file lifetimes |
| `docs/conventions/testing-and-fixtures.md` | Behavior tests, test tiers, canonical datasets, baseline review |
| `docs/conventions/model-changes.md` | STT/Transform prompt versions, quality evaluation, acceptance evidence |
| `docs/conventions/quality-checks.md` | Toolchain, format/lint/build checks, hooks, CI triggers and exceptions |
| `docs/conventions/private-data.md` | Fictional fixtures, private paths, logs, local model endpoints, staged data checks |
| `docs/verification.md` | Actual check commands, statuses, evidence, manual checks, merge enforcement limits |
| `docs/decisions/` | Short durable decisions with rationale and consequences; no duplicate rules |
| `docs/agent/feature_map.json` | Implemented CLI/app workflows once the first workflow exists |

Do not create an empty feature map or decision files for choices not made. Agent instructions link to rules rather than copying them. A missing convention/tool remains a proposal, not an active standard. Update the owning document and affected implementation plan in the same change.

## Code structure and reuse

Use four initial Swift targets:

| Target | Responsibility | Dependencies |
|---|---|---|
| `STTCore` | Validated request/result types, protocols, pure formatting, scoring, benchmark rules | Swift standard library and Foundation; no app/device/process/network implementation |
| `STTAdapters` | whisper.cpp adapter, local Transform client, audio capture/conversion, temporary files | `STTCore`, Foundation, AVFoundation as needed |
| `STTPractice` | SwiftUI/AppKit views, session state, clipboard, hotkey, service composition | `STTCore`, `STTAdapters` at composition |
| `STTBenchmark` | CLI argument validation, selecting adapters, invoking shared benchmark rules | `STTCore`, `STTAdapters` |

Package dependencies enforce target direction. File-level boundaries inside the app remain reviewed rules initially: views call session actions; only app composition constructs concrete engines. Do not claim that a package dependency graph enforces individual file imports.

- Group files within a target by work: `Transcription/`, `Transforms/`, `Audio/`, `Benchmark/`, or the relevant app feature. Add directories when the first real files need them.
- Name files after their main type or responsibility. One coherent job per file; related small types can stay together. Do not force every enum into a new file.
- Keep `WhisperCppTranscriber` specific and `TranscriberService` general. A protocol is useful for a replaceable side effect or real alternate implementation; it is not required for every class.
- Search before adding a helper. Keep private helpers with their owner. Extract shared code when its responsibility and callers are clear; avoid `Utils.swift`, catch-all managers, and speculative frameworks.
- Keep pure transformations separate from I/O. Inject only dependencies needed to control behavior: model/process service, file storage, and a clock where time matters.
- Use one composition point per executable. No global mutable service registry or shared singleton engine hidden in views.
- Copy and adapt useful Pulse Log code and fictional fixtures. Preserve applicable attribution. No symlinks, local package dependency, or runtime reference to another checkout.
- A future procedure database can depend on the core contracts. Do not add persistence now or require a database to transcribe/copy a note.

This adds one adapter target to the existing POC plan. It gives a compiler-enforced separation between reusable logic and hardware/engine code without designing a future platform.

## Swift contracts and readability

- Use Swift 6 language mode from the first source file. Use the compiler's concurrency checks rather than suppressing them globally.
- Prefer `struct`, `enum`, and `let` for data. Use classes for identity/lifetime and actors for shared mutable state. A struct containing mutable reference objects is not automatically a deep snapshot.
- Describe session states with enum cases and associated values. Avoid independent flags such as `isRecording`, `isTranscribing`, and `hasResult` that can disagree.
- Use `Optional` when absence has one clear meaning. Use an enum when absent, loading, failed, and ready differ. Do not port TypeScript's ban on optional properties into Swift.
- Decode external CLI/model responses at the adapter boundary and validate required fields, ranges, finite times, sample rates, and supported formats. `Codable` alone does not establish those invariants.
- Use typed error cases with useful recovery information. Throw for failed async/I/O operations; use `Result` only when it improves the API. Do not wrap every return value in a success/failure container.
- Avoid `try!`, forced casts, force unwraps, and ignored `try?` failures in production paths. Cleanup can be best effort only where the policy states how failures are surfaced or retried.
- Infer straightforward locals. Spell out public/important internal API types. Use enums for closed choices and names that expose units, such as `durationSeconds` and `sampleRateHz`.
- Document non-obvious constraints, side effects, cancellation, and ownership with `///`. Use `//` for a local explanation of why. Do not repeat signatures or require a comment on every function.
- Keep literals local unless naming reveals a rule or multiple callers share the same value. Use Swift casing; avoid a global constants file.
- Keep SwiftUI views focused on presentation and actions. Put decisions and state transitions in a testable session model. Break large view bodies into meaningful subviews rather than using type erasure to hide complexity.

## Concurrency and resource ownership

- Use `@MainActor` for observable UI/session state. Keep inference, subprocess waits, blocking file I/O, and expensive scoring off the main actor. `async` alone does not make work run in the background.
- Pass validated value snapshots across concurrency boundaries and use `Sendable` where required. Do not use `@unchecked Sendable`, `nonisolated(unsafe)`, or `@preconcurrency` as blanket fixes. Any narrow bridge needs an ownership argument and a focused test/review.
- Retain task handles and cancel explicitly. Use source/session revisions so late results cannot overwrite a new recording or edit. Avoid untracked detached tasks.
- Give each audio engine, converter, child process, and temporary directory one clear owner and an explicit stop/cleanup path. Test repeated start/stop and cancellation.
- Audio callbacks must not allocate large collections, perform disk/model/network work, or wait for locks/tasks. Use a bounded handoff and report overflow; do not silently lose samples.
- Drain child process outputs concurrently, terminate/reap on timeout, and never interpret diagnostic output as a clinical transcript.
- Serialize conflicting model operations initially. Measure memory and latency before introducing concurrent inference.

## Testing and model quality

Use XCTest initially, matching the existing plan and reusable tests. A second test framework is not needed for the foundation.

| Tier | Examples | Runs |
|---|---|---|
| Fast deterministic | Formatting, state transitions, input validation, scoring, stale-result rejection, fixture integrity | Full local checks and hosted CI |
| Adapter contract/integration | Fake process/transport responses, real temporary files, generated audio conversion, cancellation/cleanup | Full local checks and hosted CI; no model service required |
| Model evaluation | Actual whisper.cpp/WhisperKit accuracy; Clean Up factual preservation, latency, memory | Explicit local command on the target Mac |
| Manual platform | Microphone permission, real audio capture, floating panel, Spaces, hotkey, clipboard, app launch | Relevant PRs on the target Mac; recorded checklist |

- For executable logic and defects, add a focused behavior test and observe its expected failure before the fix. Documentation, mechanical formatting, and purely visual changes do not need mirrored tests.
- Test observable behavior, not private methods or a copy of the implementation. Assert actual failures and recovery, not only happy paths.
- Ordinary tests never contact Ollama, download models, use the live microphone, or require real user files. An explicitly requested model evaluation fails if its model/fixtures are absent; it does not silently skip them.
- Inject a controllable clock/runner when time is part of the behavior. Avoid sleeps in deterministic tests. Do not share mutable test directories or pasteboard state between parallel tests.
- Version the exact fictional audio inputs, references, expected facts, and checksums. Review reference changes; never adjust them solely to make a model pass.
- Version Transform preset/prompt text and model identity. Evaluate Transforms on corrected text and STT output separately so recognition and rewrite errors remain distinguishable.
- Prompt/model/decoder/normalization changes require the relevant full dataset comparison. Report regressions in numbers, side, device, uncertainty, and negation separately from WER.
- Collect coverage as diagnostic evidence once source exists. Do not impose a blanket percentage or raise coverage by testing trivial accessors. Every important failure path still needs direct evidence.
- Maintain a small workflow map when a workflow works. Record commands or accessible control IDs, prerequisites, visible results, source/test links, and manual-only steps. Do not claim a JSON schema check executes a microphone workflow.

## Automated tools

Use one owner for layout and another for correctness/complexity. Avoid overlapping formatting rules.

| Tool | Proposed use | Setup status |
|---|---|---|
| Toolchain `swift format` | Canonical Swift layout; read-only lint in checks, explicit write command for formatting | Available locally, version 6.2.3; no repo configuration |
| SwiftLint | Small pinned rule set for forced operations, complexity, nesting, and suspicious constructs | Available locally, version 0.63.2; no repo configuration |
| Swift compiler | Swift 6 language mode, concurrency checks, own-code warnings treated as errors | Available; no package yet |
| XCTest/SwiftPM | Deterministic tests and package compilation | Available; no tests yet |
| ShellCheck | Shell-script mistakes, plus `bash -n` for syntax | Planned |
| actionlint | Workflow syntax/expression checks | Planned; not found locally |
| Gitleaks CLI | Redacted staged/current-change secret detection without a hosted credential service | Planned; not found locally |
| Small Python 3 repository checker | Document links/indexes, protected paths, fixture/schema/checksum consistency | Planned; test each policy with passing and failing cases |

Pin the Xcode/Swift toolchain and third-party tool versions in one tooling manifest and use it for setup/local/CI checks. Record actual executable versions; do not claim Homebrew's latest version is pinned. Checksum-verify downloaded tool archives. Commit `Package.resolved` once package dependencies exist. A tool bump is reviewed with its configuration and validation evidence.

Recommended starting policy:

- swift-format owns indentation, whitespace, wrapping, and ordinary naming/style checks. Do not layer a second formatter over it.
- Use SwiftLint `only_rules` to make the active set explicit. Start with forced casts/tries/unwraps, implicitly unwrapped optionals, nesting, and cyclomatic complexity. Confirm rule IDs and fixture behavior against the pinned release.
- Propose a cyclomatic complexity limit of 10 per function. Measure the first state machine/decoder before adding more limits. Keep line counts as review signals, not arbitrary merge blockers.
- Treat enabled lint findings as failures. Narrow suppressions need a reason and review; no file-wide disables to hide new problems. Test the installed rule configuration with accepted/rejected samples.
- Format checks never rewrite files. Do not auto-stage fixes in hooks. A missing required tool is a clear failure with setup instructions, not a silent pass.
- Source policy checks exclude dependencies/build outputs, but include this project's code, scripts, and tests. No broad exclusion of adapters or test helpers.
- Secret scanning and protected-path checks are different: a credential scanner cannot prove a clinical recording contains no private data. Inspect fixture content and origin before committing.
- The staged-data checks inspect index paths and blobs. Do not scan only working-tree files and assume the staged version is the same. Do not print matched private values. Add narrow reviewed exceptions, never broad fixture exemptions.

## Check commands and hooks

Proposed commands, not available yet:

| Command | Purpose |
|---|---|
| `./scripts/setup-dev.sh` | Verify/install pinned development tools explicitly; offer hook setup without overwriting existing hooks |
| `./scripts/check.sh --quick` | Docs, staged private-path/secret checks, non-mutating format/lint; fast feedback |
| `./scripts/check.sh` | Full-tree policy/secret checks, format/lint, script/workflow validation, Swift build/test, local app packaging smoke check |
| `./scripts/format.sh` | Explicit Swift formatting; no automatic staging |
| `swift run STTBenchmark ...` | Opt-in real-model accuracy and performance evaluation |

Before a package exists, the full check validates the documents/configuration/scripts that exist and explicitly reports build/test/package checks as not yet installed. It must not exit as though Swift tests passed. Once the first source PR lands, those checks are mandatory and cannot be skipped on a code-bearing change.

Use a versioned lightweight Git hook, no Node/Husky dependency. Pre-commit runs the quick checks, including checks of the staged snapshot for file/content safety. Run full tests before requesting review; no expensive pre-push model benchmark. Hook setup must inspect/preserve any existing `core.hooksPath` or hooks and explain how to invoke checks directly.

Hooks help feedback but can be bypassed and are not merge enforcement. Partial staging is allowed: staged-snapshot checks inspect the index; whole-tree format/lint checks may also report unrelated working-copy findings. Do not silently stash, stage, reset, or discard the user's work. CI supplies the full committed-revision result.

## CI choice and cost

**User choice:** Run hosted CI when a PR becomes ready for review, plus manual workflow requests. Do not run hosted checks on every push by default.

- Start with one macOS job on a fixed available runner image and a selected installed Xcode version that matches the tool manifest. Run the same full check command. Avoid a platform/toolchain matrix until supporting more than one is a real need.
- Use the proposed merge revision for readiness checks. Pin action commits, set read-only permissions and timeouts, cancel superseded runs, and avoid long-lived credentials.
- No model weights, live services, microphone, or real notes in CI. Cache build dependencies with toolchain/lockfile keys; never cache session directories or raw private output.
- Keep artifacts small and short-lived, limited to reviewed fictional test diagnostics. Never upload the entire working directory or a developer's model cache.
- Manual runs must identify the intended PR and resolve its current head/base and merge revision. A run against an unrelated branch is not PR acceptance evidence.
- After any code or base revision changes, previous results are stale. Request a fresh readiness/manual run before merging. Record the head/base or merge SHA so a green result cannot be mistaken for a current check.
- The chosen triggers do not automatically cover later pushes or base-branch changes. Do not describe this as continuous merge blocking. Document the manual freshness step in the PR checklist.
- Branch protection/rulesets are a separate repository setting. Verify account support, exact check names, and stale-result behavior before claiming required checks. No remote is configured in this checkout yet; visibility, quota, and protections are unknown.
- Confirm Actions allowance/budget when the repository is created. Standard runners are free for public repos; private repos use the owner's allowance and can incur charges beyond it. Do not promise zero hosted cost or change account spending settings without a request.

Local full checks remain available when hosted capacity is absent. A local result must be labelled local; it is not a hosted CI pass.

## Delivery and acceptance

Add an **engineering-foundation PR** after the planning PR and before the five application PRs. It contains agent/docs indexes, the accepted conventions, pinned tooling, repository checks, hooks, and the readiness/manual CI workflow. Keep application features out of it. Add package compilation and tests in application PR 1.

The foundation is complete only when:

1. All local document links and matching convention indexes pass.
2. Invalid policy/config samples fail for the expected reason, and valid samples pass.
3. Checks do not modify/stage files and cannot hide a missing tool or missing required fixture.
4. Synthetic unsafe staged paths/credential examples are rejected without printing values.
5. The verification guide names each active/planned/manual check and its limitation.
6. The workflow passes static validation. Hosted execution is verified after a remote exists; until then it remains unverified.

The first source PR adds compiler-enforced target boundaries, Swift 6 settings, fast test targets, and a packaging check; the verification guide then records actual results. Future source PRs update tests, relevant workflow entries, and durable decisions with their changes.

## References

- [swift-format](https://github.com/swiftlang/swift-format): toolchain formatter and lint mode.
- [SwiftLint](https://github.com/realm/SwiftLint): explicit rule selection, configuration, and strict checks.
- [Swift concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/): actors, isolation, and sendable data.
- [Swift API design guidelines](https://www.swift.org/documentation/api-design-guidelines/): Swift naming and documentation.
- [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions): runner and allowance costs.

No conventions or executable tools from the reference projects were copied into active use in this change. This proposal defines what to adopt and what the foundation PR must verify.
