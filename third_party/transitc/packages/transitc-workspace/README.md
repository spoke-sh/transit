# transitc-workspace

`transitc_workspace` captures confined source files, resolves pinned repositories,
checks transitive locks and overrides, and publishes complete SQL/provenance or
migration artifacts. Build evaluation never opens a SQL client. Only explicit
fetch accesses repositories; ordinary builds use verified local caches.

`Sources` owns input I/O and resolution; `Migration` reads immutable prior basis
and history; `Build` composes these with the pure compiler. `Options`, `Report`,
`Style` and `Diagnostic` implement bounded invocation and human presentation.
The caller supplies its compiler revision. Executable identity is SHA-256 over
all executable bytes, separate from release version and contract definition.

The public build adapter accepts a diagnostic context structurally so Transit
can retain its broader CLI diagnostic state while sharing source presentation.
The compiler itself never imports this package. See the [package map](../README.md)
for standalone pins and the explicit embedded-module contract.

Run `zig build test` here and root `just test-workspace`. The workspace suite
exercises actual subprocesses, offline socket refusal, locks, hashes, overrides,
path confinement, diagnostics, corrupted artifacts, interrupted publication and
immutable migration histories. Its seccomp controls currently require Linux.
Runtime host tests remain with Transit.
