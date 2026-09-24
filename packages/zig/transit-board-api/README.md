# transit-board-api

The typed Board v1 response contract, exported as `transit_board_api`. Depends only on
[transit-protocol](../transit-protocol/README.md). It does not read stores, execute
handlers, or authenticate viewers; the Board executable composes those boundaries.

`try project(page, mappings)` rejects malformed mixed-resource or inconsistent
continuation pages before interpretation. It preserves the original authorized inspection page and
adds explicit causal references. Input-to-turn, turn-to-effect, turn-to-output,
and delivered output-to-admission links come from recorded fields. References
below the retained floor are marked reclaimed, never reconstructed.

A static `rey.example.counter` v1 lens interprets decimal example state only with
an explicit PID mapping. Its result includes operator provenance and the source
state revision. Unknown versions and malformed bytes retain the kernel view;
no handler is called and no lifecycle/permission fact is replaced.

`zig build transit-board-contract` at the repository root generates the
[OpenAPI 3.1 contract](../../../contracts/transit-board-v1.openapi.json) using the shared
Transit schema writer. Board output fields are required, and integers are bounded
to JavaScript's exact safe range. This is a resource inspection contract, not
an alternate Transit mutation or signature protocol.

From this directory, `zig build test` checks lens fallback and causal coverage.
From the repository root, `just test::packages` checks the declared dependencies.
