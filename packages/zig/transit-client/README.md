# transit-client

M25's `Application` API defines language-neutral local application
declarations, signed management requests and fresh-worker bootstrap values.
The [installation contract](../../../contracts/APPLICATION_INSTALLATION_V1.md)
owns the implemented workflow and qualification limits. Semantic validation rejects
conflicting names, dependency order and grant scopes before provisioning.

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
[Client](src/root.zig) owns bounded HTTP exchange; [Session](src/Session.zig)
adds activation-aware receive/prepare/submit operations. The default is the
experimental v2 API; explicit `submitGrowing` and `queryGrowing` methods expose
the [M10 v3 development boundary](docs/growing.md). The raw C ABI also exposes
explicit growing command/query kinds; existing Session and legacy Station foreign
behavior APIs retain v2;
`GrowingSession` is an explicit activation helper for the new profile. For the architectural boundary, read [the caller model](../../../docs/CLIENT.md).

## Caller guide

[Calling and recovery](docs/turns.md) explains Session, receive/prepare/submit,
resource-backed turns, current grants, owned bytes, and exact-request retries.
Start with the [counter](../../../examples/counter/README.md) for a complete
program. The library supplies protocol operations; Station will own the behavior
loop, durable waiting, and supervision.

## Public surface

| Interface | Caller responsibility |
| --- | --- |
| `Client.submit` | Sign a mutation and retain its exact request until the outcome is resolved |
| `Client.view` / `Session.receive` | Read a process and its next input under current inspection/activation rights |
| `Client.delivery` | Read scoped courier status without payload or general inspection access |
| `Client.inspect` | Follow bounded process/history pages with explicit cut/expiry handling |
| `Client.state` | Discover state capabilities and read metadata, associations, entries or captured views |
| `Session.prepare*` / `Pending.submit` | Freeze activation-aware proposals; no hidden retry, persistence or background loop |
| `bootstrap.awaitActivation` | Publish a fresh public key and pin the first controller-granted generation for a provider-bound worker |

The shared client accepts authority base URLs with or without trailing slashes.
It removes trailing separators before appending the operation route, preserving
the base path and its escaping. Foreign SDKs use this same transport behavior.

Each client is used by one operation at a time; sessions sharing a principal also
share its mutation sequence. Delivered input includes position, opaque value and
versioned authenticated origin. `Session.receive` rejects unsupported origin
versions. Match the expected source PID/turn or effect attempt before interpreting
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
It does not advertise growing provider bindings or change the v2 activation path.

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
schema, canonical signing rules, and shared vectors for future language bindings.
v2 rejects v1 histories and requests; start a fresh development realm.
The [C ABI](docs/bindings.md) exposes the shared client, generated signatures and
exact-request export/import for explicit v2/v3 operations. M9's Station adapters
have separate behavior/Table conformance evidence. M11's public SDK and growing
Station foreign surfaces remain in progress.
The standalone [native client port](../../../apps/transit-client-host/README.md)
also exposes canonical recovery and native operation metadata without Station.
General payload references remain separately scoped future work.

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

`Client.inspect(query, key)` reads authorized process discovery, current facts,
mailbox, outbox, effects, payload metadata, and filtered retained history. Pages
own their bytes. Keep the resource/PID/cut when following `next`; on `QueryExpired`
or `HistoryReclaimed`, discard assembled pages and refresh with explicit gap
handling. See [inspection v1](../../../contracts/INSPECTION_V1.md).

`protocol.Lifecycle.Command` and `protocol.Collection` expose M8 control requests
through the same signed `Client.submit`/`Session.Pending` mechanism. Administration
and provisioning use separate scoped credentials; execution sessions do not gain
those rights. Follow the [lifecycle contract](../../../contracts/LIFECYCLE_V1.md)
for generation fences, uncertain allocations and resumption bounds.

`ResourceReader` opens one exact current resource revision and exposes bounded
point/page reads without requiring PID ownership. It rechecks current read grants
on every query, rejects changed/invalid sources and preserves a read failure for
that source. It owns no retained version and cannot grant execution authority.
Station Document uses this shared adapter for public accepted-state reads.
`Reader.entry` returns the same bounded point observation with its resource-local
entry revision. The serving Table watch uses that revision for its application
progress marker; it never compares entry positions from unrelated resources.

With the native `resource_read_batch` capability, `ResourceReader.readBatch`
acquires up to eight distinct keys in one current authorized cut. The returned
owned `Batch` exposes only those keys and their exact absence/entry revisions;
asking for another key fails. Its local accessors perform no I/O or fresh
authorization. Use it within one bounded acquisition and revalidate before
disclosure; never reuse it as a grant or cache across requests. Serving uses it
to read configuration, policy and session together while clock/control commits
continue, then acquires a fresh batch for its final check.
