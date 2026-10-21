# Keep clear targets and reuse boundaries

Status: required working standard. Automated enforcement is listed in [verification](../verification.md).

Use four targets: STTCore for pure logic, validated types, protocols, formatting, and scoring; STTAdapters for microphone, process, local model transport, and file implementations; STTPractice for the Mac app; STTBenchmark for the CLI.

STTCore depends only on Swift/Foundation. STTAdapters depends on STTCore and required Apple frameworks. The app and benchmark depend on both. The package graph enforces target direction once application PR 1 creates it. File-level boundaries remain reviewed: views call session actions; executable composition constructs concrete adapters.

Group real files by feature within targets. Name a file after its type or job. Keep related small private types together. Keep helpers with their owner; search before adding one. Extract shared code for a clear responsibility, not a possible future caller. Do not add Utils.swift or a global mutable service registry.

Use protocols at replaceable side-effect boundaries, not for every type. Keep engine details inside named adapters such as WhisperCppTranscriber. Inject only dependencies needed to control behavior.

Copy useful reference code into this project and adapt/test it; preserve applicable attribution. No symlinks or runtime links to another checkout. Do not build database/authentication layers until required.
