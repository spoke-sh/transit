# transit-client

`Session.receive` distinguishes permanent `ProcessExpired`/`ProcessTerminated`
from `StaleActivation`. Only the latter may be resolved by obtaining a valid new
activation for the same PID. A failed read or uncertain deadline is never proof
that a PID has expired.

Zig caller library, exported as `transit_client`. Applications receive ordered
input and committed state, compute their own logic, and submit signed proposals.
The authority validates the protocol without executing application code.

Its package dependencies are [transit-protocol](../transit-protocol/README.md),
re-exported as `protocol`, and optional runtime instrumentation through
[transit-observability](../transit-observability/README.md), re-exported as
`observability`. It does not import the kernel, Ursula, or a provider.
[Client](src/root.zig) owns bounded HTTP exchange; [Session](src/Session.zig)
adds activation-aware receive/prepare/submit operations. This is an experimental
v2 API. For the architectural boundary, read [the caller model](../../../docs/CLIENT.md).

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

Each client is used by one operation at a time; sessions sharing a principal also
share its mutation sequence. Delivered input includes position, opaque value and
versioned authenticated origin. `Session.receive` rejects unsupported origin
versions. Match the expected source PID/turn or effect attempt before interpreting
application correlation; claimed senders inside opaque bytes carry no authority.

The optional [worker bootstrap](src/bootstrap.zig) performs no provider calls.
Its caller supplies a fresh in-memory key; the trusted runtime controller must
attribute the public registration to the configured container and current worker
incarnation before granting activation. Expected denied polls suppress repeated
diagnostics to preserve the bounded bootstrap log. After the first activation,
the host never adopts a newer generation. Counter and Station workers share this
path; imports and ordinary client construction never start it.

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
v2 rejects v1 histories and requests; start a fresh development realm. Station
behaviors and the complete [language-binding surface](../../../docs/CLIENT.md#language-neutral-boundary)
remain M9 work. The first [C ABI](docs/bindings.md) exposes the shared client,
generated signatures and exact-request export/import. Host adapters and their
complete behavior/Table conformance matrix remain in progress.
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
