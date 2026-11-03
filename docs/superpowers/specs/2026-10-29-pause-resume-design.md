# Buffered transcription with pause and resume

Status: revised draft for user review. Design only; the app still records a complete file and transcribes after Stop.

## Goal and delivery boundary

Let the operator record a note, pause during interruptions, resume, and finish one complete note. Process speech segments while recording when configured to do so. Keep results in an ordered transcript buffer until Finish publishes the note for editing.

The user first requested a pause/resume design on 2026-10-29, then proposed continuous speech selection and transcription with a final publication step. This revision replaces the earlier recommendation to pause one AVAudioRecorder file and defer all processing until Finish. Pause/resume belongs within the shared capture pipeline; it is no longer a separate prerequisite implementation.

Keep PR #5 focused on its current implementation. This design is stacked on `codex/light-formatting` at `f0ab3cd`, on branch `codex/pause-resume-design` in the same worktree. Do not implement application changes as part of this design request. The broader pipeline needs the evaluation gates below before detailed implementation plans are approved.

## Current behavior and terms

The current app uses AVAudioRecorder, converts its finalized file to a canonical WAV, launches whisper-cli once, then formats the result. Its energy check rejects an empty or near-silent recording. It does **not** strip silence, run a VAD model, remove background noise, or identify the intended speaker.

| Term | Meaning in this design |
|---|---|
| Capture gate | Accept audio only while the operator has recording enabled |
| Voice activity detection (VAD) | Estimate which audio intervals contain speech; keep short padding around detected speech |
| Speech segment | A bounded audio interval ready for one transcription job |
| Transcript buffer | Ordered raw segment results owned by the unfinished note; not an editable final note |
| Finish | Close capture, flush pending audio, complete queued jobs, assemble text, format once, then enable editing/copy |

VAD selects likely speech; it does not remove noise mixed with speech or reject a colleague's conversation. Dedicated noise reduction and speaker identification are separate features. Pause is the explicit control for excluding an interruption.

## Options and recommendation

| Approach | Benefit | Cost or limit |
|---|---|---|
| Pause one file; transcribe after Finish | Smallest change to the current app | Full recognition wait remains after Finish; no shared online speech segmentation |
| **One segmented pipeline with selectable processing time — recommended** | The same capture, VAD, queue, buffer, and finalization support both processing during capture and after Finish | Adds bounded audio handoff, segmentation, ordered jobs, and boundary evaluation |
| Continuously replace a live editable transcript | Immediate text feedback | Adds unstable text, overlap reconciliation, and edit conflicts; outside this request |

Use the second approach. It gives a simpler operator workflow, but it is more engineering work than native pause/resume alone. Streaming does not remove recorder ownership, cancellation, device validation, or timing requirements.

The two processing schedules are configuration/test modes, not two capture implementations or an initial UI mode picker:

- **During capture:** submit each completed speech segment to the worker immediately. Buffer completed results until Finish.
- **After Finish:** collect the same segments, then run the same worker queue after capture closes. This provides a comparison mode and an explicit resource-saving choice, without changing the finalization contract.

The existing whole-file transcription path remains a regression baseline during development. Do not present the new after-Finish segmented mode as equivalent to that baseline until measured. Do not switch schedules or recognition engines silently after a failure.

## Data flow and controls

```text
Microphone
  → capture gate (Record / Pause / Resume)
  → bounded PCM handoff and conversion
  → VAD and speech segmentation
  → bounded, ordered transcription queue
  → raw transcript buffer
  → Finish barrier: close input, flush tail, drain jobs
  → assemble raw text → format once → edit → copy
```

**Record → Pause/Resume as needed → Finish → edit → Copy Note**

