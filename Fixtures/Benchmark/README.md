# Fixed cardiology regression suite

The author confirmed on 2026-10-21 that the 12 Pulse Log recordings are fictional practice cases and approved public reuse. These files are independent copies; no runtime dependency on Pulse Log remains. The named patient in cardio_07 is fictional.

The source files were cardio_test_1.m4a through cardio_test_12.m4a, with matching reference text. Each manifest entry records the source checksum. References were copied unchanged; they are inherited references, not independently re-audited word-by-word against the audio. Treat WER as a provisional baseline until that audit. Do not change a reference simply because a model disagrees.

Canonical audio is 16 kHz mono PCM16 WAV, converted once with the installed ffmpeg using:

```sh
ffmpeg -nostdin -hide_banner -loglevel error -i SOURCE.m4a -ar 16000 -ac 1 -c:a pcm_s16le OUTPUT.wav
```

Normal tests use committed WAV files; they never reconvert them. The manifest stores SHA-256 for each WAV and reference. Silence and noise are five-second local controls. Noise uses Python Random(20261021), 80,000 uniform integer samples in -3000...3000, packed as little-endian signed 16-bit mono at 16 kHz. Silence uses zero samples. No model generated the controls.

A separate tavr_gradient case was generated from its exact fictional reference with the installed macOS say default voice, then converted with the same ffmpeg settings. It covers gradient units and negative findings. This synthetic voice case tests pipeline behavior; it is not evidence of human-dictation accuracy.

Cases include diagnostic catheterization, PCI, TAVR, Watchman, mixed procedures, planned procedures, and spoken corrections. Cases are varied practice utterances, not a representative clinical validation set. Some are longer than 15 seconds; report duration and real-time factor per case instead of comparing all cases to a 15-second latency target.

The scoring tokenizer splits on non-letter/non-number characters and lowercases text. It does not normalize spoken numbers to digits. WER uses ordered Levenshtein alignment and counts substitutions, insertions, and deletions; it can exceed 100%. Empty references have no WER denominator; inserted non-speech words are reported separately. Overall WER is weighted by reference word count, not an average of percentages.

Expected facts are conservative full-phrase checks with explicitly listed acceptable alternatives and forbidden phrases. They expose selected omissions or unwanted substitutions, but cannot establish clinical equivalence or detect every invented fact. Negation and corrections can produce deliberate phrase-review flags; a flag needs human review, not automatic rewriting. Changes to facts/aliases require review with the case reference and audio.

All fixtures and references must be listed in the manifest. Missing files, extra files, duplicate IDs, path escapes, unsupported audio, or checksum changes fail validation. Real model evaluation is opt-in; ordinary tests use fake processes and generated temporary WAV files.

On 2026-10-22, reference review corrected facts assigned to the wrong cases (cardio_11 and cardio_12) and a false forbidden-vessel phrase in cardio_10. Selected size, drug, device, and imaging checks were also added. Audio and reference text stayed unchanged. A regression test now requires each curated fact to match its own reference without a forbidden phrase. This checks fixture consistency; it does not audit the audio or prove clinical equivalence.
