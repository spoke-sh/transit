# transit-client

`Session.receive` distinguishes permanent `ProcessExpired`/`ProcessTerminated`
from `StaleActivation`. Only the latter may be resolved by obtaining a valid new
activation for the same PID. A failed read or uncertain deadline is never proof
that a PID has expired.

`Client.unavailable` classifies temporary transport failures, including DNS,
connection and incomplete I/O failures. It performs no retry. Worker loops can
retry observations and exactly frozen proposals through these failures; access,
fencing, malformed responses and rejected commands remain separate decisions.

Zig caller library, exported as `transit_client`. Applications receive ordered
input and committed state, compute their own logic, and submit signed proposals.
The authority validates the protocol without executing application code.

Its package dependencies are [transit-protocol](../transit-protocol/README.md),
re-exported as `protocol`, and optional runtime instrumentation through
[transit-observability](../transit-observability/README.md), re-exported as
`observability`. It does not import the kernel, Ursula, or a provider.
[Client](src/root.zig) owns bounded native v1 HTTP exchange;
[Session](src/Session.zig) adds activation-aware receive/prepare/submit operations.
The [native caller guide](docs/growing.md) describes bounded views and retained
versions. Read [caller semantics](../../../docs/reference/callers.md) for the
language-neutral ownership boundary.

[Recorded manual worker replacement](docs/worker-handoff.md) composes native
quiescence, complete state verification, conditional fencing and credential
rotation under one authority. Hosts retain exact manager records and proposals.

## Caller guide

[Calling and recovery](docs/turns.md) explains Session, receive/prepare/submit,
resource-backed turns, current grants, owned bytes, and exact-request retries.
Start with the [counter](../../../examples/counter/README.md) for a complete
program. The library supplies protocol operations; Station owns the behavior
loop, durable waiting, and supervision.

## Public surface

| Interface | Caller responsibility |
| --- | --- |
| `Client.submit` | Sign a mutation and retain its exact request until the outcome is resolved |
| `Client.query(.process)` / `Session.receive` | Read a process and its next input under current inspection/activation rights |
| `Client.waitForChange(selector, key, hint)` | Bounded notification wait followed by a current authorized process/delivery/output query; hints can be lost or coalesced |
| `Client.query(.delivery)` | Read scoped courier status without payload or general inspection access |
| `Client.query(.inspection)` | Follow bounded process/history pages with explicit cut/expiry handling |
| `Client.query` | Discover state capabilities and read metadata, associations, entries or captured views |
| `AuthorizationClient.read` | Read current identity, roles, grants, effective access, previews and retained operations |
| `AuthorizationChange.Client` | Prepare, save, explicitly submit and observe [recoverable policy changes](docs/authorization.md) |
| `Session.prepare*` / `Pending.submit` | Freeze activation-aware proposals; no hidden retry, persistence or background loop |
| `bootstrap.awaitActivation` | Publish a fresh public key and pin the first controller-granted generation for a provider-bound worker |

The shared client accepts authority base URLs with or without trailing slashes.
It removes trailing separators before appending the operation route, preserving
the base path and its escaping. Foreign SDKs use this same transport behavior.

`Client.call` returns fixed native values. Domain responses containing strings or
collections use `callOwned`, whose parsed arena owns the complete result until
`deinit`, independently of the transport lifetime. Request and response limits
default to 1 MiB each and cannot exceed 16 MiB. This path preserves shared JSON
array shapes, rejects redirects, and drains/frees a response that races a timeout.
It performs one HTTP attempt; it does not retry uncertain work.

Each active exchange owns one bounded heap response slot. Observation and
deadline handling borrow that slot instead of copying bulk values onto the
handler's stack. Completion joins the transport before transferring the result;
timeout or cancellation joins it before freeing a raced owned response.

Each client is used by one operation at a time; sessions sharing a principal also
share its mutation sequence. A client retains at most one free HTTP connection
and discards it before a new exchange after 200 ms idle. This is below the growing
node's one-second idle-header deadline; peers may still close sooner. A failed
exchange remains a transport failure without automatic replay, including for
signed mutations. A peer may close a connection after a response.
Snapshot release and combined finish reads carry a checked control-admission
hint; signed authorization and request semantics remain mandatory.
`waitForChange` uses the service's independent wait admission with a 1–1000 ms
bound. It does not retry or cache permission. `Session.observed_position` records
the last successful process observation for idle-loop registration. Setting
`Session.idle_wait_ms` makes a receive following an empty observation combine
waiting and the next receive; a nonempty delivery clears the idle state. Zero
disables waiting. Substituted transports must implement `waitForChange` when
waiting is enabled. The position is a hint,
not a retained read cut, checkpoint or authority to execute an input.