- Record creates one note identity and starts accepting microphone samples.
- Pause closes the capture gate at a defined sample boundary and acknowledges that boundary to the UI. Samples after it must not reach VAD, segment files, export audio, or recognition context. Clear any pre-roll that could reintroduce the paused conversation on Resume.
- Audio accepted before Pause remains valid. Flush its pending speech tail once; previously queued transcription may continue while the app is paused. Pause does not cancel valid jobs or clear their text.
- Resume opens a new capture interval within the same note after input checks. Start fresh VAD/pre-roll state, while preserving queued jobs and ordered text from earlier intervals.
- Show Recording or Paused separately from processing status, such as a pending-segment count. A paused microphone does not imply an idle model worker. Use explicit states, not loosely related Boolean flags.
- Keep partial text internal in the first version. No live editor, copying partial results, or Clean Up while recording. A read-only preview can be designed later.
- Finish works from Recording or Paused. Stop accepting audio first, flush the last accepted speech, close the queue, wait for all required results, then publish raw and formatted text once. If the worker has kept up, the remaining wait should be shorter; it is not guaranteed to be zero.
- Label the final action **Finish**. Status explains remaining processing. Rename internal finalization actions where needed so Stop does not incorrectly imply that transcription starts only then.
- New Note, setup changes, and the export preference stay disabled while an unfinished note owns audio or jobs. Cancel discards the entire unfinished note. Quit drains cancellation and cleans owned files. Neither operation publishes partial success.

Pause cannot remove audio already accepted before its acknowledged boundary. If the operator pauses after a colleague starts speaking, that earlier speech may already be in the note. This design does not add retrospective deletion.

## Capture and segmentation

AVAudioRecorder's finalized-file flow does not expose the PCM stream this pipeline needs. Introduce an AVAudioEngine-based capture adapter with a bounded audio handoff. Keep VAD, conversion, file writes, and inference off the realtime callback and main actor. Do not read a growing CAF file as an undocumented streaming interface.

The callback copies into preallocated bounded storage and reports overflow through the owner. It must not allocate large buffers, block, write files, or call a model. A worker consumes accepted PCM in order and converts it to the rate/format required by VAD and transcription. An overflow stops acceptance and reports an incomplete note; it must never silently drop words.

Use a real local VAD adapter for speech selection. An amplitude threshold alone is not a substitute. Apply configurable leading/trailing speech padding, an end-of-speech delay, and a maximum segment length. Silence does not create a transcription job. Continuous speech must still split at the maximum length rather than wait indefinitely for silence.

Start with nonoverlapping speech segments where possible. Coalesce overlapping padded ranges within a capture interval so the same source samples are not submitted twice. At forced maximum-length boundaries, evaluate context padding and timestamp-based ownership before choosing a rule. Do not remove repeated words by string matching: meaningful repetition, repeated values, and corrections must survive. Short final fragments, quiet words, and statements split by Pause/Resume require explicit tests.

VAD can miss speech. Keep the original accepted audio temporarily under the note owner until successful finalization or discard, so a failed processing job can be retried and opt-in export can be checked against speech selection. Export the accepted recording across active intervals, excluding explicit pauses; do not export only VAD-selected audio as if it were the original. Keeping original audio is temporary resource ownership, not default persistent retention.

## Queue, buffer, and model lifetime

Assign each segment an immutable note ID, segment ID, sequence number, capture-interval ID, and accepted-audio range. Use a single serialized recognition worker initially. Store results by sequence number and assemble them in source order, never completion order. Separate raw assembly from deterministic formatting; format the complete note only at Finish so partial headings and number phrases are not repeatedly rewritten.

Bound PCM memory, segment size, queued audio, and total accepted audio. Temporary segment files belong to one session directory; the queue holds bounded metadata, not unlimited PCM arrays. If the worker falls behind and a bound is reached, stop accepting new audio and show a clear paused/error state. Resume only after capacity is available and the operator chooses it. No silent discard, indefinite backlog, or automatic resumption of the microphone.

The current WhisperCppTranscriber starts a fresh process and loads its model per request. It can support a limited file-segment experiment through the existing engine interface, but it is not evidence of an efficient streaming worker. Measure startup cost, throughput, and combined capture/VAD/model memory before choosing production integration. Prefer retaining one loaded recognition model for the note or app when the chosen engine supports it.

