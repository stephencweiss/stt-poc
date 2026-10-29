# Local practice checks

Status: manual checks for the usable dictation app. Record results on the target Mac. Automated tests do not establish microphone or pasteboard behavior.

- [x] Basic microphone → transcription → edit → copy trial. The user confirmed completion on 2026-10-29; this does not complete the detailed checks below.
- [ ] Run ./scripts/run-local.sh. Check that the app opens and local paths pass setup.
- [ ] Deny microphone access. Check the error and recovery instructions. Allow access in System Settings and retry.
- [ ] With networking off, record a fictional catheterization, PCI, and TAVR note. Stop, compare raw text with edited text, and check values, units, side, drugs, uncertainty, and negation.
- [ ] Edit the note. Copy it into TextEdit. Edit again and check that the app asks for another copy.
- [ ] Select New Note. Check that it clears the old note before a new recording.
- [ ] Cancel during recording and transcription. Check that no late result appears. Record again.
- [ ] Record silence and very quiet speech. Check empty/near-silent errors; this is an energy check, not speech detection.
- [ ] Run through the 120-second limit. Check that the complete recording is processed once.
- [ ] Disconnect the input device during recording. Check the error or device behavior and retry. Check the recording ending for lost words.
- [ ] Quit while recording and while transcribing. Check that capture, child processes, and temporary session files are removed.
- [ ] Simulate a crash and relaunch. Check abandoned-session recovery without removing another running session.
- [ ] Record without changing any export setting. Check that export is available after transcription and no audio/reference export files appear until requested. Export once, listen to the WAV, and audit the saved reference. Select New Note and check that the old sample is no longer available. Quit and relaunch; check that no sample returns.

Use fictional text only in shared reports. Record microphone/device, macOS version, observed failures, and timing. Formatting, global hotkey, floating panel, automatic copy, and Clean Up are outside this slice.
