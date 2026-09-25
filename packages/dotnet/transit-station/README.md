# Station for .NET

The .NET 8 adapter uses generated P/Invoke declarations for the shared
[Station ABI](../../zig/transit-station/docs/bindings.md), plus the independent
Transit client ABI. It is qualified on Linux x86_64 with the SDK pinned by
`nix develop .#bindings`. There are no NuGet dependencies; the checked-in
configuration disables package feeds.

`GenServer.OpenAsync` takes an explicit native library directory, endpoint,
32-byte signing seed and server configuration. The directory contains
`libtransit_station.so` and `libtransit_client.so`; one directory is selected per
assembly. Importing the assembly acquires no credentials and performs no I/O.
`NextAsync`, `ApplyAsync` and `FinishAsync` expose the same private turn as Zig.
`PendingAsync` returns the exact signed request for `Client.CallAsync` recovery.
Do not parse/reserialize that retry material. Arrow IPC remains a `byte[]`;
`ArrowCellAsync` provides the qualified finite cell reader. Full-width Arrow
integers and correlations are decimal strings in the JSON API.

Every handle owns one dedicated native thread with the ABI's generated 8 MiB
stack budget. Native calls do not run on the CLR thread pool. A concurrent call
fails with status 9 instead of joining an unbounded queue. Task continuations run
asynchronously. Await cancellation with `task.WaitAsync(token)` stops waiting,
not the admitted native operation; retain that task to observe its outcome.
`DisposeAsync` waits for admitted work without blocking the caller's event loop.
`Dispose` joins synchronously. Safe handles and finalizers provide cleanup, but
explicit `await using` is the supported lifetime pattern. Managed copies of
credentials cannot be promised secure erasure.

An exception does not implicitly finish a turn. The caller can explicitly record
failure, or discard the handle and recover after fencing the old activation.
Cancellation, host loss or an unavailable completion never proves that a commit
was rejected. Preserve exact pending material, or establish fresh ownership
before recomputing.

The [runnable example](../../../examples/station-bindings/dotnet/Program.cs)
materializes a Table and exchanges a durable Arrow reply with other languages.
`just bindings::test` builds it without network package restore, runs both caller
roles against the real authority, and exercises asynchronous lifetime cleanup.
Generated declarations and the embedded contract are checked by
`just bindings::check`.
