# TODO

## v1

- [ ] Migrate speech transcription from whisper.cpp to WhisperKit through the existing transcriber interface.
  - Record the whisper.cpp baseline before migration, including tool/model versions, prompt settings, hardware, and test results.
  - Run the same audio fixtures, reference transcripts, scoring rules, and prompt-on/prompt-off tests with WhisperKit. Use equivalent model variants where available; document model and decoding differences.
  - Replicate tests for critical terms, values, units, laterality, negation, silence, and background noise. Report accuracy by procedure group and overall.
  - Compare first-load and warm latency, full stop-to-text time, real-time factor, and peak memory use on the same Mac.
  - Repeat cancellation, error handling, offline cold launch, and local file cleanup tests. Confirm normal use makes no network requests.
  - Repeat the record → transcribe → Clean Up → review → copy workflow. Keep Transform model and settings fixed during comparison.
  - Agree on acceptable accuracy and performance differences before testing. Switch the default engine only after the comparison meets those criteria; document results and remaining limits.
