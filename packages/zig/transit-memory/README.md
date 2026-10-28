# Bounded memory

`transit_memory` owns allocation measurement and reusable memory primitives below
storage, query and client packages. It depends only on the Zig standard library;
domain owners supply capacities, admission policy and public error semantics.

`Workspace` owns a fixed 64-byte-aligned reserve. Its single borrower receives a
generation-checked `Lease`; reset ends all views and updates that lease, and
release allows a new borrower. Marks support transactional append/rewind. The
allocator and raw slices borrow the lease: callers must stop using them before
reset or release. Generation checks protect lease operations, not dereferences
of stale raw pointers. Keep the workspace at a stable address after acquisition.

`Pool` admits independent borrowers into fixed workspace size classes. It
serializes admission and release and picks the smallest available fitting slot.
Exhaustion returns `MemoryPoolExhausted`; it never grows or invalidates another
borrower. Each payload still has one borrower, and all tasks must join before
release. `reservedBytes` includes slot metadata and alignment padding. Explicit
erasure on release clears every byte used through its allocator, including
freed, shrunk or rewound allocations and earlier leases released without erasure.
The reserve starts zeroed; the used high-water range avoids repeatedly clearing
untouched capacity. Owners that borrow the raw backing buffer must erase their
own writes before returning the lease; those writes bypass allocator accounting.

`Slab` supplies an allocator for independently lived objects inside one fixed
reserve. It coalesces free ranges and serializes allocator metadata operations;
payload access remains the caller's responsibility. Headers, alignment gaps and
fragmentation consume the reserve. `live_bytes` counts requested payload bytes;
`occupied_bytes` includes headers and rounding, and `buffer.len` remains charged
until destruction. `reservations` and `refusals` count internal free-list requests.
Allocation failure never falls back to the parent. Destroy it only after freeing
every object. Initialization rounds capacity down to a multiple of 64 bytes.
Admission charges that full capacity and initializes allocator metadata without
filling unused payload pages. Backing capacity is not a resident-page promise;
the parent allocator and host determine page residency. Ordinary borrower
allocations retain Zig's normal initialization behavior. The first erasure
covers the complete reserve because its initial contents are unknown. Later
`reset(true)` calls or destruction erase the used high-water range, including
freed payloads, padding and old headers, without clearing untouched capacity again.
`fromBuffer` borrows an exclusively leased aligned reserve; its backing owner
remains responsible for accounting and release. `reset(true)` requires no live
objects and erases freed payloads, padding and old headers before reassignment.
Lifetime peak accounting survives reset.

`Budget` bounds allocations through one borrower and distinguishes its configured
exhaustion from a parent allocator failure. Optional `Quota` ancestors provide
concurrent shared bounds; a rejected parent reservation rolls back child usage.
Ancestor chains must be acyclic, immutable and outlive their borrowers. Temporary
reservations remain charged while a parent allocator runs. Share `Quota`, not a
mutable `Budget`, between workers. Fuze exports this same `Budget` as
`MemoryBudget`.

Place a budget **below** a workspace, pool or slab to charge its entire retained
reserve, including idle capacity. Placing another budget above it can constrain
one borrower, but those logical charges are not additional physical memory.
Owners account for their own structs, worker stacks and external transport
allocations separately. All primitives must stay at stable addresses while
allocators, leases or child quotas reference them. No primitive acquires backing
memory during reset, reservation or release.

`AllocationProbe` records attempted and successful allocation, resize and remap,
free calls, acquired/released bytes and live/peak backing bytes. `begin(true)`
seals the allocator after warmup: allocation, growing resize and all remap
attempts fail and remain counted. `verify` rejects any such attempt, even if its
caller recovered without allocating. Resetting counters preserves live backing
accounting. Place the probe below the reusable workspace, not above its internal
bump reservations. It is single-borrower; workers need separate probes or host
synchronization. It does not observe other allocators, libc or OS mappings.

Run `zig build test` or `zig build check` in this package inside `nix develop`.
