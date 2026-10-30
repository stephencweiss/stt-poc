# Run pinned local and hosted checks

Status: required working standard. Automated enforcement is listed in [verification](../verification.md).

tooling.json owns Xcode/Swift versions, minimum Python runtime, runner image, and tool versions/download checksums. Use setup-dev.sh --install-tools for explicit downloads into ignored .tools. Do not upgrade tools implicitly. Commit Package.resolved when dependencies exist.

swift format owns layout. SwiftLint checks the enabled correctness/complexity rules and the Logger-only custom rule in .swiftlint.yml, with strict findings and complexity limit 10. Narrow suppressions need a reason/review. Never weaken a check solely to make a change pass. Checks do not rewrite or stage files.

Run ./scripts/check.sh --quick for staged data safety plus document/Swift checks. Run ./scripts/check.sh before requesting review. Missing required tools fail with setup instructions. Full checks include repository policy tests, installed lint rule tests, shell/workflow validation, and fixture integrity. App build/test/package checks become mandatory once Package.swift exists; Swift source without a package fails.

Enable the lightweight local hook explicitly with setup-dev.sh --hooks. Existing hooks are preserved. Partial staging is allowed; safety reads index blobs, while format/lint inspect current source. Do not silently stash, stage, reset, or discard unrelated work. Hooks can be bypassed and do not enforce merges.

Hosted CI runs on ready_for_review and explicit workflow_dispatch, not on every push. Readiness runs test the proposed merge commit. Manual runs resolve an open PR in this repository to its current head/base/merge revision. After any head/base change, request another run; stale results are not acceptance evidence. See docs/verification.md for current status and manual dispatch bootstrap limits.

Pin action commits, use read-only permissions, one macOS job, timeouts, and cancellation. Do not upload session data or model caches. Branch protection and account budget settings are separate remote configuration; never claim they are enabled without evidence.