`ResourceReader.Batches.init` and `SnapshotReader.Support.init` can share one
checked capabilities response for the same caller and connection. Each requires
its own advertised flags; only immutable protocol support is reused. The handles
cache no grants, resource metadata, values or principal sequence. Every read and
snapshot operation retains its current signed authorization, definition checks
and ordinary failure behavior after an authority restart.

`ResourceReader.Batches.cached(batch)` creates operation-local scratch for the
batch's exact resource revision. It holds at most 64 keys, including absent
entries, and coalesces up to eight misses per fetch. Eviction triggers another
signed read. Revision changes and read failures poison the scratch reader;
cached values cannot clear that failure. This object does not pin history or
supply fresh authorization: discard it after the observation and check current
permission again before disclosing a derived result.

Delivered input includes position, opaque value and
authenticated origin within the current native definition. Match the expected source PID/turn or effect attempt before interpreting
application correlation; claimed senders inside opaque bytes carry no authority.

The request deadline includes acquisition of concurrency for both the timer and
HTTP work. A bounded I/O pool can briefly remain busy after publishing a previous
task's completion. The client yields and retries only worker-slot acquisition
within the original monotonic deadline, then reports `AuthorityTimeout` if no
slot becomes available. HTTP runs at most once per call; transport failure never
triggers an automatic request retry or an inline fallback that defeats deadlines.

The optional [worker bootstrap](src/bootstrap.zig) performs no provider calls.
Its caller supplies a fresh in-memory key; the trusted runtime controller must
attribute the public registration to the configured container and current worker
incarnation before granting activation. Expected denied polls suppress repeated
diagnostics to preserve the bounded bootstrap log. After the first activation,
the host never adopts a newer generation. Counter and Station workers share this
path; imports and ordinary client construction never start it.

The separate [growing ownership bootstrap](docs/growing-bootstrap.md) supports
finite operator placement with a fixed expected generation and ephemeral key.
It fixes an operator-selected generation. Provider-bound workers use
`awaitActivation` and the runtime controller instead.

## Deterministic transport composition

`SessionWithTransport(Transport)` instantiates the same activation, private
proposal and frozen-request logic as `Session`. `Session` selects the real HTTP
`Client`. A substituted transport supplies `query(selector, key)` and
`submit(signed)` with the same validated response, receipt and uncertainty
semantics. The type factory introduces no alternate authority or retry policy.

`delivery.step(client, query, key, pending)` owns one courier observation/submission
step; the executable uses this same function. The query must select delivery.
The caller owns the optional exact signed pending operation, polling and lifetime.
A failed exchange preserves that operation; only a receipt or the existing
resolved-output disposition clears it. Deterministic tests replace transport
outcomes while exercising these production Session and courier functions.

## Instrumentation

An embedding service can set `Client.observer` to its borrowed telemetry runtime
and `Client.parent_context` to the operation making the call. Each call then
records a separate `transit.client.request` span and propagates `traceparent` to
the configured authority, without changing signed bytes. Both fields default to
null; imports and client construction perform no telemetry I/O. Successful poll
requests use debug logs; failed attempts are warnings. Metrics count every
completed attempt, independently of log filtering/loss.

`last_status` and `last_rejection` describe a completed exchange when available,
not a timeout's server outcome. Mutation failures can remain `uncertain`; a
successful response is a `receipt`, not proof of a newly committed transition.
Instrumentation finishes after cancellation joins, before call state is reused.

## Wire compatibility

The [public contract package](../transit-protocol/README.md) owns the generated
schema, canonical signing rules and shared vectors. All native operations use the
current v1 definition identifier. Signatures, responses, saved requests and SDK
library handshakes fence incompatible builds. No previous protocol profile or
fallback decoder is supported; see [versioning](../../../docs/reference/versioning.md).
The [C ABI](docs/bindings.md) exposes shared signing and exact request export/import.
The standalone [native client port](../../../apps/transit-client-host/README.md)
provides those operations without Station.

`Application` defines neutral local application declarations, signed management
requests and bootstrap values, including explicit Board inspection scopes.
Semantic validation checks names, dependency order and grant scopes before
provisioning. The [installation contract](../../../contracts/APPLICATION_INSTALLATION_V1.md)
owns that workflow and its compatibility boundary.

