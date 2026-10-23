# Light Formatting Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task by task. Track verified steps with checkboxes. This is a draft plan, not permission to implement it.

**Goal:** Turn a completed raw transcript into readable, editable text with conservative notation and explicit layout rules.

**Architecture:** Add a pure synchronous formatter in STTCore. The session runs it once on a successful transcript before entering ready state. Raw text remains unchanged; manual edits, copy, and export use the editable result. Formatting has no model, process, file, or network dependency.

**Tech Stack:** Swift 6, Foundation, XCTest, existing SwiftUI session and test targets. No package or model download.

**Status:** Draft for user review. No formatter implementation is included. Based on Task 5 of the [POC plan](2026-10-20-local-stt-poc.md) and the working app in PR #4. Implement after PR #4 merges, then open one focused formatting PR against main.

## Scope and approach

Use a small ordered set of exact rules. This is the lowest-cost extension of the accepted scope. Broad fuzzy corrections could change clinical facts; local-model cleanup belongs in the later Transform slice.

Preserve spoken order, facts, values, units, side, negation, uncertainty, meaningful repetition, and unsupported text. Do not infer a procedure, section, normal finding, diagnosis, or missing value. Do not remove filler, repair grammar, summarize, or resolve false starts. Recognition errors such as a wrong drug name remain errors in raw and formatted text.

Formatting runs automatically once on successful transcription. Do not add a Format button, automatic reformatting after edits, or another output pane. The existing Raw transcript disclosure supplies the comparison view. Empty/error-marker handling still precedes formatting.

### Proposed rule contract

These details refine the existing scope and need review before implementation.

| Rule | Input | Output and boundary |
|---|---|---|
| Whitespace | Leading/trailing spaces; repeated horizontal spaces; CRLF | Trim edges, collapse horizontal whitespace, normalize newlines, and cap blank lines at one. Preserve paragraph boundaries. Do not infer paragraphs from clinical meaning. |
| Explicit heading command | `Heading findings. No coronary obstruction.` | `Findings:` then a newline and the statement. Match only an approved heading immediately after the literal word `heading`, at the start of the transcript or a sentence/line. Preserve commands with unknown labels. |
| Existing heading label | Standalone `Findings:` | Canonicalize the approved label and keep its section break. Do not treat `the findings were normal` or a bare narrative word as a heading. |
| Numeric units | `16 french`, `26 millimeters`, `2.5 millimeters` | `16 Fr`, `26 mm`, `2.5 mm`. Match complete numeric-unit expressions; retain the numeric value, sign, and decimal digits. |
| Integer words with units | `sixteen french`, `twenty six millimeters` | `16 Fr`, `26 mm`. Initially support complete English integer phrases from zero through ninety-nine, including hyphenated tens, directly before an approved unit. |
| Exact vocabulary spelling | `pci`, `tavr`, `sapien` | `PCI`, `TAVR`, `SAPIEN`. Initial allowlist is case normalization only for PCI, TAVR, LAD, RCA, IVUS, FFR, SAPIEN, and Evolut. Preserve variants and other tokens. No fuzzy matching, word joining, or abbreviation expansion. |

Proposed heading allowlist: Procedure, Indication, Access, Findings, Intervention, Hemodynamics, Complications, Plan. Preserve the speaker's order. Do not create absent headings. Marker punctuation after a recognized command is consumed as part of that command; punctuation in the following statement is retained.

Unit rules initially cover French/Fr and millimeter/millimeters/mm, case-insensitively in numeric contexts only. Do not rewrite ordinary uses such as `the patient is French` or `sixteen French patients`. Define and test a narrow device-unit context for French (for example, a sheath/catheter size or a standalone size phrase); preserve nationality uses and ambiguous context.

Protect unsupported numeric expressions before shorter rules run: number-word decimals, ranges, fractions, compound dimensions, corrections, and phrases outside the supported grammar must remain intact. For example, `two point five millimeters` must not become `two point 5 mm`; `twenty to twenty six millimeters` must not be partly rewritten. Do not round values or turn `2.5` into `25`. Unsupported expressions can remain less polished.

For headings, recognizing `heading findings` is safer than guessing from bare words. Existing unambiguous standalone labels remain supported. Confirm this command syntax before implementation; the source PRD does not establish reliable detection from ordinary narrative.

## Files and boundaries

| Path | Change |
|---|---|
| `Sources/STTCore/Formatting/NoteFormatter.swift` | New pure entry point `NoteFormatter.format(_ text: String) -> String`; ordered rules and layout handling |
| `Sources/STTCore/Formatting/NumericUnitFormatter.swift` | New internal numeric-unit grammar, protected unsupported spans, and exact notation rules |
| `Sources/STTCore/Formatting/FormattingVocabulary.swift` | New reviewed, fixed heading/unit/case tables used only by formatting |
| `Tests/STTCoreTests/NoteFormatterTests.swift` | New exact input/output tests; free-form, heading, number, vocabulary, and idempotence regressions |
| `Sources/STTPractice/SessionModel.swift` | Populate editedText with formatted text once; keep rawText as the engine result |
| `Tests/STTPracticeTests/SessionModelTests.swift` | Verify raw/edited separation, current-edit copy/export, and stale/cancel behavior with formatting |
| `README.md`, `docs/practice-checklist.md`, `docs/verification.md` | Explain implemented rules, manual trial, and measured check results |
| `docs/agent/feature_map.json` | Update the implemented dictation workflow only when formatting works |

