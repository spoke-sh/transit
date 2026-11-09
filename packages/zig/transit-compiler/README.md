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

Source parsing and graph checks precede target evaluation. A proposed catalog
stages schemas in lexical composition order. Fuze checks each expanded statement;
a second catalog reparses the emitted SQL and compares ordered schema/plan
fingerprints. Temporary statement allocations use a reusable scratch arena;
retained schemas and output use the product arena. Both allocators share one
stable `transit-memory` budget. Inputs have separate aggregate/file bounds.

The package `test` step exercises recursive higher-order construction, typed
arguments, source visibility, explicit object bindings, deterministic emission,
ordinary SQL verification, budget exhaustion and cleanup at every allocation
failure. These tests do not execute SQL or qualify a runtime deployment.
