# Use clear Swift contracts and errors

Status: required working standard. Automated enforcement is listed in [verification](../verification.md).

Use Swift 6 language mode. Prefer structs, enums, and let for data. Describe mutually exclusive states with enum cases and associated values, not independent Boolean flags. Use Optional for one clear absence; use enums when loading, failed, and absent differ.

Validate external data at adapter boundaries. Codable does not validate ranges, finite timestamps, sample rates, or required semantic fields. Return useful typed errors from async/I/O failures. Use Result only when it clarifies the contract.

Do not use forced casts, try!, or force unwraps in production paths. Do not ignore try? errors without an explicit cleanup/recovery policy. Use narrow reviewed exceptions only when needed, with evidence.

Infer simple locals and specify API contracts. Use Swift casing for constants. Keep literals local unless naming exposes a rule or callers share the value. Do not create a global constants file.

Document non-obvious ownership, side effects, failure behavior, and constraints with ///. Use // for a useful local explanation. Do not repeat names/signatures in comments. Keep views focused on rendering/actions and decisions in testable state code.
