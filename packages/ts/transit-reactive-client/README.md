# transit-reactive-client

Reusable, framework-independent TypeScript consumer of the
[shared reactive API](../../../contracts/REACTIVE_V1.md) and its explicit
[private host adapter](../../../contracts/REACTIVE_CLIENT_V1.md). No signing seed,
SQL compiler or application protocol codec lives in this package. Zig prepares
and verifies the native operations; this host adapter owns browser I/O and
in-memory lifecycle state.

`Transport` validates finite responses, signed envelopes and the actual SSE
field/JSON boundary. It rejects malformed UTF-8, unsupported versions, duplicate
fields and oversized messages without accumulating stream history. Int64 snapshot
cells stay decimal strings with checked range. Generated standalone validators
need no `eval` and are suitable for Board's CSP.

`Session` prepares controls through the configured Zig host, retains frozen bytes
on uncertainty and waits for committed dispositions before proceeding. Keep the
object above disposable components. Call `recover` explicitly before preparing
more controls when `pending` is present. `follow` owns one abortable stream;
consumers own pause/hide, reconnect/backoff and visible refresh scheduling. A
reconnect observes the existing session and does not implicitly reopen an expired
one. Close stops a subscription and does not cancel application work.

The shared caller gate uses Web Locks for native preparation/receipt coordination
across same-origin tabs. It keeps the lock across an uncertain mutation until the
same frozen request resolves. This requires a secure browser context and Web Locks;
it does not replace durable requester admission or coordinate different origins.
Other native callers still need sequence coordination. The gate can be injected
by another supported host. `refresh` controls and `refreshStatus` use the opt-in
durable owner; namespace strings preserve all 64 bits.

`inspect` returns metadata/progress through the qualified Table adapter.
`snapshot` requires an explicitly enabled application viewer. Board's default
private profile does not allow it. Neither method verifies an entire finite
query result; the shared query reader and M21 refresh lifecycle own that work.

Run `just transit-board::check` for generated drift, strict types and consumer
checks. `just test::reactive-client` exercises the real Zig host, TLS, exact
lost-reply recovery and metadata-only boundary. Full M21 browser/view qualification
remains in progress; M20's browser harness is separate protocol evidence.

`LiveView<T>` owns a single joined stream/read lifecycle and one newest dirty
revision outside rendering. `start` is explicit; reconnect observes the same
session and never reopens expiry. A host supplies the authorized snapshot reader
and calls `pause` on hide/unmount. Known denial clears the snapshot; transient
failure retains its original basis. Query readers must verify complete coverage
and reread the visible page before returning; this generic owner does not decode
or verify finite query segments itself. One listener set (at most four), snapshot,
refresh record and frozen control are resident; event history is not accumulated.
Renewal runs independently of bounded result verification and shares the single
control owner. Pause joins both tasks before releasing the session.

Private descriptions carry the committed observer clock. Open/renew deadlines
use that recorded value, leaving margin within the 30-second bound; browser wall
time only prompts renewal. A stale/unavailable observer cannot authorize a longer
lease. Clock observation and all accepted controls have durable retention cost.
