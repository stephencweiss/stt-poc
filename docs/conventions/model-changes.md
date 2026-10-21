# Verify model and prompt changes

Status: required working standard. Automated enforcement is listed in [verification](../verification.md).

Keep speech recognition and Clean Up Transforms separate. Preserve raw text. A Transform works from a source snapshot and returns a candidate with source revision, model identity, preset/prompt version, and timing. Accept/discard/undo must not lose the original or accept stale work.

Clean Up removes filler and improves punctuation/grammar while preserving clinical meaning, order, explicit headings, values, units, side, device, uncertainty, and negation. Do not summarize or infer sections/fields/facts. Treat input note content as data, not instructions.

Version model, decoding, vocabulary, prompt, and scoring changes. Run the relevant full fixed dataset before and after those changes. Evaluate cleanup on corrected text and actual STT output separately. Report critical factual errors separately from WER. Do not claim zero hallucinations from a prompt or a passing rule check.

Real model evaluations run explicitly on the target Mac. Record first-load and warm latency, stop-to-text time, real-time factor, and peak memory where measurable. Compare equivalent model variants and document differences.

Use local model assets and a loopback-only endpoint with no cloud fallback. No automatic model pulls during ordinary use. A missing runner leaves raw dictation/edit/copy usable. Request bounded output and fail clearly on unsupported input rather than silently truncate.