## Build and verification

Use the repository's pinned `nix develop` shell. From the repository root:

```sh
(cd packages/zig/transit-client && zig build test)
just test::packages
```

See the [test guide](../../../tests/README.md) for integration evidence and limits.

`just test::callers` exercises the real counter and byte-log programs against the
same authority, including lost receipts, stale owners, malformed responses, and
restart recovery. `just test::service` also covers client request deadlines.

## Inspection

`Client.query` with `kind.inspection` reads authorized process discovery, current facts,
mailbox, outbox, effects, payload metadata, and filtered retained history. Pages
own their bytes. Keep the resource/PID/cut when following `next`; on `QueryExpired`
or `HistoryReclaimed`, discard assembled pages and refresh with explicit gap
handling. See [inspection v1](../../../contracts/INSPECTION_V1.md).

`protocol.Growth.Command` and `protocol.Growth.Collection` expose lifecycle and
collection requests
through the same signed `Client.submit`/`Session.Pending` mechanism. Administration
and provisioning use separate scoped credentials; execution sessions do not gain
those rights. Follow the [lifecycle contract](../../../contracts/LIFECYCLE_V1.md)
for generation fences, uncertain allocations and resumption bounds.

`ResourceReader` opens one exact current resource revision and exposes bounded
point/page reads without requiring PID ownership. It rechecks current read grants
on every query, rejects changed/invalid sources and preserves a read failure for
that source. It owns no retained version and cannot grant execution authority.
`withFailure` optionally records the original rejected query's native cause and
resource, or metadata observed at a lifecycle failure. The caller owns this bounded
context and keeps it alive with the reader. A fresh query clears earlier evidence;
successful or unrelated transport failures cannot borrow an old rejection.
Station Document uses this shared adapter for public accepted-state reads.
`Reader.readBlock(key, output)` reads a complete immutable block at that same
revision. `Batches.readBlocks` and its operation-local cache acquire at most
eight keys and 128 KiB of verified owned bytes. `BlockBatch` keeps missing keys
distinct from unrequested keys and empty values; it supplies no authorization.
`Reader.entry` returns the same bounded point observation with its resource-local
entry revision. The serving Table watch uses that revision for its application
progress marker; it never compares entry positions from unrelated resources.

`SnapshotReader.open` acquires a fresh leased resource cut through the
`leased_snapshots` capability. Its point/page methods keep that revision across
source writes while the authority checks current permissions and lifetimes.
Call `close` on success, cancellation and failure; abnormal client loss falls
back to the finite lease. The reader preserves failures, supports a cancellation
flag between fetches and cannot resume after authority restart. See
[leased snapshots](../../../contracts/INTERACTIVE_QUERY_V1.md#generic-leased-snapshots)
for active quotas, clock requirements and retained-byte limits.

`SnapshotReader.blockBatch(request, body)` reads block data at the same leased
cut and preserves the metadata reader's failure, cancellation and renewal rules.
Its caller owns the body. Table hosts may cache verified bytes within one cut;
they still validate current authority before disclosing results.

With the native `resource_read_batch` capability, `ResourceReader.readBatch`
acquires up to eight distinct keys in one current authorized cut. The returned
owned `Batch` exposes only those keys and their exact absence/entry revisions;
asking for another key fails. Its local accessors perform no I/O or fresh
authorization. Use it within one bounded acquisition and revalidate before
disclosure; never reuse it as a grant or cache across requests. Serving uses it
to read configuration, policy and session together while clock/control commits
continue, then acquires a fresh batch for its final check.

`SnapshotReader.Support` caches negotiated protocol support, never permission.
Both `leased_snapshots` and `snapshot_read` must be advertised. Missing support
returns `InteractiveQueriesUnavailable`; the client has no older-protocol fallback.
With `snapshot_read`, `acquire` combines a fresh cut with bounded captured data
and current metadata. `batch` preserves that cut while acquiring fresh current
metadata, reading bounded ranges/points or validating and releasing the token.
The response distinguishes those bases. See the
[combined read contract](../../../contracts/INTERACTIVE_QUERY_V1.md#combined-snapshot-reads).

The native client ages pooled sockets from the start of the previous exchange,
including response transfer/parsing time. Exchanges older than the bounded reuse
window retire idle sockets before the next send. The gateway uses the same rule.
This reduces stale reuse after slow responses without retrying an uncertain
request. A peer can still close a connection or exceed its deadline; callers
retain and reconcile the exact prepared identity after transport failure.
