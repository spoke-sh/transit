# transit-station for Python

The [handler Table guide](docs/tables.md) covers general schemas, typed reads and
exact resumable mutations.

The [local logical codec guide](docs/logical.md) covers exact scalar/recursive
documents, owned values, checked casts and logical Arrow export.

Typed handlers, scoped KV/Table access, durable calls and synchronous/asynchronous
runners over the shared Zig Station implementation. The public API selects
`native_v1` explicitly. Python owns application codecs and scheduling; Zig owns
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
[Python API design](../../../docs/history/sdk/PYTHON.md) provides fuller typed examples;
the [shared ABI guide](../../zig/transit-station-bindings/docs/bindings.md) owns native bounds.

Raw callers import the independent `transit_client` package. Station exports
its typed runner APIs; the generic `transit_station.raw` adapter and root
`Client`/`GenServer` aliases are removed. Stored requests and process state from
superseded protocol definitions require an explicit cutover; loading them does
not convert their meaning.

The [finite RPC guide](docs/grpc.md) covers local descriptor binding, original
message batches, durable calls, explicit retry/disposal and owned replay.

The [Document guide](docs/documents.md) covers typed structured/text changes,
scoped writer jobs and current-policy synchronous/asynchronous reads. These M17
APIs compose shared Zig semantics; remote writer routing and the other language
adapters remain separately qualified work.

The [unified query guide](docs/unified-query.md) covers explicit v1 KV/Table/
Document sources, sync/async query callers, persisted admission commands and
owned nested Arrow pages. Qualification is tracked per source and SDK.

The [relational query guide](docs/relational.md) covers sync/async interactive
joins and groups, explicit catalog routes, exact page retries and integer results.

The [catalog guide](docs/catalog.md) covers general typed schemas, sync/async
CREATE/ALTER/DROP and INSERT/UPDATE/DELETE, conditional policy, exact saved-intent
recovery and currently authorized outcomes through the shared native caller.


Handler query failures use a typed callback with the authenticated origin,
correlation, result identity and reason. See
[negative query outcomes](../../../docs/reference/sdks.md#handler-query-failures)
for callback names, write budgets and recovery behavior.