Evaluate a resident whisper.cpp integration against the planned WhisperKit path before committing to that extra adapter work. The v1 migration comparison remains in docs/TODO.md; this design does not implicitly approve it or require building both production engines. Keep engine choice behind a replaceable boundary. No hosted service or API charge is required. Verify existing VAD assets first; a separate local VAD download may be needed, with size/license/version checked before setup.

## State, failure, and cancellation rules

| Situation | Required behavior |
|---|---|
| Recording while a segment is transcribing | Capture continues within queue bounds; the UI does not enter its current exclusive Transcribing state |
| Paused while earlier jobs complete | Keep valid results for this note; do not restart capture |
| Finish races with Pause, VAD flush, or a late job | Close input once; enqueue each accepted tail once; await an explicit final segment count before publication |
| Cancel or New Note after cancellation | Invalidate the note revision, cancel workers, reap child processes, then clean files; reject old results |
| One segment fails or times out | Pause capture, show an incomplete-note error, and retain owned inputs/results for explicit Retry or Cancel; do not publish a successful final note with a gap |
| Retry succeeds before Finish was requested | Return to Paused with valid results and remaining jobs; the operator chooses Resume or Finish |
| Retry succeeds after Finish was requested | Keep capture closed and continue the existing Finish barrier; do not enable Resume or reopen segment production |
| Queue or callback overflow | Stop capture and report incomplete audio; do not offer a retry that claims to recover dropped samples |
| Fatal capture/write failure | Report incomplete audio and stop work; cleanup follows explicit discard or quit; no automatic success from earlier text |
| No speech selected | Return an explicit no-speech result, not a fabricated note |

Use one retained session coordinator to own capture, segmentation, queue, and finalization. The capture actor owns source boundaries and cumulative time. Worker actors own conversion/VAD/inference and their resources. Represent capture phase separately from segment processing state within the unfinished-note state. Keep the view limited to rendering and actions.

Note identity remains stable across pauses. Capture-interval generations reject stale meters and capture callbacks. Valid jobs from earlier intervals must still be accepted: pausing must not invalidate the whole note revision. At Finish, close segment production and record its final sequence/count. Preserve this finalization intent through errors and retries. A failed finalization may retry work but cannot become a resumable recording. Publish only after every required result succeeds. Error, cancellation, and stale-result paths cannot overwrite later notes or trigger copying.

## Input, time, and resource policy

- Require the same verified system input UID and compatible format across Resume. A display name is insufficient. If input verification fails, remain Paused and keep prior audio/results. The operator can restore the input or Finish the existing note; Finish must not require a connected microphone.
- Keep the current shared 120-second allowance for this first implementation. Count accepted capture time, including quiet time while Recording, but exclude explicit pauses. VAD removal does not grant extra recording time. This bounds both supported schedules and preserves the current short-note scope.
- Track time from accepted sample counts rather than wall time. Segment timestamps map to that accepted-audio timeline, with separate capture-interval identities for pauses. At the limit, close capture and use the Finish barrier once.
- Each segment has a processing timeout; the note also needs a bounded finish/drain deadline. The existing 180-second whole-file timeout must not become an accidental unlimited total of per-segment waits. Choose and test shared configuration after the throughput experiment.
- Input changes, sleep/wake, and permission interruptions require explicit handling. Never automatically resume capture after an interruption. No hardware microphone-indicator shutdown guarantee is made by the application gate.
- Keep files private and local. Successful Finish removes temporary originals/segments after producing any opted-in bounded export data. Retry retains the same owner. Cancel, discard, quit, and abandoned-session recovery cover every stage. No transcripts/audio in logs, no new saved-draft feature, and no recovery guarantee after exit.

## Proposed code boundaries

These names describe responsibilities; a detailed implementation plan will settle contracts after the evaluation gates.

