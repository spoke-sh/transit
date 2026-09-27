# transit-station for Python

Typed handlers, scoped KV/Table access, durable calls and synchronous/asynchronous
runners over the shared Zig Station implementation. The public API selects
`growing_v3` explicitly. Python owns application codecs and scheduling; Zig owns
protocol validation, signatures, framework transitions and exact retry.

Build installable wheels with `nix develop --command just bindings::python-build`.
Install `transit-station==0.2.0` from `.cache/bindings/wheels` with pip's
`--no-index --find-links` options. It depends on the version-matched
`transit-client` and `transit-native-station` packages; the client has its own
independent native dependency. Discovery uses installed packages, with an explicit
`ServiceConfig.native_directory` override. Import starts no work or credential
access. Missing native artifacts/exports raise `IncompatibleNative`.

The qualified target is Nix-pinned CPython 3.13 on Linux x86_64. Native wheels
carry the local build's Nix runtime linkage; they are not portable manylinux
artifacts. Registry publishing and other platforms remain unqualified.

```python
from transit_station import Runner, Recovery, FailurePolicy, Committed
from transit_sdk_examples.counter import Counter
from transit_sdk_examples.codecs import counter_codec

# config contains an explicitly provisioned activation, associated resource,
# endpoint and key file. store implements application-owned durable persistence.
with Runner.open(config, handler=Counter(), codec=counter_codec,
                 failure_policy=FailurePolicy.STOP,
                 recovery=Recovery.persist_before_dispatch(store)) as runner:
    for event in runner.run():
        if isinstance(event, Committed):
            observe_commit(event.input_position, event.receipt.position)
        else:
            report_recovery_or_stop(event)
```

The installable [counter and query examples](../../../examples/station-sdk/python/README.md)
include both service and requester handlers and versioned application codecs.
`just bindings::python-test` type-checks them and runs clean installed consumers
against a real disk-backed node. [Runtime and recovery](docs/runtime.md) describes
mutation gates, cleanup, errors, Tables and Arrow ownership. The
[HTTP guide](docs/http.md) describes typed request preparation, resumable bounded
publication, correlated outcomes and synchronous/asynchronous capture readers.
These experimental M15 APIs use shared Zig validation and current-grant reads;
the full connector milestone remains in progress. The
[Python API design](../../../docs/sdk/PYTHON.md) provides fuller typed examples;
the [shared ABI guide](../../zig/transit-station-bindings/docs/bindings.md) owns native bounds.

M9's generic `Client` and `GenServer` remain under `transit_station.raw`, with
compatible root aliases. They retain the legacy profile and explicit JSON actions;
they are not the public growing runner. New raw callers import `transit_client`
without Station. Migrating requires explicit profile/activation selection and
application codecs; no state or wire-profile conversion occurs automatically.

The [finite RPC guide](docs/grpc.md) covers local descriptor binding, original
message batches, durable calls, explicit retry/disposal and owned replay.
