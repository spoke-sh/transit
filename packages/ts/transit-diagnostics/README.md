# Transit diagnostics for browser callers

`@rey/transit-diagnostics` owns the TypeScript validation and rendering of the
shared [diagnostic contract](../../../contracts/DIAGNOSTICS_V1.md). Query,
application and reactive callers use this library directly.

`ownedDiagnostic(value)` copies and validates optional detail, including the
current contract definition, exact decimal integers, UTF-8 byte bounds,
evidence/outcome combinations and recovery action targets. An invalid detail
returns `{ invalid: true }`; it does not replace a primary transport error or
a committed domain outcome. Absent detail returns `{ invalid: false }`.

`diagnosticLines(diagnostic)` formats validated detail for a caller-facing view.
It escapes supplied fact text and preserves unavailable facts. Diagnostic text
is neither a logging payload nor a retry policy; callers decide whether current
authorization still permits displaying it.

The generated declarations and CSP-compatible validator come from the Zig-owned
`contracts/diagnostic-v1.schema.json`. Regenerate with
`just transit-board::generate`. `just transit-board::check` runs strict types,
formatting, validation and rendering tests alongside its consumers.
