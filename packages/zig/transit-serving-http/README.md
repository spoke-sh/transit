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

`ApplicationRequests` preallocates request bytes, protected-value slots and private
scratch within an explicit resident budget. Admission refuses capacity without
evicting live requests and rejects duplicate original inputs, including in-flight
construction. Each reservation binds an exact Queue input and a fixed
monotonic deadline; waiting or recovery does not renew it. Evaluations borrow one
request exclusively while other requests proceed independently. Closing revokes
further access, joins its current borrower, then erases all request/protected
bytes. Registry calls take the calling task's I/O runtime, and each borrow retains
that runtime for cancellable waits and cleanup. Ingress and SQL workers can use
separate runtimes without borrowing ingress's cancellation context. The native
request host uses its scoped client's runtime for expressions and secret reads.
Releasing an evaluation erases its private scratch and removes its borrowed
authority callback. A stale borrow or close cannot affect a reused slot. Registry
ownership grants no native rights: new and released reservations deny redemption
until a native binder supplies current scoped authority. Live listener/executor
composition remains pending.

`ApplicationRequestHost` composes those owners for an explicitly supplied native
execution context. It selects at most one top-level capability from the original
input snapshot, borrows that exact Queue record's reservation, and returns a
`BoundHost` whose cleanup releases only that borrow. Every protected redemption
checks both the registry's current lifetime and the signed invocation authority.
Secret mounts match the declared binding's catalog scope and namespace; physical
placement never grants secret-use rights. Missing or expired reservations still
allow public failure-handler expressions, while protected operations fail without
creating replacement material. The managed executor and listener must still be
wired to this factory. Its readiness check includes all typed program functions,
protected input fields and failure continuations, and requires a matching mount
for declared secret references. It currently refuses effects, response/handoff
operations, paging and invocation deadlines. Supplying this host does not claim
that those facilities or live ingress are ready. Releasing the binding erases
its copied scoped clients and signing material after removing registry callbacks.

`ApplicationSecrets` supplies the protected host's native lookup/current
callbacks using the exact canonical secret binding and current fenced client.
The deployment supplies an open private mount for that namespace. Reads accept
only bounded regular files, preserve every byte, and verify the declared SHA-256
commitment before retention. Changed, empty, oversized or unavailable files
cannot substitute another credential; failed reads erase their private buffer.
Current checks retain the native transaction read guard and reject a revision
from another binding. The request host supplies these callbacks for the matching
trusted mount and the evaluation's exact fenced client/transaction view.

Secret authority provenance remains separate from redemption purpose. Derived
values and Bearer headers preserve their parent's native revision requirement;
random/request/provider material carries a transient observation identity.
The reservation supplies that distinction to the authority verifier from its
retained slot, so a public handle cannot alter it.

`ApplicationAuthority` connects reservation access to the shared execution
context's current invocation, control and dependency checks. Native secret
redemption additionally requires the program's exact declared secret binding
and the same client fence/transaction view. Rotation can produce a false
`SECRET_CURRENT` result; other uses reject the stale revision. The adapter
currently rejects all handoffs until the native common-commit proof owner is
connected. It does not enable live ingress or effect dispatch by itself.

When an effect scope supplies an `ApplicationReadSet`, the request host records
the actual secret metadata read (including absence), native policy revision and
program control/dependency observations. Cached redemptions repeat these checks;
they cannot replace a changed basis or add a new source after verification.

`ApplicationEffectHttp` renders frozen effect operands into caller-owned private
buffers. Form values use exact UTF-8 percent encoding; Bearer headers retain typed
secret references until the transport resolver rechecks their purpose and current
authority. Sink-owned headers cannot be replaced by request fields. Prepared form
bytes still require current redemption before sending. Capacity and rendering
failures erase partial bodies. Response capture retains at most 64 KiB privately
and creates status/count/digest metadata only from a complete transport result;
the protected body must be sealed separately in the original reservation.
Sealing commits the original descriptor, status, byte count and body digest to
one protected observation. Adoption checks that observation, its exact handle
and retained bytes under current authority. A sealing failure leaves the known
HTTP response metadata intact with no body handle.
This adapter supplies neither dispatch authority nor a service worker.

`ApplicationEffectTasks` bounds local active work and private scratch separately
from the native backlog. A full pool leaves the original waiting. Each task
keeps its creating I/O runtime through join and requires independent clients;
coordinator calls may use another runtime. Local status observes an existing task
without admitting one; missing work and capacity are distinct from a running task.
Waiting returns the existing progress unchanged, without another native read or
an authority claim. The physical task checks current authority and fences through
its native operations and final write gate. Missing or completed local tasks
re-enter the native executor boundary before result observation. Withdrawal signals the task, which
joins its child I/O before reporting completion. A replaced fence cannot start
another task in the occupied slot, and changed operands for the same original
are rejected. Failed work remains abandoned until native recovery releases it.

Known responses survive join, repeated polls and shutdown. Shutdown stops new
tasks and joins physical work while keeping completion metadata; the coordinator
must settle and release those originals before destroying the pool. Its resident
budget covers owned slots and scratch, with I/O scheduling and thread-stack
budgets owned by the deployment runtime. An executor callback still supplies the
actual native reopening, authority checks and HTTP exchange. The pool does not
make effect programs ready by itself.

`ApplicationEffectRuntime` supplies that physical callback and an explicit host
composition. Each task reopens the original invocation with independent native
clients, borrows its request once, and validates exact connection placement.
Its explicit `native_bytes` slice comes from the existing task scratch budget.
A fixed `transit-memory` slab reuses native call buffers with independent
lifetimes and a resettable arena for guard temporaries. Retained evaluation
values use separate output memory in that same reserve.
State execution retains the program's role; the active sink selects its own
dispatch role. Native secret redemptions require both roles' current rights.
Both read sets must agree on the policy revision, and the final state-role check
also verifies the exact sink/connection controls observed by the dispatch role.
After TLS, the worker reevaluates the original guard against the frozen pre-step
environment, rechecks protected operands and verifies those current read sets
before allowing the first HTTP write. It never reevaluates frozen request operands.

The worker uses native Queue clock inspection and the original claim's deadline,
with sink and request limits that can only shorten the remaining budget. Programs
with effects or a declared deadline require `inspect` on their input Queue;
ordinary programs retain their narrower input privileges. A
deadline watcher cancels and joins the exchange when a later clock observation
shortens that budget. No fresh native dispatch admission means no send; later
transport failure retains uncertainty. Complete responses remain known through
failed private body sealing and cancellation. Response adoption checks the
original deadline again before disclosing the protected body to its continuation.
The explicit host rejects programs declaring `DEADLINE`: the exchange watchdog
does not bound native preflight and successive application transactions. Sink
timeouts and transient request expiry still bound each exchange. It also lacks ingress
publication, handoff and transactional response facilities; node/SQL
deployment composition must supply their owners before admitting the complete
browser application.

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
