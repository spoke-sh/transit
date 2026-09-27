# transit-board-client

Typed resource client for Board's inspection and optional Table query APIs, exposed in the workspace as
`@rey/transit-board-client`. This is the browser's first
shared TypeScript package, independent of React and Router; it is not a Transit
execution/signing client. [Zig transit-board-api](../../zig/transit-board-api/README.md) owns the
[OpenAPI contract](../../../contracts/transit-board-v1.openapi.json).

`just transit-board::generate` derives TypeScript models, JSON schemas and standalone AJV
validators. `just transit-board::contract` detects drift, including validator declarations.
Validation executes without runtime `eval`, so the production content-security
policy can forbid it. Numeric IDs are checked against JavaScript's safe integer
range, values use Transit's lowercase hex representation, and unknown fields or
malformed tagged unions are rejected. A type assertion never replaces validation.

The small transport wrapper exposes `capabilities` and
`read(resource, pid?, continuation?, signal?)`. Inspection fetches are GET-only and manage
no Board credentials. Same-origin credentials can support deployment-managed
ingress; Board issues no cookies. Requests use no redirects/cache, a four-second
timeout, and a streaming 256 KiB decoded-response
limit. Consumers own refresh/backoff and lifecycle; they must discard assembled
pages on `QueryExpired`/`HistoryReclaimed`, clear sensitive views on denial, and
label connection failures instead of returning empty data. API errors are typed
`BoardError` values, distinct from empty authorized results.

## Reading state resources

`readState(resource, id?, continuation?, signal?)` validates the state response
at runtime. `resource` is `resources`, `associations` or `entries`. For
`associations`, the ID is a PID; for `entries`, it is a resource ID. `resources`
without an ID lists authorized metadata, and with an ID reads one resource.

```ts
import { readState } from "@rey/transit-board-client";

const page = await readState("resources");
const visible = page.observation.resources.filter((resource) => resource !== null);
```

Values remain exact hexadecimal bytes. Resource metadata grants and entry-read
grants differ; a denied entry read does not erase unrelated authorized process
views. Follow `next` with its original cut; never combine pages after a cut
expires. Recognized framework enrichment preserves source evidence and does not
decode application values.

[src/index.ts](src/index.ts) owns transport and error handling. Generated types,
schemas and validators live beside it; edit the Zig owner and generator rather
than patching their output.

Dependencies are installed with `vp` from the root pnpm workspace. Generated
models/schemas/validators are committed; the generator deliberately supports only
the JSON Schema vocabulary emitted by the shared Zig writer and fails on unknown
types. Unit/runtime and real-browser checks live with Board web; API fixtures and
independent Python consumers live in `tests/board.py`.

## Growing atlas and queries

`records(resource, cursor?, signal?)` reads up to eight record identities and
recognized exchange metadata from a growing resource. It requires the configured
inspection principal's current resource read grant. A continuation carries the
original resource revision and a lowercase hexadecimal key of 1–32 bytes;
revision changes require an explicit refresh. `validateRecords` checks source
alignment and canonical full-width unsigned decimal strings after generated
schema validation. The response never includes raw values or captured bodies.
Consumers must clear displayed records on read errors and recheck authority when
returning to a hidden view. The actual generated validator is also exercised
against real HTTP captures by `tests/board_records_client.mjs`.

`httpMetadata(resource, exchange, signal?)` fetches the explicitly selected
exchange's allowlisted HTTP metadata. Exchange IDs, policy IDs/revisions, times
and byte counts use exact unsigned decimal strings. `validateHttp` checks those
values, descriptor/member keys, terminal order and the final coverage reference
after generated schema validation. The route loads only selected metadata members;
it does not download a body or independently replay the full transcript.

`atlas(cursor?, signal?)` reads bounded growing catalogs. `query(operation,
signal?)` posts a Zig-owned query operation to the separately configured route.
Both validate every response. `validateQuery` additionally checks typed cell
alignment, exact int64 range, UTF-8/binary bounds, row coverage and continuation.
It never interprets opaque KV bytes. Query strings are not parsed or executed in
TypeScript. Frozen submission tokens remain opaque strings and stay in memory
for an exact retry; the transport retries only pre-dispatch rate refusals.

The real generated validator is exercised against service responses by
`tests/board_query.py`; the actual browser proof checks exact integers,
Canvas/Browse state and clearing after live revocation. No browser seed,
automatic replacement submission or persistent result storage exists.
