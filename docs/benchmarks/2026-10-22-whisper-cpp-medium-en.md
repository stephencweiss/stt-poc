# whisper.cpp medium.en local baseline — 2026-10-22

All 30 inferences completed with exit status 0. The file-transcription pipeline works with network access denied. Accuracy still fails important value, drug, and terminology checks. Use this as a comparison baseline; the user chose on 2026-10-22 to build the practice app first and compare WhisperKit after the first trial. Do not use formatting or Clean Up to conceal recognition errors.

## Run and identity

- 15 fixed cases, prompt off and on, one trial per setting: 12 fictional human recordings, two non-speech controls, one synthetic voice case.
- Apple M3 Pro, 36 GiB RAM, macOS 15.7.7; installed whisper.cpp 1.8.3 and `ggml-medium.en.bin`.
- Source: `ef0ae8a53034096ebaef3e1e732007b50b8a9eec`, clean working tree when measurement started.
- [Full report](2026-10-22-whisper-cpp-medium-en.json): exact manifest/model/executable SHA-256, arguments, vocabulary prompt/version, per-case text, scores, procedure groups, and times.
- [Memory observations](2026-10-22-whisper-cpp-medium-en.memory.json): sampled every 0.5 seconds. Peak engine CPU resident memory was 2.11 GiB; peak benchmark-plus-engine was 2.63 GiB. These exclude GPU allocations and can miss short peaks.
- The lid stayed open. `caffeinate -i` prevented idle sleep during the run. Active and elapsed wall time were both about 66 seconds, including validation, hashing, and sampling overhead.
- The benchmark and child processes ran under `sandbox-exec` with `(version 1)(allow default)(deny network*)`. A separate Python socket-bind test under that policy failed with `Operation not permitted`. This tests process-level offline operation without changing system network settings.

Repeat from the repository root with a fresh report filename:

```sh
/usr/bin/caffeinate -i /usr/bin/sandbox-exec \
  -p '(version 1)(allow default)(deny network*)' \
  .build/debug/STTBenchmark --report .local/new-baseline.json
```

Build first with `swift build -Xswiftc -warnings-as-errors`. The installed speech model is required; the command does not download it. The sandbox command was used for this evaluation, not added as an app dependency. Memory observations came from polling `ps -axo pid=,ppid=,rss=,comm=` for the benchmark and its direct engine child.

## Results

| Measure | Prompt off | Prompt on |
|---|---:|---:|
| Completed inferences | 15/15 | 15/15 |
| Raw weighted WER, all 13 spoken cases | 22.03% | 19.16% |
| Raw weighted WER, 12 human recordings only | 22.48% | 19.44% |
| Median transcription time, all cases | 1.61 s | 1.60 s |
| Maximum transcription time | 3.62 s | 6.63 s |
| Median real-time factor | 0.170 | 0.167 |
| Selected phrases absent | 17/43 | 11/43 |
| Forbidden phrase flags | 1 | 1 |
| Inserted tokens on silence/noise controls | 4 | 3 |

The first invocation took 1.65 seconds. Each call starts a new process and reloads the model; these are not resident-model warm times. Earlier attempts had already used the model, so this is not a cold-cache startup measurement. Model startup is not measured separately. The 6.63-second case was a 32.87-second recording. The observed times are below the plan's discussion targets, but microphone stop-to-text time is not measured here.

WER splits punctuation and does not normalize number words to digits: `twenty six` and `26` count differently. It includes harmless notation changes as well as errors. Silence/noise have no WER denominator; their inserted tokens are separate. The synthetic voice case is not human-accuracy evidence. References are inherited and still need an independent word-by-word audio audit.

## Output review

The following table records differences from the references in the prompt-on output. These are review findings, not an independent audio audit. All prompt-on and prompt-off outputs were inspected; the JSON retains their full text.

| Case | Reference or expectation | Prompt-on result and remaining issue |
|---|---|---|
| cardio_01 | diagnostic cath, right radial, no complications | Matches the reference; the prompt removes the prompt-off `path` error. |
| cardio_02 | six French sheath | `sixth French sheath`; selected size phrase fails. |
| cardio_03 | planned TAVR, transfemoral access | `trans femoral` is an accepted spacing variant; timing of the planned procedure remains. |
| cardio_04 | mid-LAD, 2.5 by 18 mm drug-eluting stent | `mid lab`, `2.85`, `drug-eluting scent`; wrong value and terms. |
| cardio_05 | SAPIEN valve, femoral site, no hematoma | Selected phrases pass; number notation differs. |
| cardio_06 | IVUS, FFR 0.92, heparin bolus | Selected phrases pass, but `heparin bolts` differs from the reference. |
| cardio_07 | bivalirudin, lithotripsy, recovery | `valvudine`; adds `and two more` and changes the ending to `patient tumor properly`. The prompt improves some terms but also introduces these changes. |
| cardio_08 | Evolut, Impella, clopidogrel | `evolute`, `impeller`, `glaucoma`; also changes valvuloplasty, ProGlide, large-bore access, and manual pressure wording. |
| cardio_09 | Watchman, right femoral vein, protamine | Selected access/device phrases pass, but `bromine` replaces protamine; stroke prophylaxis wording also changes. |
| cardio_10 | RCA treatment, LAD FFR 0.75, PCI tomorrow morning | Value/vessel checks pass; `cardio`, `warning`, and missing `morning` change the plan wording. |
| cardio_11 | spoken correction to minor bleeding, radial site, sheath size six | Selected phrases pass. Filler/punctuation differ; the spoken correction remains. |
| cardio_12 | circumflex, IVUS, stent | `stem` replaces stent. |
| silence / noise | Empty reference | `[BLANK_AUDIO]` / `[static]`; prompt-off noise is `(water splashing)`. These are nonempty outputs and require handling before a note workflow. |
| tavr_gradient | 26 mm valve, mean gradient 4 mmHg, negative leak/obstruction | All four selected phrases pass; number and device-name notation differ. Synthetic voice only. |

Prompt on is the better measured comparison baseline for aggregate WER and selected phrases, but it is not uniformly better. Case cardio_07 gets worse. A passed phrase check does not prove that the rest of a note is correct; cardio_06 is an example. No setting is accepted for unattended note generation.

## Fixture correction and limits

The first awake diagnostic run exposed expected facts assigned to the wrong cases in cardio_11/cardio_12, and an incorrect forbidden `LAD` phrase in cardio_10. These were corrected against unchanged references before this final run. Critical size, drug, device, and imaging phrases were added, plus the spacing alias `trans femoral`. The new reference-consistency test first failed on five assertions, then passed after correction. No audio or reference was changed to improve model scores.

The corrected manifest hash identifies this baseline; the earlier diagnostic fact counts are superseded. The phrase checks cover selected facts only. Quiet speech, background conversation, microphone capture, true cold-cache startup, and an independent reference audit remain untested. Model/engine improvement and non-speech handling are needed before the practice workflow is accepted.
