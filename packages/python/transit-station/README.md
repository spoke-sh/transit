# transit-station for Python

An owned-handle `ctypes` adapter over the shared Zig libraries. It exposes raw
`Client` and `GenServer` classes, synchronous calls and `asyncio` wrappers.
Importing it opens no libraries, connections or credentials. Supply library
paths and credentials explicitly during construction.

The [M11 Python SDK design](../../../docs/sdk/PYTHON.md) proposes typed clients,
handlers and runners above this adapter; those APIs are not implemented yet.

The current qualification baseline is Nix-pinned CPython 3.13 on Linux x86_64.
No Python runtime dependencies are needed. PyArrow is an independent test/example
consumer; it is not needed to execute a Station handler or retrieve IPC bytes.

```sh
zig build station-abi client-abi
export TRANSIT_LIBRARY_DIR="$PWD/zig-out/lib"
export PYTHONPATH="$PWD/packages/python/transit-station"
python3 examples/station-bindings/python/main.py /private/host.json service 2
```

That example needs a provisioned peer and associated resource; run
`zig build test-bindings` for a fully provisioned, disposable pair. It consumes
one turn per invocation, demonstrating recovery between handler calls.

Use `with` or `async with` and close explicitly. Async calls run in Python's
worker pool and release the GIL during native work; each handle allows one
operation and rejects overlapping use. Cancellation releases the await, not
the native request. `close` waits for native work; use async context management
or `asyncio.to_thread(server.close)` on an event loop. Handle cleanup never
implicitly acknowledges or commits a message. Explicit contexts are preferred
to finalizers, particularly during interpreter shutdown.

`GenServer.next` presents detached turns, `apply` uses the generated action
schema, `finish` freezes success/failure and `pending` preserves exact retry
text. `Client.prepare`/`call` use the raw protocol and retain its status distinctions.
`TransitError.status` is the generated numeric status; `detail` contains native
and protocol errors when available. Table int64/correlation values cross the
shared action API as decimal strings; Python may convert them to integers after
reading. IPC is returned as hex and can be passed as bytes to PyArrow directly.

The [shared ABI guide](../../zig/transit-station/docs/bindings.md) owns bounds,
recovery and current permission semantics. Python-managed secret copies cannot
be guaranteed erased by the garbage collector; keep credentials explicit,
private and out of logs. Native copies are erased when their handles close.
