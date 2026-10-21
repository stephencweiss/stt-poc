# STT POC

A local macOS practice app for free-form cardiology dictation, editing, copying, and an optional local Clean Up Transform. Application code is not implemented yet.

Read the [document guide](docs/README.md) for accepted scope, plans, and verification status.

## Development

Apple Silicon macOS, Xcode 26.2 / Swift 6.2.3, and Python 3.11+ are required. Exact tool versions and verified archive checksums are in tooling.json. No Node runtime or paid service is required for the foundation.

```sh
./scripts/setup-dev.sh --install-tools
./scripts/setup-dev.sh --hooks
./scripts/check.sh
```

Setup downloads only missing/mismatched tools into ignored .tools; it does not download speech/language models. Use ./scripts/setup-dev.sh to verify an existing setup, ./scripts/check.sh --quick for fast checks, and ./scripts/format.sh for explicit Swift formatting. Checks do not stage files. App launch and benchmark commands will be added with application code.

## Conventions

- [Maintain conventions and indexes](docs/conventions/writing-conventions.md)
- [Keep clear targets and reuse boundaries](docs/conventions/structure-and-reuse.md)
- [Use clear Swift contracts and errors](docs/conventions/swift-and-interfaces.md)
- [Own concurrent work and resources](docs/conventions/concurrency-and-resources.md)
- [Test behavior and version regression inputs](docs/conventions/testing-and-fixtures.md)
- [Verify model and prompt changes](docs/conventions/model-changes.md)
- [Run pinned local and hosted checks](docs/conventions/quality-checks.md)
- [Keep private data out of Git and logs](docs/conventions/private-data.md)

## CI

[Verification](docs/verification.md) owns check status and manual CI instructions. CI runs when a PR becomes ready for review, or by manual request; new commits and base changes require a fresh run. Local hooks and passing old checks do not block unsafe merges.
