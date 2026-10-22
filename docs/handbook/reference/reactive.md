# Sessions, watches and live views

The reactive API supplies resumable notifications and exact snapshot refresh for
catalog Tables with two INT64 columns and a single-column primary key on the
first column. General Table storage and finite queries admit broader schemas. A notification says the source may have
changed. It is not a new query result, every intermediate row change or a
continuous SQL engine.

Use [OpenAPI](openapi.md) for fetch-SSE, [AsyncAPI](asyncapi.md) for WebSocket and
the [shared TypeScript client](../../../packages/ts/transit-reactive-client/README.md)
for runtime-validated browser ownership and scheduling.

## Session and attachment identity

A durable session belongs to a caller/service scope. A subscription binds its
source; an attachment generation fences a particular transport consumer. Signed
cursors preserve integrity and progress, not permission. Every protected release
rechecks current native/service/source rights, lease and generation.
Session-status reads return session state under the current service policy and
omit the Table declaration. Discovery, snapshots and events additionally require
current database CONNECT, schema USAGE and Table SELECT privileges.

The initial profile bounds active work to four live sessions per service, two per
caller and one subscription per session. Lease advancement requires authenticated
monotonic observer input and respects process/resource lifetimes. Old closed
history can remain durable without occupying those active slots.

Losing a connection does not close a session or cancel its accepted commands.
Expiry requires explicit reopening; a restarted gateway cannot renew the old
lease automatically. Owners may close their own live work after read-policy
revocation without gaining source data through that cleanup operation.

## Snapshot and watch handoff

Acquire the declared catalog metadata/schema, Table-head watermark and first page at
one exact resource revision through the shared operation. Reading "latest" and
subscribing later loses changes between the two requests. A `more` flag sends
larger snapshots through the existing finite query reader.

Preserve resource, source contract/schema and data-watermark evidence. Do not
compare incompatible positions or treat framework bookkeeping as row changes.
Missing retained coverage returns reset or interruption; it never silently
pretends the stream remained continuous. A cursor does not extend a released
query pin or the source's history lifetime. The watermark is the native revision
of the published Table-head entry. Head reservations or no-op completions can
signal possible change; staged rows remain invisible. Query bookkeeping and
changes to other Tables do not advance this head. Database CONNECT, schema USAGE and Table SELECT are checked for the
authenticated caller and selected role on each observation and again before
release. A cursor or open attachment retains no permission. ALTER/DROP
or a different metadata commitment requires an explicit new snapshot; a watch
never follows a reused name.

## Refresh a displayed result

Keep the submitted plan/schema/source generation fixed. Each refresh receives a
new finite query identity and captures the actual available source basis; no
arbitrary executable `AS OF` operation is implied. While it runs, retain one
latest unsubmitted invalidation. Only proven coverage clears that dirty position.

The refresh owner retains Follow’s original native admission, including its
credential epoch and selected role. Each continuation checks current source
privileges and includes them in the native publication guard. Rotation or
revocation cannot be bypassed by a self-message or restart. The owner copies the
original submitted bundle and verifies its commitment before execution. A result's bound plan fingerprint includes its
captured source basis and can change across refreshes. Compare source resource,
contract and schema across the generation, and require the full manifest to
remain identical across pages of each individual finite result.

Verify the complete ordered result through bounded pages, discard each verification
page and reread the visible page from that same immutable result. Recheck current
authorization on the reread. Replace rows and summaries together only after
verification; a late response cannot replace a newer generation.

On denial, clear protected candidate and displayed state. Temporary unavailability
does not become an empty result. A reset requires an explicit authorized snapshot.
Show the last exact basis and refresh status while writes continue; the profile
does not promise every revision or an unmeasured latency bound.

A rejected control includes the original expected and observed generation,
attachment, subscription or lease when available. Explicit closure and lease
expiry have distinct reasons. A reached deadline can coexist with a recorded
`open` phase until an expiry control commits. Inspect that retained phase before
assuming a quota slot is free. The browser preserves the original control reason
and separately reports any later current-scope failure; denial clears protected
state. Neither diagnosis causes an automatic replacement session or command.

Follow status retains the original scheduling stop independently of the selected
query outcome. It distinguishes explicit pause, closure or expiry, exhausted
budget, changed source, unavailable resources, authority denial, occupied
namespace and rejected/cancelled/retired queries. A query failure includes its
own original code and witness. Restoring permission or closing the session does
not rewrite the earlier stop or restart the generation. The browser keeps the
last exact result on non-authority failures and shows the retained detail; current
denial still clears protected state.

A disconnected view retains the diagnostic from its interrupted stream or failed
attachment read while reconnecting the same session. Source unavailability does
not establish permission revocation: the already disclosed snapshot keeps its
original basis, with no replacement coverage claimed. Reconnection progress does
not overwrite the failure with generic advice.

Failed Follow reader checks identify the identity field or permission mask,
resource writer/lifecycle, or template phase and missing manifest. The diagnostic
retains the policy/resource revision observed at that check. Native read failures
identify the operation, principal and actual failing resource; their original
cause remains available even when the scheduling stop is classified more broadly
as resource unavailability. These details come from the failed operation, not a
later lookup after policy or data has changed.

## Budgets and transport

Follow uses one active refresh and bounded coalesced work per admitted scope,
with fairness for consumers sharing a query principal. The current owner permits
eight selected intents per explicit Follow generation. That finite budget also
limits durable control history; lease expiry alone does not remove old receipts.

Pause, hide and close stop new scheduling/renewal through explicit lifecycle
controls. Accepted work remains independently observable. Follow retains its
submitted plan when SQL is edited. The separate
[finite draft budget](queries.md#finite-draft-evaluation) permits evaluating
complete edits after explicit enablement; it does not reset Follow or provide
speculative partial execution or incremental continuous results.

SSE is a signed POST fetch stream, not `EventSource` GET. WebSocket uses the
`transit.reactive.v1` subprotocol and the configured challenge bootstrap; there
are no URL credentials. Connection-local challenges need the same gateway until
consumed, and portable cursors require the configured shared signing identity.
Heartbeats and successful writes do not establish application progress.

Exact messages, limits and resumption rules are in
[reactive v1](../../../contracts/REACTIVE_V1.md) and the
[client contract](../../../contracts/REACTIVE_CLIENT_V1.md). See the
[refresh owner](../../../packages/zig/transit-serving/docs/refresh.md) and
[runnable example](../../../examples/serving/docs/reactive.md) for integration.

A peer closing its WebSocket closes only that transport. Its diagnostic does not
claim that the retained session closed, its lease expired or application commands
were cancelled. Inspect the original session and saved commands through an
authorized connection. Invalid watch declarations supplied by a caller are input
errors; malformed declarations encountered during a read are integrity failures.
Neither case authorizes implicit reset or a replacement query generation.
