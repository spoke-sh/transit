# Station language examples

These callers demonstrate the same service/requester exchange through the shared
Station implementation. The service creates an associated Table with an int64
value above JavaScript's exact-number range and grants a specific peer query
access. The requester records a durable call, receives captured Arrow IPC, reads
the exact value and commits its observation. Each invocation consumes one turn;
the proof restarts hosts between capture, publication and result fragments.

The [Python example](python/main.py) is implemented:

```sh
zig build test-bindings
```

This provisions isolated disk Ursula, signed/scoped principals, required state
associations, ownership and a courier. It also runs native boundary failure
proofs. No running developer installation is used. The service and requester
fit two resource slots; their descriptors, rows, waiting and reply fragments
share the existing per-resource budgets.

For an already-provisioned installation, use the commands and ownership rules in
the [Python adapter](../../packages/python/transit-station/README.md) and
[shared binding guide](../../packages/zig/transit-station/docs/bindings.md).
The remaining language examples are still being implemented in M9.
