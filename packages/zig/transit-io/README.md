# Bounded I/O runtime

Numeric IPv4/IPv6 endpoints resolve directly into caller-owned queue storage.
They preserve address-family filtering, port and canonical-name lifetimes without
calling libc's allocating resolver on reconnect. Hostnames retain the platform
resolver's DNS/NSS behavior; those external allocations require a separate
profile and are not covered by numeric-endpoint allocation checks.

`transit_io.Threaded` owns the pinned Zig threaded I/O implementation, a fixed
`transit-memory` slab for task/future records and an admitted worker count. Hosts
choose the worker count, record capacity and stack size before accepting work.
This effectful owner sits above the deterministic memory library.

`create` initializes stable storage and starts every admitted worker behind a
barrier. The barrier is released and joined before admission returns. Subsequent
concurrent tasks reuse those workers and reserve records inside the slab;
exhaustion uses Zig's `ConcurrencyUnavailable` result. Ordinary asynchronous work
retains Zig's inline-execution behavior when it cannot reserve a task. There is no
fallback allocator. Cancellation and joins use the same runtime that started work.

Pass `runtime.io()` to the client and its host operations. Join every future/group
before `destroy`; destruction waits for the worker loops before releasing record memory.
The supplied environment/argument views must outlive the runtime. Distinct
long-lived runtimes should be destroyed in reverse initialization order because
the underlying threaded implementation installs process signal handlers.

`Options.worker_cleanup` runs a non-failing callback once on each distinct worker
after host work has joined and before runtime destruction. A simultaneous barrier
prevents one worker from consuming multiple cleanup tasks. The future directory
is reserved at creation, so cleanup needs no backing allocation. Use this hook
to end foreign thread-local state while its allocator still exists. The pinned
runtime detaches pthreads: waiting for its worker loops alone does not join later
pthread destructors. The SQL gateway explicitly stops OpenSSL thread state here
before freeing its process-wide crypto reserve. The callback must not schedule
new work or reuse the runtime.

`reservedBytes` includes owner metadata, the barrier directory, retained record capacity and requested
worker stacks. It does not count OS guard pages, pthread metadata or TLS runtime
state; a host claiming an OS allocation bound must measure those separately.
Using an unrelated `std.Io` implementation does not inherit this runtime's memory
profile. Record counters do not cover allocators used by application callbacks.

Run `zig build test` or `zig build check` inside `nix develop`.

`Notification` reserves a fixed directory of active wait tickets at initialization.
Register before rechecking the owner's durable predicate, and wait only when that
recheck still requires progress. Publication and recovery call non-failing
`notify`; its generation prevents a notification between recheck and parking
from being lost. All waiters wake together and must recheck current authorization
and durable state before returning any data. Notifications carry no durable
acceptance or completion evidence.

Each ticket admits one cancellable wait with an absolute deadline; a relative
timeout is converted once before parking. Capacity exhaustion refuses new waits.
Tickets use non-repeating serials, and released tickets cannot address reused
slots. Registration, wakeup, timeout and release allocate no backing memory.
Close wakes existing waits and refuses registrations. Join all host tasks and
release their tickets before `deinit`, which refuses outstanding tickets. The
owner must remain at a stable address while tickets exist.
