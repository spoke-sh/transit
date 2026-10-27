# SQL statement client

`transit_sql_client` submits SQL statements and consumes typed results over
HTTP/TLS or a private Unix socket. `Executor` returns a command completion, logical
result set, service failure or unresolved original attempt. Consumers do not
interpret cursor ordinals or poll accepted-operation phases. The library depends
on the public SQL protocol and result libraries; it imports no SQL runtime,
account signing keys or storage adapters.

## Statements and result ownership

Open a `Client` with endpoint, trust and account configuration. Initialize a
second control client with the same instance, session and account, and keep both
clients and their `Executor` at stable addresses until all outcomes are released:

```zig
var executor: sql.Executor = .{
    .client = &client,
    .control = &control,
    .config = config,
    .password = password,
};
const outcome = try executor.execute("SELECT id FROM items", null, .{});
defer outcome.deinit();
switch (outcome.value) {
    .rows => |*result| {
        // schema and observation remain valid until outcome.deinit().
        while (try result.nextRow()) |row| {
            try display(row); // borrow ends at the next advance or close
        }
        try displayCount(result.completion().?.rows);
    },
    .command => |completion| try displayCommand(completion),
    .unresolved => |original| try displayUncertainty(original),
    .failure => |failure| try displayFailure(failure),
}
```

Command kind, outcome and applicable matched/changed counts come from the service.
Session commands have no durable operation; Table, configuration and captured
operations preserve their owner identity. Rejected, cancelled and partial command
outcomes require explicit handling. `execute` submits once. Its uncertainty result
retains the original account, instance, admission token and known operation; a
missing observation never authorizes resubmission.

A `ResultSet` exposes one logical schema and observation, `nextRow` or `nextBatch`,
and verified `completion`. Batches are borrowed row or column views with no cursor,
ordinal or repeated schema. Rows include their nested/variable-width allocations;
copy before advancing if retaining a value. Exhaustion closes the remote cursor.
`close` stops early and is idempotent; `Outcome.deinit` closes and frees all local
ownership even after a failure. Completion already received survives early close,
while delivered count can remain lower than the verified result count.

`nextBatch` exposes `results.Batch` with `len`, `cell(row, column)`, `columnAt`
and non-copying `slice`. Column consumers can access compatible Fuze/Arrow value
buffers without building row objects; `nextRow` supplies an allocation-free row
view over the same values. Retain the source owner for all borrowed buffers.
The native adapter retains an exact-size aligned binary response body per batch.
Common scalar columns borrow Arrow-compatible value buffers directly. Other
logical types allocate cell/recursive descriptors while borrowing variable bytes
from that body. Initial schema and observation metadata have separate lifetimes;
subsequent batches carry their commitments. The next pull or close releases the
previous body. Native result bodies are uncompressed; socket reception and server
column construction still copy bytes. Prepared parameters use the bounded JSON
control codec.

`results.Window.read(allocator, result, .{ .rows = 32, .bytes = 262144 })` copies a
bounded view. Deinitialize the window independently. A row or byte limit leaves
the next non-fitting row unread and does not imply query completion. The caller
can continue streaming or close. Schema/observation storage and window storage
have distinct owners.

`Executor.Options.resident_bytes` bounds statement response parsing, copied
metadata and decoded rows together; its default and maximum are 16 MiB. Transport
connections have separate client-owned buffers. Native batches contain at most
32 rows and 1 MiB of canonical cells inside a 4 MiB message. A small client budget
can reject a valid server batch with `OutOfMemory`; limits do not silently truncate
rows. Per-batch storage is released before fetching the next batch. A window has
its own explicit allocation budget. All result APIs require one borrower.

## Deadlines, cancellation and recovery

A lost fetch reply can retry the same cursor/ordinal up to three attempts within
the original request deadline. The reader never resubmits SQL, replaces its session
or appends a different snapshot. Malformed rows, changed schema/observation,
incorrect counts, missing terminal evidence and transport failure stop the result.
`ResultSet.failure()` retains a service diagnostic when one was received. EOF,
cancellation and closure cannot manufacture a successful empty result.

`Pending` observes the original admission token. Discovery uses the remaining
request budget; confirmed acceptance permits settlement for up to 270 seconds
from submission. Polling does not reset either deadline. Temporary authority
unavailability repeats only observation. One separately authenticated observation
session may resolve an expired session's accepted operation, pinned to the same
instance/account; it does not restore settings or an interrupted read.

Optional cancellation callbacks supply caller intent. Cancellation joins the
active request before using the control transport. An accepted write can complete
before cancellation wins; its confirmed outcome remains authoritative. Cancellation
settlement has a one-second budget. Stopping a wait is not rollback. Cleanup uses
at most one second; an unobserved close leaves the service's lease/recovery rules
responsible for remote cleanup, and does not erase known completion.

Slow consumers call `Executor.renew()` between advances to renew the existing
session. They must finish each blocking local task within the advertised lease
or arrange independent control access. Expiry produces an incomplete prefix.
`openCaptured` explicitly opens a retained captured operation as a new consumption;
it never repairs or splices an interrupted reader.

## Low-level connection controls

`Client.init` validates endpoint/trust configuration. `open` negotiates the current
definition and instance and performs peer/trust/SCRAM login. `call` returns an
owned parsed response; deinitialize it. `callAllocated` assigns that response's
request/parsing allocations to a supplied allocator. These low-level calls never
automatically replay requests. `Client.deinit` releases transport resources;
explicitly send `close` to release the logical session.

TCP credentials use HTTPS with system roots or a configured PEM CA bundle.
Plain HTTP requires explicit loopback trust. Redirects are refused. HTTP sockets
may be replaced without replacing the logical session.

`Discovery` reads nonsecret local rendezvous records under an owner-checked
runtime directory. On Linux, the service verifies the socket peer UID. The
fallback is `/tmp/transit-<uid>` with mode `0700`; an installation path digest
selects its socket. Missing/foreign definitions, unsafe directories, links at
owned socket paths and a live socket are rejected. Only the service holds the
socket ownership lock.

Run `nix develop --command sh -c 'cd packages/zig/transit-sql-client && zig build test'`.
The [result contract](../../../contracts/SQL_RESULTS_V1.md) owns the semantic
model; the [session contract](../../../contracts/SQL_SESSION_V1.md) owns its native
communication mapping. The finite relation oracle uses the same public consumer
with scripted semantic sources and native messages, varied chunk boundaries,
malformed evidence and allocation failure. These checks do not establish honest
computation by an untrusted service.
