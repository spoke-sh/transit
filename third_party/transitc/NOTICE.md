# Source attribution and extraction basis

Compiler, workspace, source contracts, fixture families, independent grammar/type
comparisons and test capture helpers originate in the
[Transit repository](https://github.com/spoke-sh/transit), commit
`e7434306334e3692c6f3e123cba0d278fa412196`. The transitc repository retains its
existing LICENSE. Original source attribution is preserved here; the Transit
checkout has no root LICENSE file. File movement does not transfer protocol or
SQL authority from Transit. Shared modules are consumed from the exact pin in package manifests.

Extraction changes package wiring, executable identity and the command name.
SQL bytes, mappings, definition identifiers and migration formats remain current
v1. Expected provenance differences are only `compiler_revision`,
`compiler_digest` and `input_digest`; parity tests compare everything else.
The workspace renderer fixes a borrowed-slice lifetime exposed by Debug builds:
text now borrows the caller's diagnostic envelope instead of a callee stack copy.

Formal models retain their premises. Grammar correspondence, bounded Lean laws,
compiler comparisons and runtime integration are separate evidence categories.
No previous Transit run is reported as a transitc result.
