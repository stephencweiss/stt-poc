# Logging and session state implementation plan

> **For agentic workers:** Use superpowers:executing-plans for inline execution. The user approved this scope on 2026-10-30.

**Goal:** Keep log definitions separate from viewing instructions and enforce session transitions in code.

**Architecture:** Add a staged text-diff gate requiring a nonempty staged catalog update when logging expressions change. Do not validate catalog semantics or parse Swift. Move state/event rules into PracticeState; SessionModel owns effects and revision checks.

**Tech Stack:** Swift 6, XCTest, Python unittest, existing Git hook.

## Tasks

- [x] Add failing repository policy tests in scripts/tests/test_logging.py for added, changed, removed, renamed, and partially staged logging code, catalog deletion, initial commits, and unrelated edits.
- [x] Implement scripts/logging_policy.py with a logging-expression text scan and Git staged diff/index reads. Run it in scripts/check.sh --quick; run its tests in full checks. Reject logging changes without a nonempty changed catalog. Document conservative detection limits.
- [x] Add docs/log-catalog.md and docs/conventions/logging.md; update README.md, AGENTS.md, docs/README.md, docs/logging.md, and docs/verification.md. Catalog current calls exactly and state when logs are appropriate. No semantic matching gate.
- [x] Add failing Tests/STTPracticeTests/PracticeStateTests.swift. Define independent expected state/event outcomes; check all combinations and invalid events. Keep session integration tests.
- [x] Add Sources/STTPractice/PracticeState.swift with next(after:). Route SessionModel transitions through a single helper; reject invalid events before effects. Preserve revision, recording ID, and closed guards. Replace docs/session-state-transitions.md with a short ownership guide linking to code and tests.
- [x] Run focused tests after each implementation. Run swift formatting and ./scripts/check.sh, inspect the diff, and record actual evidence in docs/verification.md.

## Transition contract

Setup requests are accepted from nonbusy states; success/failure leave checkingSetup. Record begins from idle/error. Capture start, stop, conversion, and transcription results advance the main path. Cancel is allowed from starting/recording/stopping/transcribing. Failure cleanup can enter or remain in cancelling. Cleanup outcomes leave cancelling for idle/error/setupNeeded. New Note resets nonbusy states according to checked paths. Session guards retain text/configuration and task identity requirements. Shutdown retains the separate closed flag.

## Gate contract

Inspect changed Swift source under Sources in the index, including deletions and renames. Scan changed hunks and five context lines for logging expressions, including the current short multiline calls. Detect Logger/OSLog construction, logger method calls, and legacy logging calls conservatively. A changed catalog must exist in the index, contain non-whitespace text, and differ from HEAD (or be new). Unstaged catalog updates cannot satisfy the gate. This checks joint updates only; review owns meaning and completeness.

## Completion evidence

Local ./scripts/check.sh passed on 2026-10-30 with 71 Swift tests and 25 repository/tool tests, lint, build, and app packaging. The initial-commit full-mode regression failed before its fix and passed after it. Review found no remaining issues. Implemented on codex/pr4-review-docs from PR #4.
