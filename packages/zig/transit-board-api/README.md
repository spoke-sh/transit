# transit-board-api

The typed Board v1 response contract, exported as `transit_board_api`. Depends only on
[transit-protocol](../transit-protocol/README.md). It does not read stores, execute
handlers, or authenticate viewers; the Board executable composes those boundaries.

`try project(page)` rejects malformed mixed-resource or inconsistent
continuation pages before interpretation. It preserves the original authorized inspection page and
adds explicit causal references. Input-to-turn, turn-to-effect, turn-to-output,
and delivered output-to-admission links come from recorded fields. References
below the retained floor are marked reclaimed, never reconstructed.

`projectState(page)` preserves authorized resource/association metadata and
bounded opaque entries, rejecting mixed projections. Resource read grants are
separate from metadata grants. M7 removes the application counter lens and its
response field; Board contains no application state decoder.

`zig build transit-board-contract` at the repository root generates the
[OpenAPI 3.1 contract](../../../contracts/transit-board-v1.openapi.json) using the shared
Transit schema writer. Board output fields are required, and integers are bounded
to JavaScript's exact safe range. This is a resource inspection contract, not
an alternate Transit mutation or signature protocol.

From this directory, `zig build test` checks projection boundaries and causal coverage.
From the repository root, `just test::packages` checks the declared dependencies.
