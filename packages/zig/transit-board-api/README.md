# transit-board-api

The typed Board v1 response contract, exported as `transit_board_api`. Depends on
[transit-protocol](../transit-protocol/README.md) and
[Station's metadata codecs](../transit-station/src/Metadata.zig), plus
[transit-query](../transit-query/README.md) for the optional query contract and
[transit-exchange](../transit-exchange/README.md) for capture metadata. It does not read stores, execute
handlers, or authenticate viewers; the Board executable composes those boundaries.

`try project(page)` rejects malformed mixed-resource or inconsistent
continuation pages before interpretation. It preserves the original authorized inspection page and
adds explicit causal references. Input-to-turn, turn-to-effect, turn-to-output,
and delivered output-to-admission links come from recorded fields. References
below the retained floor are marked reclaimed, never reconstructed.

`projectState(page)` preserves authorized resource/association metadata and
bounded opaque entries, rejecting mixed projections. Resource read grants are
separate from metadata grants. M7 removed the application counter lens and its
response field; Board contains no application state decoder. M9 adds a bounded
`framework` array of recognized versioned declarations: GenServers, Tables,
registry scopes/bindings, supervised children, calls and captured Arrow results.
Every lens carries its writer PID, resource, exact key/revisions and observation
position. Only an authorized entries read can produce these lenses. Unknown or
malformed versions remain opaque; names and executable code IDs never select a
decoder. These inspection projections do not interpret Table rows or Arrow data.
The separately authorized query route returns verified typed Arrow cells through
the shared query client.

## Public API and extension workflow

| Export | Meaning |
| --- | --- |
| `Response` / `project` | One authorized inspection page plus bounded recorded causal edges |
| `StateResponse` / `projectState` | One authorized state page without business-value interpretation |
| `AtlasResponse` | Growing process/resource pages and the current inspection identity at one cut |
| `RecordsResponse` / `projectRecords` | Eight growing record identities and recognized exchange metadata, with exact source evidence |
| `QueryRequest`, `QueryResponse` | Optional Table query operations, opaque frozen submissions and verified typed pages |
| `Json.write` | Schema-consistent JSON: fixed byte arrays stay arrays, text slices stay strings |
| `Capabilities`, `Error` | Board build capabilities and its finite error vocabulary |
| [export.zig](src/export.zig) | OpenAPI generation over the public typed definitions |

All projections are deterministic and have no I/O, credential or cache ownership.
Array bounds are part of the wire contract; missing history remains an explicit
coverage value. A new framework projection must preserve source evidence and
unknown-version fallback without broadening authorization.

The growing records projection exposes keys/revisions and allowlisted capture,
obligation, lineage and attempt-budget fields. It omits raw values, captured
bodies and immutable adapter context. Unknown records retain their identity with
no decoded detail. Recognition requires the exchange key namespace and canonical
versioned codec; descriptor ownership must match the resource writer. Full-width
exchange, policy and count fields use canonical unsigned decimal strings. These
records describe committed framework evidence, not proof of remote execution or
permission to dispatch. HTTP timing, omission and root endpoint policy views are
not implemented yet.

Change the types/projection and tests here, then run `just transit-board::generate`
and `just transit-board::contract` from the repository root. Update service
routing and frontend validation in the same change. The experimental v1 API has
had deliberate removals; the [Board migration guide](../../../apps/transit-board/docs/configuration.md#migrating-the-experimental-board-v1-profile)
and app state section record them.

`zig build transit-board-contract` at the repository root generates the
[OpenAPI 3.1 contract](../../../contracts/transit-board-v1.openapi.json) using the shared
Transit schema writer. Board output fields are required, and integers are bounded
to JavaScript's exact safe range. Query int64 cells use decimal strings; opaque frozen tokens preserve signed
requests without JavaScript parsing their full-width literals. The query route
exposes only the [public query profile](../../../contracts/PUBLIC_QUERY_V1.md),
not arbitrary Transit commands.

From this directory, `zig build test` checks projection boundaries and causal coverage.
From the repository root, `just test::packages` checks the declared dependencies.
