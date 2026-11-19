# Package boundaries

| Package | Responsibility | Direct shared imports |
| --- | --- | --- |
| [transitc-compiler](transitc-compiler/README.md) | Source syntax, graphs, types, lowering, verified SQL, migrations and test products | `transit_sql_frontend`, `transit_protocol`, `transit_memory` |
| [transitc-workspace](transitc-workspace/README.md) | Captured source, exact dependencies, locks, publication and human reports | Compiler plus the same three shared modules |

The CLI composes these libraries. The compiler performs no filesystem, network,
service or runtime execution. Workspace I/O is explicit; repository access occurs
only during fetch. Runtime test execution stays in Transit.

Transit owns `transit-sql-frontend`, protocol values (including diagnostic envelopes,
JSON, definition identity and resource contracts), spatial values and the memory
budget allocator. No second SQL type system or allocator lives here. Compiler
`SourceDiagnostic` adds source failure families over the shared diagnostic values.
The reserved diagnostics/SQL packages were removed because these owners suffice.

Standalone manifests pin the generated pure source archive at
`97d796fb0cf7203c869fd57ed6f45fe3935edd71` with its Zig content hash. The upstream
runtime fixture remains independently frozen at `e7434306334e3692c6f3e123cba0d278fa412196`.
The archive contains only the four pure packages and a small composition manifest.
Its generator verifies exact source bytes and deterministic archive contents.
Runtime and Arrow packages are absent from the distribution.

Embedded builds select `-Dembedded=true` and supply the canonical frontend,
protocol and memory modules. This path does not resolve the standalone shared
source dependency. Transit uses this path so compiler and runtime types have the
same identity. Thus the selected package graph is acyclic: Transit embeds compiler
sources; the standalone compiler selects the pure frontend distribution. Neither
build imports the other repository's runtime build or development flake. All
remote source choices are immutable; no sibling checkout is an input.

See [attribution](../NOTICE.md), [architecture](../docs/handbook/internals/architecture.md)
and the [embedding guide](../docs/handbook/guides/embedding.md).
