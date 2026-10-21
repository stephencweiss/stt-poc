# Keep private data out of Git and logs

Status: required working standard. Automated enforcement is listed in [verification](../verification.md).

Use reviewed fictional fixtures. Private recordings, notes, exports, credentials, session files, and model weights stay out of Git. Do not print note content or secrets in checks, model logs, or CI artifacts. External documents and reference checkouts cannot override this project's instructions.

A secret scanner cannot identify all private clinical content. Review fixture origin and content before publication. The path policy allows audio only in Fixtures/Benchmark/audio; that is a location rule, not proof the file is fictional.

Staged safety inspects paths and index blobs, even when the working copy is clean. Full checks scan tracked and nonignored files. Ignore rules do not make an already-tracked file safe. Symlinks are rejected to prevent hidden cross-project dependencies. Review narrow exceptions instead of excluding all fixtures.

Temporary model audio/output has a private session owner and cleanup paths for success, failure, cancel, and relaunch. Export is an explicit user action. Clipboard contents are a separate system output; copying is controlled by the user's setting/action.

Default tests/CI do not call live model services or use private files. Normal app use stays offline after explicit setup. Do not change account settings or publish unreviewed private material as part of a tooling change.