| Area | Responsibility |
|---|---|
| `Sources/STTCore/Audio/` | Capture intervals, accepted sample ranges, pause/resume commands, bounded configuration |
| `Sources/STTCore/Transcription/` | Speech-segment identity, ordered transcript buffer, finalization contracts |
| `Sources/STTAdapters/Audio/` | AVAudioEngine input adapter, input UID/format checks, bounded PCM transfer, conversion, local VAD, private audio ownership |
| `Sources/STTAdapters/Transcription/` | Replaceable segment transcriber; model lifetime, timeout, and cancellation remain engine details |
| `Sources/STTPractice/` | Session coordinator, capture/processing states, Pause/Resume/Finish/Retry controls, final text publication |
| `Tests/STTCoreTests/` | Ordered assembly, ranges, segment completion, and finalization invariants |
| `Tests/STTAdaptersTests/` | Fake capture/VAD/engine boundaries, real conversion/files, queue pressure, errors, and cleanup |
| `Tests/STTPracticeTests/` | Control states, pause boundaries, pending jobs, Retry, Finish, Cancel, late results, copy/export |
| `Sources/STTBenchmark/`, `Fixtures/Benchmark/`, `docs/benchmarks/` | Versioned segmentation/VAD evaluation and comparison to the existing whole-file baseline |

Reuse formatting, clipboard, file-safety rules, and engine interfaces where suitable. Do not duplicate the note editor or add a second independent session workflow. Update implemented workflow documentation only when the pipeline works.

## Evaluation gates and delivery sequence

1. **Audio/VAD experiment:** verify bounded live PCM capture and conservative speech segmentation. Test accepted-audio and paused boundaries with synthetic inputs, then opt-in fictional microphone recordings. Replay the same inputs with VAD on/off. Check quiet speech, short negations, values at boundaries, long speech without silence, background noise, and another speaker. VAD is not a privacy or accuracy guarantee.
2. **Recognition experiment:** replay identical segmented audio in both schedules and compare with the committed whole-file baseline. Measure raw WER, critical factual errors, segment-boundary omissions/duplication, first-load cost, throughput, peak memory, backlog, and Finish latency. Version VAD model/settings, segmentation rules, prompts/context policy, engine, and model identities. Exact equivalence between schedules requires fixed decoding/context inputs; do not assume it.
3. **Engine decision:** determine whether the existing CLI is adequate for the experiment and which resident engine should support the implementation. Evaluate the WhisperKit migration here if it avoids building a temporary resident adapter. Record a decision before dependency/model setup. Downloads remain explicit.
4. **Implementation planning:** write separate reviewable tasks for bounded capture/segmentation, queue/buffer/finalization, and operator controls. Deliver one working vertical slice at each step; do not implement the old native-pause-only design first. Keep the existing app path usable until replacement acceptance.
5. **Verification:** failing tests before each behavior change; ordinary checks use fake clocks/capture/VAD/models and real temporary files. Run full local/hosted checks for each final PR head/base. Include failure and Retry during Finish: input must stay closed and the original final segment count must remain fixed. Live microphone and real-model evaluations are explicit, not CI prerequisites.
6. **Operator trial:** record → pause during a fictional interruption → resume → finish → review → edit → copy, offline. Export an opted-in original and verify it excludes paused speech but includes quiet accepted speech. Check Finish while paused, a slow/failing worker, Retry, queue pressure, maximum duration, quit, sleep/wake, and late callbacks. Record observed limits before acceptance.

This is a broader replacement design, not a promise of one small pause/resume implementation PR. Keep it stacked above PR #5; choose implementation PR boundaries after the experiments. No package installation, model download, live recording, or recognition benchmark has been run as part of writing this revision.

## References and exclusions

The [whisper.cpp VAD documentation](https://github.com/ggml-org/whisper.cpp#voice-activity-detection-vad) describes speech selection before recognition and a separate VAD asset. Its [streaming example](https://github.com/ggml-org/whisper.cpp/tree/master/examples/stream) demonstrates periodic recognition, but labels its VAD implementation basic. These are capability references, not a tested integration for our Swift app or a reason to adopt its microphone loop.

Excluded: live editable partial text, automatic speaker identity, removing noise mixed with speech, retrospective removal of an interruption, adding audio after Finish, long-session guarantees, saved drafts, cloud services, and automatic microphone resumption. A final full-note model cleanup remains the separately planned Clean Up Transform.
