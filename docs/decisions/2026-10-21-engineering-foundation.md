# Adopt a Swift engineering foundation

Date: 2026-10-21
Status: accepted by the user as the engineering-foundation implementation scope.

Adopt a short agent guide, focused conventions, matching indexes, explicit document authority, and one local/full CI check. Adapt INAB and SuChef's intent to Swift rather than copying TypeScript rules or web/database infrastructure. Reference projects do not govern this repository.

Use Swift 6 contracts/concurrency, swift-format for layout, selected SwiftLint rules, tested repository policies, and pinned checksum-verified development tools. Add four compiler-enforced targets with the first source PR: core, adapters, app, benchmark. Keep real-model benchmarks local and deterministic tests independent of models.

The user chose hosted CI on PR readiness and manual request. Later pushes/base updates require fresh evidence. No remote branch protection or spending settings are implied. See [verification](../verification.md) for actual enforcement and limits.

The foundation is stacked on the planning PR. Application features remain in the five application PRs. This trades a small initial tooling cost for reproducible checks and clear boundaries; add more custom analysis only for a demonstrated gap.
