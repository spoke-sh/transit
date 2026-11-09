# transit-serving-http

The current host requires the native `resource_read_batch` capability and its
`read_entries` operation. Bounded service
and session reads acquire their keys at one current cut; responses still check
current caller/service authority before disclosure. This removes repeated
point-read races with live clock and renewal commits without retaining versions.

Reusable Zig HTTP, fetch-SSE and WebSocket host for
[transit-serving](../transit-serving/README.md) and its
[reactive v1 protocol](../../../contracts/REACTIVE_V1.md).
The neutral [HTTP server](../transit-http-server/README.md)
owns listener admission, deadlines and WebSocket framing; this package owns
signed dispatch, challenge consumption and joined streaming tasks.

Compose `Context` with a validated `Gateway`, upstream URL, gateway reader key
and diagnostics, then pass it to `transit-http-server.serve`. The host maps only
explicitly configured caller public keys and forwards their exact signed native
commands. Its reader credential and accepted service/watch publication remain
separate from caller identity. No handler, raw store or provider is imported.

`Gateway.validate` checks declared connection/request limits, caller uniqueness,
HTTPS origin and reactive clock/deadline requirements. Explicit
`development_allow_insecure_http` permits a configured development HTTP origin;
exact Host/Origin validation remains mandatory. Configuration owns the
lifetime of borrowed URL/origin/caller slices; `Context` outlives all listener
tasks. Each task owns a bounded upstream allocator. Challenges stay local to this
context: route SSE challenge and events to the same instance. Durable session
and cursor recovery still uses the public serving reader and configured signer.

The host uses two-second challenges, 500 ms idle authority checks,
one-second writes and the configured finite connection deadline. WebSocket
authorization stays under the serialized write lock, bounded by the
configured request deadline. The socket write itself retains its separate
one-second deadline. Cancellation
joins receive/event tasks before releasing sockets and buffers. No response
status is appended after streaming headers. Data capacity and control capacity
remain separate; accepted application work is never cancelled by disconnect.
After consuming a challenge, attachment admission and commit observation share
a ten-second retry window inside the joined HTTP task. Temporary upstream
capacity or timeout failures retain the exact signed attachment. A denial,
expiry or incompatible scope still fails immediately; retries do not renew the
session or authorize another use of the challenge.
Stream observations retry temporary read-capacity conflicts for up to 500 ms;
they release no event or heartbeat until a fresh authority check succeeds.
Sustained unavailability interrupts the stream.

From this directory, `zig build test` checks the standalone manifest. The actual
host is exercised by `just test::serving-tls`, `just test::reactive`, and the
reactive browser/limits/placement proofs documented in [tests](../../../tests/README.md).

The optional `Gateway.viewer` enables the [private caller adapter](../../../contracts/REACTIVE_CLIENT_V1.md).
Call `Context.loadViewer` once before serving and `deinit` after tasks join. The
explicit caller key must match an allowed public key. No route is enabled by
merely providing an inspection credential. The default `snapshot_values = false`
profile exposes Table metadata/progress and denies signing application snapshots;
applications must opt in to the bounded snapshot profile. Dedicated control
routing preserves renew/close capacity while streams occupy data slots.

Private descriptions include the committed observer clock and refuse a sample
more than ten seconds behind the configured conservative host upper bound. This
lets callers select a lease within the owner's recorded 30-second interval.
It neither observes a new clock implicitly nor delegates observer authority.


`ServingDiagnostic.Attempt` belongs to one request or joined stream task. Native
submission sets dispatch evidence only after local signature/command validation;
returned native receipts are retained independently of subsequent reads or
response writes. HTTP, SSE and WebSocket errors preserve this evidence through
one shared envelope. Concurrent WebSocket receive/event tasks return their own
owned diagnostics; the selected failure is disclosed only after task joining.
A response write is marked before HTTP output begins, preventing an error handler
from appending a second response after a partial write.

API descriptions reference one shared diagnostic schema and remain inside the
existing 256 KiB description budget. Runtime terminal messages retain the 8 KiB
bound; private finite responses retain their 16 KiB client bound.

## Declarative browser host

The application runtime's `ApplicationReservation` and
`ApplicationProtectedHost` components own transient protected values and typed
helper evaluation. Original input identity, per-step observations, redemption
purpose and current native authority remain distinct from the opaque handle.
The host erases its separate private scratch on every return and never exports
credential or protected-response bytes through ordinary values. See the
[application program contract](../../../contracts/APPLICATION_PROGRAM_V1.md#protected-values)
for helper algorithms, bounds and the remaining live verifier/dispatch work.

`ApplicationSecrets` supplies the protected host's native lookup/current
callbacks using the exact canonical secret binding and current fenced client.
The deployment supplies an open private mount for that namespace. Reads accept
only bounded regular files, preserve every byte, and verify the declared SHA-256
commitment before retention. Changed, empty, oversized or unavailable files
cannot substitute another credential; failed reads erase their private buffer.
Current checks retain the native transaction read guard and reject a revision
from another binding. These callbacks still require composition with the live
request registry and managed executor.

Secret authority provenance remains separate from redemption purpose. Derived
values and Bearer headers preserve their parent's native revision requirement;
random/request/provider material carries a transient observation identity.
The reservation supplies that distinction to the authority verifier from its
retained slot, so a public handle cannot alter it.

`BrowserRuntime.Running` opens the optional browser listener inside `transit-node`.
It reads typed catalog declarations, resolves private mounted secrets, performs
bounded provider exchanges and obtains published rows through signed native
Table reads. It does not know application table names or grant social users
native privileges. See [browser v1](../../../contracts/BROWSER_V1.md) and the
[example](../../../examples/declarative-browser/README.md). The independent
listener and buffered-disclosure schedules run with `just test::declarative-browser`.

`ApplicationReservation` supplies the local protected-value boundary being
integrated with ordered applications. Its caller supplies bounded memory and
value slots for one active HTTP request, serializes access and joins borrowers
before destruction. Original Queue append identity and ordinal bind the request;
copying a handle into a different row cannot transfer ownership. Every access,
including cached observations, calls the native authority verifier. Redemption
also names its intended use; only generated or derived secrets may become
cookies, and provider bodies remain protected JSON references.

One explicit handoff may transfer the request to an exact destination Queue
record after the verifier observes its committed common transaction. A pending
or denied observation leaves ownership unchanged, and a repeated handoff cannot
reset a destination already acquired by its original invocation. Expiry, close
or request loss erases the reservation; capacity refusal preserves earlier
values and erases partial copies. This component performs no HTTP dispatch,
durable admission or native authorization itself. The live ingress, native
verification callbacks and effect/response integration remain required before
ordered programs can use it.
