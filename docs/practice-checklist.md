# Local practice checks

Status: manual checks for the usable dictation app. Record results on the target Mac. Automated tests do not establish microphone or pasteboard behavior.

The user reported a successful basic microphone → transcription → edit → copy trial before formatting planning. The detailed checks below remain separate; that report does not establish that each scenario was tested.

- [ ] Run ./scripts/run-local.sh. Check that the app opens and local paths pass setup.
- [ ] Deny microphone access. Check the error and recovery instructions. Allow access in System Settings and retry.
- [ ] Select the required device in System Settings → Sound → Input. Start recording and check the displayed system input name. Stop before changing inputs. Repeat with the built-in and wireless microphones.
- [ ] Enable export and record more than 30 seconds of fictional speech. Listen to the full exported WAV and compare it with Raw transcript. If markers replace speech, report whether the missing words are audible in the WAV.
- [ ] With networking off, record a fictional catheterization, PCI, and TAVR note. Stop, compare raw text with edited text, and check values, units, side, drugs, uncertainty, and negation.
- [ ] Edit the note. Copy it into TextEdit. Edit again and check that the app asks for another copy.
- [ ] Select New Note. Check that it clears the old note before a new recording.
- [ ] Cancel during recording and transcription. Check that no late result appears. Record again.
- [ ] Record silence and very quiet speech. Check empty/near-silent errors; this is an energy check, not speech detection.
- [ ] Run through the 120-second limit. Check that the complete recording is processed once.
- [ ] Disconnect the input device during recording. Check the error or device behavior and retry. Check the recording ending for lost words.
- [ ] Quit while recording and while transcribing. Check that capture, child processes, and temporary session files are removed.
- [ ] Simulate a crash and relaunch. Check abandoned-session recovery without removing another running session.
- [ ] Leave export off. Check that no audio/reference export appears. Enable it before another note and export once. Listen to the WAV and audit the saved reference.

Use fictional text only in shared reports. Record microphone/device, macOS version, observed failures, and timing. Global hotkey, floating panel, automatic copy, and Clean Up remain outside this slice.

## Formatting trial

Status: pending user trial. The earlier successful basic dictation trial predates formatting.

- [ ] Dictate a free-form fictional note. Check that no section labels or paragraphs are inferred from clinical meaning.
- [ ] Dictate the same note with bare headings such as `Findings.` and with optional `heading findings`. Compare the unchanged raw transcript and formatted editor output. Check ordinary narrative uses of heading words too.
- [ ] Check `sixteen french sheath`, `twenty six millimeters`, and an unsupported range/decimal phrase. Check values, laterality, negation, uncertainty, and device variants against what was spoken.
- [ ] Edit formatted text. Copy into TextEdit; check that manual spaces and words stay as edited. Export if selected and check the saved reference against the edited note.

These manual checks depend on the engine returning recognizable heading markers. Pure formatter tests use known transcript strings and do not establish speech-recognition accuracy.
