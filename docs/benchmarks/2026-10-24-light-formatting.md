# Light formatting review

This review applies deterministic formatting to the 30 transcript strings in the committed whisper.cpp baseline. No audio was transcribed again. Model, prompt, raw WER, expected facts, audio, references, and baseline JSON remain unchanged.

- Baseline: [2026-10-22 report](2026-10-22-whisper-cpp-medium-en.json)
- Baseline SHA-256: `a6ff4aebb6a9368d5898bbf791081235be8d366e746c66d34533d3c955e31b03`
- Formatter source digest: `55d57d94d695d470f4e44515010851d924ddaeea49a4bd3f0bf8075c9116bcae` (SHA-256 of sorted repository-relative Formatting/*.swift paths, a NUL separator after each path, and each file's bytes)
- Local review output: ignored .local/formatter-evaluation/review.json; 30 raw/formatted pairs
- Result: 4 transcripts changed; 26 were identical. Every changed output was reviewed against its raw source.

| Case | Prompt | Changed word spans |
|---|---|---|
| cardio_05 | Off | `sapien` → `SAPIEN` |
| cardio_08 | Off | `millimeter` → `mm` |
| cardio_08 | On | `millimeter` → `mm` |
| tavr_gradient | Off | `Sapien` → `SAPIEN` |

The changed spans use approved spelling case and numeric-unit notation. No changed span adds or removes a clinical statement, negation, side, device variant, or numeric value. This is a limited text review, not proof of clinical equivalence. Unrecognized spelling such as `evolute` and known baseline recognition errors remain unchanged. This is not improved raw WER or a new recognition baseline.

Conservative clause guards can leave otherwise supported values unchanged when mixed with complex or ambiguous language. The automated suite covers invented text pairs with bare/explicit headings, negation, uncertainty, supported numbers/units, and unsupported numeric constructions. Every fixture checks repeated-formatting stability. Session tests check exact raw preservation, once-only formatting, and current-edit copy/export. The formatting microphone and TextEdit trial remains pending in the [manual checklist](../practice-checklist.md).

To repeat this review, decode the baseline's measurements array and apply NoteFormatter.format to each transcript string. Save each id, promptEnabled, raw string, and formatted string to an ignored local report. Compare every changed span. No benchmark command or model run is needed.
