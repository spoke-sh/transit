# Bounded I/O runtime

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
before `destroy`; destruction joins worker threads before releasing record memory.
The supplied environment/argument views must outlive the runtime. Distinct
long-lived runtimes should be destroyed in reverse initialization order because
the underlying threaded implementation installs process signal handlers.

`reservedBytes` includes owner metadata, retained record capacity and requested
worker stacks. It does not count OS guard pages, pthread metadata or TLS runtime
state; a host claiming an OS allocation bound must measure those separately.
Using an unrelated `std.Io` implementation does not inherit this runtime's memory
profile. Record counters do not cover allocators used by application callbacks.

Run `zig build test` or `zig build check` inside `nix develop`.
