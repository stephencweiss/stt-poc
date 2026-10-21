# STT POC

A local macOS practice app for free-form cardiology dictation, editing, copying, and an optional local Clean Up Transform. The first build includes a setup window and a local file-transcription benchmark. Live microphone recording, formatting, and Clean Up are later application PRs.

Read the [document guide](docs/README.md) for accepted scope, plans, and verification status.

## Development

Apple Silicon macOS, Xcode 26.2 / Swift 6.2.3, and Python 3.11+ are required. Exact tool versions and verified archive checksums are in tooling.json. No Node runtime or paid service is required for the foundation.

```sh
./scripts/setup-dev.sh --install-tools
./scripts/setup-dev.sh --hooks
./scripts/check.sh
```

Setup downloads only missing/mismatched tools into ignored .tools; it does not download speech/language models. Use ./scripts/setup-dev.sh to verify an existing setup, ./scripts/check.sh --quick for fast checks, and ./scripts/format.sh for explicit Swift formatting. Checks do not stage files. Run the setup window with `./scripts/run-local.sh`. Record remains disabled in this baseline build. The window checks file paths; it does not initialize the model. Custom paths entered there do not change CLI options.

## Local benchmark

```sh
swift run STTBenchmark --report .local/baseline.json
```

This runs 15 fixed cases with the vocabulary prompt both off and on (30 local inferences). Every call launches whisper.cpp and loads the model; total wait can be several minutes. No model download or network service is used. Reports include fictional fixture text; do not publish reports made from private recordings.

Defaults are /opt/homebrew/bin/whisper-cli and /opt/homebrew/share/whisper-cpp/ggml-medium.en.bin. Override them with `--executable PATH` and `--model PATH`. Use `--manifest PATH`, `--prompt off|on|both`, and `--repetitions 1...10` as needed. Run `swift run STTBenchmark --help` for usage. Use a fresh report filename; existing reports and the fixture directory are protected from accidental overwrite. Invalid setup or any failed case returns a nonzero exit instead of skipping a case.

Read [fixture provenance and scoring](Fixtures/Benchmark/README.md) before changing the suite. Baseline analysis will be stored under docs/benchmarks/. Real-model evaluations run locally; CI builds, tests, checks fixture integrity, and packages the app without a model or microphone.

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
