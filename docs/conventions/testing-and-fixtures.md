# Test behavior and version regression inputs

Status: required working standard. Automated enforcement is listed in [verification](../verification.md).

Use XCTest for application tests initially. For new executable logic and defects, observe a focused test fail for the expected reason, implement the behavior, then refactor while it passes. Documentation, formatting, and visual-only changes need appropriate review rather than mirrored tests.

Test visible behavior and errors, not private methods or a copy of the code. Use fake process/transport boundaries and real temporary files. Control clocks instead of sleeping. Do not share mutable test directories or live pasteboard state across parallel tests.

Ordinary tests must not require models, Ollama, live microphone input, private data, or model downloads. Explicit model evaluation fails when required assets are missing; no silent skips.

Version reviewed fictional audio, references, expected facts, origin, categories, and manifest checksums under Fixtures/Benchmark/. Manifest version 1 has a nonempty cases array; each case has id, audio, reference, audioSha256, referenceSha256, category, origin, and expectedFacts. Paths are relative to the manifest and must stay inside its directory. Every audio/reference file must be listed; unlisted files fail. Quick checks validate index blobs, not a possibly different working copy. Commit canonical converted inputs; do not regenerate them during tests.

Review fixture content and expected results together. Never change a reference merely to match a model error. Commit reviewed baseline reports under docs/benchmarks/ with dataset/source/model/prompt/settings/hardware identities. Keep scratch runs ignored. Collect coverage as evidence, not a substitute for meaningful failure-path tests.

Add docs/agent/feature_map.json when a workflow exists, documenting real commands/controls, prerequisites, results, source/tests, and manual steps. No empty map or fabricated automated UI evidence.
