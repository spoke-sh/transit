# Transit source compiler

Pure, bounded compilation of `.transit` modules to ordinary Table SQL. The
[application source contract](../../../contracts/APPLICATION_SOURCE_V1.md) owns
syntax, visibility, supported statements and limits. The package depends on
Fuze's public typed statement owners, the protocol's diagnostics and the memory
budget allocator. It has no filesystem, network, catalog service or execution
access.

Call `compile(allocator, sources, options, &diagnostic)` with resolved, immutable
source buffers and a compiler revision. A successful `Product` owns its SQL,
statement maps and digests independently of the inputs; call `product.deinit()`.
On failure there is no product. Diagnostics are bounded values and contain no
source text or operand values. Resolution provenance enters the build digest
through `Options.resolution_digest`; supplying source never establishes trust or
runtime permissions.

Source parsing checks complete Table templates and assertion rows in every body,
including unused modules and both IF branches. `Syntax.Template` retains token
spans and typed-hole roles without inventing values or catalog bindings. Name,
type, target and schema checks retain their later stages. A proposed catalog
stages schemas in lexical composition order. Fuze checks each expanded statement;
a second catalog reparses the emitted SQL and compares ordered schema/plan
fingerprints. Temporary statement allocations use a reusable scratch arena;
retained schemas and output use the product arena. Both allocators share one
stable `transit-memory` budget. Inputs have separate aggregate/file bounds.

`SourceTypes` owns nominal scalar identity, closed constructor payloads and exact
Table interfaces. `TypedOperands` binds source annotations to Fuze-owned target,
column and parameter spans. Nominal values stay typed alongside temporary SQL
parameters until the check succeeds; final scalar SQL emission then records the
checked assignments/predicates. The `Step.checked` projection is in-memory evidence;
installed artifacts still contain ordinary SQL and existing provenance fields.
All Table spellings use the annotation catalog. A raw ID cannot enter a nominal
column just because the underlying SQL type agrees.

MATCH checking forks proposed catalogs and uses typed symbolic payloads for every
arm. Only the selected arm emits steps/actions or contributes schema definitions.
Symbolic callees check scalar parameter types and both symbolic IF paths;
recursive edges check signatures. Symbolic schema/export changes and non-exact
physical parameter coercions reject. Transient Fuze preparation uses the shared
scratch arena, and retained branches count against the existing product budget.

`Format.write(text, file, writer)` writes source from a parsed `Syntax.File` to
a caller-bounded writer. Keep the immutable source and AST allocator alive for
the call. It performs no I/O or allocation, omits comments, preserves quoted SQL
bytes and token adjacency, and prints expressions with precedence-preserving
parentheses. Output exhaustion and expression/body depth beyond 64 fail; a
partial writer buffer is not a complete formatted artifact. Source coordinates,
digests and expansion-position-derived case identities may change after formatting;
explicit runtime bindings, ordered SQL and logical test expectations do not.
This facility adds no formatter CLI command.

The [independent source grammar](../../../contracts/application-source/README.md)
and its private verification executable compare source ASTs, exact UTF-8 byte
coordinates, source round-trips and compiled products. ANTLR and its Python
adapter are verification tools, not package or installed-runtime dependencies.

The package `test` step exercises recursive higher-order construction, typed
arguments, source visibility, explicit object bindings, deterministic emission,
ordinary SQL verification, budget exhaustion and cleanup at every allocation
failure. These tests do not execute SQL or qualify a runtime deployment.

`Options.mode = .test_suite` selects a `CREATE TEST TARGET` (normally `tests`).
The owned product contains independent cases with ordinary SQL, statement maps
and typed runner expectations. Every case uses the same production evaluator,
working catalog, emitter and independent SQL verification. Compilation executes
no SQL. Row expectations use exact schema-bound value encodings with duplicate
multiplicity; they do not depend on physical ordering or SQL collation equality.

`test::application-source-types` checks three scoped Lean laws and independent
finite comparisons of source selection, typed Table/domain/operand records and
ordinary SQL. See the [verification owner](../../../tests/query/application_source/README.md)
for premises, tool pins and negative controls. The
[synthetic typed-target fixture](../../../tests/fixtures/application-typed-targets/README.md)
is executed separately by real build/test CLI checks.