Keep the existing STTCore/Transcription/CardiologyVocabulary.swift prompt and version unchanged. FormattingVocabulary owns only display rules; it is not a second speech-recognition dictionary. Do not import Pulse Log or depend on its files at runtime.

## Task 1: Establish the formatter contract

- [ ] Write exact-output XCTest cases before implementation. Include empty text, mixed line endings, whitespace, ordinary prose, and no inferred headings or paragraphs.
- [ ] Add paired free-form and headed versions of the same fictional note. Assert spoken order and clinical statements stay intact.
- [ ] Run `swift test --filter NoteFormatterTests`; observe failures because the formatter does not yet exist.
- [ ] Implement the public pure entry point with whitespace rules only and make the Task 1 cases pass. Add heading and numeric expectations in their later tasks, immediately before their implementation.
- [ ] Run `swift test --filter NoteFormatterTests` and commit the passing contract and tests.

## Task 2: Explicit layout and spelling

- [ ] Add failing cases for the approved heading commands, existing standalone labels, unknown headings, mid-sentence narrative, and heading words used as ordinary nouns.
- [ ] Implement anchored heading recognition and case normalization with escaped labels and whole-token boundaries. Match the literal command, not clinical meaning.
- [ ] Add and pass exact vocabulary-case tests. Include `evolution`, Evolut variants, and unknown medical terms to reject broad substring replacements.
- [ ] Verify `the procedure was uncomplicated`, `cannot exclude coronary obstruction`, and `no paravalvular leak` retain their meaning and order.
- [ ] Run `swift test --filter NoteFormatterTests`; commit passing layout/spelling rules and tests.

## Task 3: Numeric-unit notation

- [ ] Add failing tests for the approved integers/units, existing digits, hyphenated tens, signed/decimal digit values, and unchanged unsupported expressions.
- [ ] Add negative tests for partial matches inside decimals, ranges, fractions, dimensions, and corrections. Include `two point five millimeters`, `twenty to twenty six millimeters`, `twenty six by forty millimeters`, `twenty six no twenty nine millimeters`, and `one hundred twenty six millimeters`.
- [ ] Implement complete-expression recognition and protected spans before substitutions. A conservative clause-level passthrough is acceptable: if a clause contains an unsupported numeric construction, skip numeric-unit rewriting for that clause. Define the clause boundaries and numeric continuation tokens in tests. Do not use a trailing-number regex that rewrites only its last words.
- [ ] Add exact-output regressions for device variants, laterality, gradients, units, and uncertainty in the same note. Preserve unsupported gradient notation as dictated.
- [ ] Require `format(format(input)) == format(input)` for every fixture. Run `swift test --filter NoteFormatterTests` and commit the passing rules.

## Task 4: Connect the existing note workflow

- [ ] Add a fake-transcriber session case returning text such as `  sixteen french sheath. no paravalvular leak.  `. Assert rawText equals the exact engine result and editedText equals the expected formatted output.
- [ ] Observe the new integration test fail, then change only the successful transcript assignment from `editedText = result.text` to `editedText = NoteFormatter.format(result.text)` after current empty/marker validation and revision checks.
- [ ] Prove later edits are preserved and Copy Note copies the edited text. Prove the export snapshot uses current edits and the selected snapshot survives New Note.
- [ ] Re-run duplicate Stop, cancellation, late-result, and stale-event session tests. Formatting must not create another task or alter file ownership.
- [ ] Run `swift test --filter STTPracticeTests`; commit the passing integration. No new UI controls are expected.

## Task 5: Regression evidence, documentation, and review

- [ ] Run the formatter over the committed baseline JSON's transcript strings offline. Produce a local side-by-side raw/formatted review without another model run. Verify the report schema before extracting fields. Do not edit reference transcripts or recognition failures to fit formatting.
- [ ] Review every changed output, especially values, negation, side, and device names. Ordinary tests own deterministic behavior. Do not claim that these tests establish clinical equivalence or improve raw STT WER.
- [ ] Keep raw WER, expected-fact scoring, prompt settings, fixture identities, and benchmark output unchanged. A separate formatted review must be labeled as formatting evidence, not a new recognition baseline.
- [ ] Update README, manual checklist, and workflow map with actual implemented behavior. Document the supported heading syntax and unsupported numeric phrases. Update verification only with checks actually run.
- [ ] Run `./scripts/format.sh`, then `./scripts/check.sh`. Expected: formatter/session regressions, existing tests, fixture checks, lint, compiler, and signed app packaging all pass.
- [ ] Run `./scripts/run-local.sh`. Manually dictate the same fictional note free-form and with explicit heading commands; compare raw/editable text, edit, copy into TextEdit, and export if selected. Record only the checks actually completed.
- [ ] Review the code against this plan and repository conventions. Fix material findings. Open one focused formatting PR after PR #4 merges; attach it and run hosted checks for its final head/base. Do not merge without the user's instruction.

## Acceptance and deferred work

Ready when deterministic examples pass, raw text stays available, formatting runs once, edits/copy/export work, and no rule infers clinical structure or corrects a recognition error. No model download is needed. The heading syntax and initial allowlists above remain proposed until plan review.

Local-model Clean Up, live transcription/VAD, long-session recording, WhisperKit migration, hotkeys, and automatic copy remain separate work. This plan does not change recording or transcription timeouts.
