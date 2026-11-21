# Transit SQL frontend

`transit_sql_frontend` owns the pure SQL syntax, logical value/type contracts,
scalar and program binding, Table schema evolution, and ordered SQL verification
shared by Fuze and offline source compilers. It was separated from `transit-fuze`
without changing SQL syntax, limits, encodings or the current contract definition.

Direct dependencies are `transit-memory`, `transit-protocol` and `transit-spatial`.
The frontend has no Arrow, query scan, storage, filesystem, service or network
dependency. Callers supply bytes, schemas, allocators and explicit bounds. Parsing
or binding establishes neither runtime authorization nor successful execution.

`ApplicationProgram.Types.bindForAnalysis` accepts at most 64 immutable public
scalar parameters for offline specialization checks. They do not add Queue
fields or resource dependencies; ordinary record, expression and resource limits
still apply. Parameters cannot shadow the input alias or Queue columns, carry
protected values, or introduce record fields. Failure handlers retain these
constants but cannot read body locals. The returned binding owns its parameter
descriptors. Native installation uses `bind`, which rejects unresolved names;
the analysis API does not supply runtime values or executable parameter syntax.
After successful binding, `ApplicationProgram.Predicate.validateForAnalysis`
checks Queue filters with the same scalar parameters. Boolean parameter leaves,
logical operators and parameter/literal atoms use the existing native profile
and 64-instruction budget without adding fields or inventing sample values.
Concrete atoms retain native collation checks. Selected programs must still pass
ordinary predicate validation and compilation after replacing parameters.

Fuze reexports these public types to keep one module identity for existing
consumers. Its `ApplicationProgram` facade adds expression/cursor execution;
`LogicalQuery` adds the pull executor. Those runtime composition helpers and
cross-component Arrow tests remain with Fuze. Shared finite-column and plan-byte
limits live here and are consumed by both sides.

Run `zig build test` inside this package with the pinned development shell. Tests
exercise pure parsing, codecs, logical semantics, type checking and allocation
ownership. Run the Fuze and compiler suites as well when changing shared owners.
These checks do not qualify a storage provider or live service.
