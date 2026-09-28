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

`inspect` returns metadata/progress through the qualified Table adapter.
`snapshot` requires an explicitly enabled application viewer. Board's default
private profile does not allow it. Neither method verifies an entire finite
query result; the shared query reader and M21 refresh lifecycle own that work.

Run `just transit-board::check` for generated drift, strict types and consumer
checks. `just test::reactive-client` exercises the real Zig host, TLS, exact
lost-reply recovery and metadata-only boundary. Full M21 browser/view qualification
remains in progress; M20's browser harness is separate protocol evidence.
