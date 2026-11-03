# Keep the current recording in memory for export

Status: accepted. The user explicitly approved implementation on 2026-10-29 in the PR #4 review chat.

## Decision

Keep the current successful recording in memory by default so the user can choose to export after transcription. Remove the pre-recording retention toggle. Saving audio.wav and reference.txt still requires an explicit export action and a selected local destination.

This replaces the pre-recording opt-in in the usable dictation plan and the earlier no-retention default in the POC plan. The user approved the proposed behavior with: “please implement this change.”

## Ownership and limits

The app requests export bytes through the existing capture contract. The session retains them only for a usable note. Temporary recording files are still removed after processing, cancellation, or failure. New Note, cancel, or quit releases session audio. A restart does not restore recordings. Existing abandoned-file cleanup remains in place.

An export selected before New Note owns an independent audio/text snapshot until that export completes. Explicitly saved files remain at the selected destination. This change does not add history, automatic exports, benchmark registration, or model training.

The 120-second recording limit bounds the audio retained in memory. This uses more memory than discarding audio after transcription, but lets the user decide to save a useful test case after hearing or reviewing the result.

## Verification

Session tests cover export without prior selection, release on New Note and shutdown, cancellation with a late result, unusable output, and an export snapshot selected before New Note. Adapter tests retain coverage of temporary-file cleanup. The manual checklist covers export and restart behavior in the packaged app.
