# Session state ownership

Status: implementation guide. The transition rules are executable code, not a duplicated Markdown table.

[PracticeState.next(after:)](../Sources/STTPractice/PracticeState.swift) owns allowed state/event transitions. It returns the next state or nil for a rejected event. [PracticeStateTests](../Tests/STTPracticeTests/PracticeStateTests.swift) checks every state/event pair against independently defined expectations.

[SessionModel](../Sources/STTPractice/SessionModel.swift) routes all state changes through one transition helper. Rejected actions must return before starting effects. The model owns task execution, recording and note data, and cleanup. [SessionModelTests](../Tests/STTPracticeTests/SessionModelTests.swift) checks real action sequences with fake external services.

State transitions alone cannot identify stale results. The revision token rejects old task results, recordingID rejects events from another recording, and closed prevents further work after shutdown. Text and configuration guards remain in the model. The microphone service has separate recorder and file ownership state. MainActor serializes access; it does not replace these rules.

When behavior changes, update the transition contract and its tests together. Keep cancellation, failure cleanup, and repeated or late events in the integration tests.
