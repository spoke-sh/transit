# Transit inspection v1

Implemented as the additive `POST /v2/inspect` surface. Existing v2 commands,
canonical signatures and histories are unchanged. Public types and the generated
[JSON Schema](transit-v2.schema.json) are owned by
[transit-protocol](../packages/zig/transit-protocol/README.md).

## Authentication and disclosure

The body is `SignedInspectionQuery { query, signature }`. Sign
`Ed25519(SHA256("rey.transit.inspection.v1\\0" || canonical-query-json))` with the
current principal key. The domain ends in one NUL byte; canonical JSON follows
the same declared-field-order/default/null rules as commands. Reads consume no
mutation sequence, and cannot be submitted as commands.

Each query requires current realm/PID-scoped `inspect`. Discovery filters by that
scope. All resource requests authenticate before disclosing existence or cut
validity. Permission/key replacement applies to every page; continuations carry
no authority. The final unchanged-tail check authorizes one bounded response.
A concurrent commit (including revocation) returns `409 Conflict`; a later
revocation prevents the next authorization, without recalling released bytes.

`inspect` includes opaque state/message/effect bytes and payload **metadata**.
There is no separate metadata-only grant or payload-body route. Outbox entries
require both source and destination access. Incoming delivery history omits the
output ID when its source cannot be inspected. Administrative grant records,
public keys, raw journal entries and hidden process counts are never returned.
Positions, policy revisions, and retention floors are realm-wide ordering metadata
already disclosed by known-PID views; they are not per-PID event counts.

## Resources and bounds

`resource` is one of `processes`, `process`, `mailbox`, `outbox`, `effects`,
`payloads`, `history`. All except `processes` require `pid`; discovery forbids it.
Arrays have 16 nullable slots. Omitted resources have empty arrays, not implied
zero totals. Catalogs have the M1 fixed bounds; history scans at most 128 positions
and returns at most 16 matching records per request. `scanned` is scan work, not
an authorized-resource count. Responses own their bytes and fit the client/server
256 KiB bound. Authority catch-up retains its existing request deadline; the scan
budget applies to projection after catch-up, not recovery replay.

The page identifies the current reader, its permission bits and PID scope so a
consumer can refuse an overprivileged deployment credential.

`process` exposes current protocol state including activation/binding evidence.
Mailbox pages contain retained admissions, each with its disposition at the cut:
`pending`, `consumed`, or `cancelled`. History contains typed process events, with
only explicit input/effect/output links and authority clock samples when recorded.
A delivery event is an admission only when `admitted` is true. Successful turn
results are application claims, not authority-verified computation. History is a
filtered inspection projection, not a complete replay/export format.

## Cuts, continuation, and reclamation

Every page reports `{ realm, resource, pid, cut, next, complete, history }`.
`cut` contains the exclusive authority tail, current reader policy revision, and
retained floor. `after:0, cut:null` starts a query. Pass the identical resource,
PID and cut with the returned `next` as `after` to continue. These fields are all
signed. `after` is the next array slot or journal position, not a page number.
Clients must retain the query identity alongside the continuation.

M2 deliberately expires cuts on **any** authority change: `409 QueryExpired`
requires discarding the partial assembled query and explicitly refreshing.
This avoids snapshot storage, unbounded retained versions and mixed-state pages.
A busy authority can repeatedly invalidate pagination; the caller must show that
condition and back off, not silently omit records. No historical snapshot service
or sustained-write pagination availability is promised by this bounded profile.

`complete` means no further matches at this cut. It does not mean all history
still exists. `history:prefix_reclaimed` and `cut.retained_from` expose checkpoint
coverage even on an empty page. A continuation overtaken by retention or a trim
racing storage reads returns `409 HistoryReclaimed`; start a new query and show
the gap. Unexplained missing records fail unavailable, never as empty data.
Reads do not pin history. Current state/outbox evidence can survive without its
source events, so consumers must mark unresolved historical links.

## Clients and proofs

`transit_client.Client.inspect(query, key)` returns an owned `Inspection.Page`.
`rey-cli sign-inspection SEED QUERY.json` emits the envelope;
`rey-cli inspect SEED QUERY.json URL` performs the public client call.

`just test::inspection` exercises real signed HTTP calls and disk recovery.
A shared [canonical fixture](../packages/zig/transit-protocol/src/fixtures/inspection-v1.json)
checks field ordering, the separate domain hash and signatures in Zig and Python.
Core tests deterministically inject final-tail races and trim, check scan budgets,
scoped discovery and two-endpoint links, and distinguish mailbox dispositions.
Board adds its own ingress and generated API above this contract.
