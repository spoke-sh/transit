# Bounded memory

`transit_memory` owns allocation measurement and reusable memory primitives below
storage, query and client packages. It depends only on the Zig standard library;
domain owners supply budgets, synchronization and public error semantics.

`AllocationProbe` records attempted and successful allocation, resize and remap,
free calls, acquired/released bytes and live/peak backing bytes. `begin(true)`
seals the allocator after warmup: allocation, growing resize and all remap
attempts fail and remain counted. `verify` rejects any such attempt, even if its
caller recovered without allocating. Resetting counters preserves live backing
accounting. Place the probe below the reusable workspace, not above its internal
bump reservations. It is single-borrower; workers need separate probes or host
synchronization. It does not observe other allocators, libc or OS mappings.

Run `zig build test` or `zig build check` in this package inside `nix develop`.
