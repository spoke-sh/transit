# transit-board-api

The typed Board v1 response contract, exported as `transit_board_api`. Depends on
[transit-protocol](../transit-protocol/README.md) and
[Station's metadata codecs](../transit-station/src/Metadata.zig), plus
[transit-query](../transit-query/README.md) for the optional query contract and
[transit-exchange](../transit-exchange/README.md) and
[transit-station-http](../transit-station-http/README.md) and
[transit-station-grpc](../transit-station-grpc/README.md) for capture metadata, plus
[transit-station-document](../transit-station-document/README.md) for accepted Document metadata. It does not read stores, execute
handlers, or authenticate viewers; the Board executable composes those boundaries.

`try project(page)` rejects malformed mixed-resource or inconsistent
continuation pages before interpretation. It preserves the original authorized inspection page and
adds explicit causal references. Input-to-turn, turn-to-effect, turn-to-output,
and delivered output-to-admission links come from recorded fields. References
below the retained floor are marked reclaimed, never reconstructed.
Effect pages also carry an optional diagnostic per original effect slot. The
shared native owner projects retained authorization, observation and closure
provenance after record validation. Optional diagnostic construction failure
leaves the primary effect visible; current-access checks remain on the read.
The browser validates detail against the effect identity, phase, policy, count,
deadline and clock, retaining primary observations when optional detail fails.

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
| `RecordsResponse` / `projectRecords` | Eight growing record identities and recognized Exchange/Document/query metadata, with exact source evidence |
| `Query.Lens` / `Query.decode` | Canonical finite capture/manifest records without SQL, application rows or access tickets |
| `HttpResponse` / `Http.project` | Selected HTTP policy/timing/omission/completion metadata and its committed member references |
| `GrpcResponse` / `Grpc.project` | Selected RPC shape/schema, directional counts, half-close and terminal evidence without protobuf interpretation |
| `DocumentResponse` / `Document.project` | Accepted identity, profile, revision, retained floor and bounded register conflict counts, without field or text values |
| `UnifiedQueryRequest`, `UnifiedQueryResponse` | Optional v1 scoped SQL, finite upload, frozen retry and nested pages through `transit-query.Workspace` |
| `Json.write` | Schema-consistent JSON: fixed byte arrays stay arrays, text slices stay strings |
| `Capabilities`, `Error` | Board build capabilities and its finite error vocabulary |
| [export.zig](src/export.zig) | OpenAPI generation over the public typed definitions |

All projections are deterministic and have no I/O, credential or cache ownership.
Array bounds are part of the wire contract; missing history remains an explicit
coverage value. A new framework projection must preserve source evidence and
unknown-version fallback without broadening authorization.

The `queries` lenses recognize canonical public v1 query capture and manifest
keys through Station's owning codecs, checking the recorded writer/destination
or source resource. Full-width correlations, policy revisions and counters use
canonical decimal strings; native resource/PID revisions retain safe integers.
They retain exact record provenance. Recorded phase, row
count and segment count are evidence about the capture, not proof of current
result access or complete retained coverage. The result reader checks those
separately; unknown versions and malformed records remain opaque. Reading these
lenses does not enable Board's separately authorized query execution route.

The growing records projection exposes keys/revisions and allowlisted capture,
obligation, lineage and attempt-budget fields. It omits raw values, captured
bodies and immutable adapter context. Unknown records retain their identity with
no decoded detail. Recognition requires the exchange key namespace and canonical
versioned codec; descriptor ownership must match the resource writer. Full-width
exchange, policy and count fields use canonical unsigned decimal strings. These
records describe committed framework evidence, not proof of remote execution or
permission to dispatch. The separate HTTP projection exposes frozen endpoint
revision, TLS/trust digest, bounds and followup policy references, plus timing,
omission counts and completion metadata. It omits routing values and secret
references. Full-width times/counts stay decimal strings. Each selected member
retains its exact key, ordinal, digest and chain under the descriptor's source cut;
this is not a full transcript replay or a decoded application body.

Change the types/projection and tests here, then run `just transit-board::generate`
and `just transit-board::contract` from the repository root. Update service
routing and frontend validation in the same change. The
[Board compatibility guide](../../../apps/transit-board/docs/configuration.md#board-v1-compatibility)
and app state section describe schema changes and client update requirements.

`zig build transit-board-contract` at the repository root generates the
[OpenAPI 3.1 contract](../../../contracts/transit-board-v1.openapi.json) using the shared
Transit schema writer. Board output fields are required, and integers are bounded
to JavaScript's exact safe range. Query int64 cells use decimal strings; opaque frozen tokens preserve signed
requests without JavaScript parsing their full-width literals. The query route
exposes only the [public query profile](../../../contracts/UNIFIED_QUERY_V1.md),
not arbitrary Transit commands.

The `/api/v1/query` route has its own generated schemas. Dynamic
row/column/path/conflict arrays are bounded to eight, and full-width counts,
identities and scalars remain strings. Atlas identifies the configured query
version only when its resource appears in the authorized inspection page.
Query configuration and grants remain separate from the inspection identity.

From this directory, `zig build test` checks projection boundaries and causal coverage.
From the repository root, `just test::packages` checks the declared dependencies.

## Document inspection

The `documents` record lenses recognize canonical SDH1 heads at their exact
Document key. Unknown/malformed versions remain opaque. The selected Document
route projects accepted revision/epoch, type and change format, retained floor,
opted-in merge window, pending job and permanent retirement. Full-width Document
identities and counters remain decimal strings. Head source evidence includes
writer, exact key, entry/resource revisions and authority position.

Register counts cover at most eight retained registers, including detached and
deleted history; they are not visible-field or whole-Document totals. Continuation
requires the original resource revision and an opaque exclusive index key.
Changed cuts fail explicitly. Retirement keeps head metadata inspectable while
withholding register reads. This maps the shared Document read contract; it adds
no administrative capability or runnable Document SQL syntax.

`ParticipationResponse` is a separate growing-profile metadata surface, leaving
`AtlasResponse` unchanged. It contains one selected resource, at most eight PID
contributions and independent resource/process/association positions. Nullable
`process_position` marks an explicit single-PID association read. `matches`
counts only this authorized association page; `next` on a member indicates
incomplete PID coverage, while top-level `next` continues the process scan. No
value bytes, names of hidden associations, global count or traffic rate is
inferred. The host performs only public client reads. See the
[Atlas guide](../../../apps/transit-board/docs/application.md#bounded-atlas-evidence)
for cursor and failure semantics.

`InspectionDiagnostic.project` classifies failed public read attempts separately
from write outcomes. It retains the native cause and distinguishes missing capture
members, invalid coverage, protocol mismatch, decoding failure and inspector
capacity. It supplies no domain receipt or replay authorization. The host attaches
this envelope only to read routes; query/application submission uses its owner.
