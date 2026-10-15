# @transit/station

The [local logical codec guide](docs/logical.md) covers exact scalar/recursive
documents, immutable owners, checked casts and logical Arrow export.

Typed Station runners for Node.js 24, over the version-matched shared Zig host.
This M11 package is separate from the compatible `@rey/transit-station` M9 wrapper.
It depends on the independent `@transit/client` and `@transit/native-station`
artifacts. Importing starts no process and discovers no credentials.
Source declarations use erasable TypeScript so Node's strip-only unit-test loader
can import the same public modules; the package check enforces that constraint.

Build tarballs with `nix develop --command just bindings::node-build`. Install
version 0.2.0 with its matching native packages; local tarball overrides follow
the [client guide](../transit-client/README.md). Registry publication is outside
this qualification. Artifacts currently target Linux x86_64 in the pinned Nix
environment and require its native closure; they are not portable static binaries.

```typescript
import { Runner } from "@transit/station";
import { Counter, counterCodec } from "@transit/sdk-examples";

const runner = await Runner.open(config, new Counter(), counterCodec, {
  failure: "stop",
  recovery: { kind: "persist-before-dispatch", store },
});
try {
  for await (const event of runner.run({ signal })) {
    if (event.kind === "committed") observe(event.receipt);
    if (event.kind === "needs-recovery") saveForReconciliation(event.mutation);
  }
} finally {
  await runner.close();
}
```

`config` explicitly selects `native_v1`, URL, activation, association and optional
query-result support. `Activation(ProcessRef, principal, generation, seedFile)`
does not read its seed; opening the owned native host does. `nativeHost` overrides
installed executable discovery. Both host versions and authority capabilities
are checked. No implicit legacy fallback exists.
Opening also verifies the exact generated contract definition; matching v1
labels alone do not establish compatibility with another native build.

See [runtime and recovery](docs/runtime.md), the
[HTTP call and replay guide](docs/http.md), the
[executable examples](../../../examples/station-sdk/typescript/README.md) and
[proof guide](../../../tests/README.md). Public types own application contracts;
generated wire schemas remain internal. Existing M9 low-level usage retains its
original package and semantics.

The [finite RPC guide](docs/grpc.md) covers local descriptor binding, original
message batches, durable calls, explicit retry/disposal and owned replay.

The [Document guide](docs/documents.md) covers typed structured/text edits,
scoped writer jobs and asynchronous current-policy reads. `bigint` identities,
owned bytes and validated native responses preserve the shared Zig contract.

The [unified query guide](docs/unified-query.md) covers explicit v1 sources,
persisted admission commands, current-policy results and owned nested Arrow.
Qualification is tracked per source and SDK.

The [relational query guide](docs/relational.md) covers explicit catalog routes,
interactive joins and groups, exact page retries and full-width integer results.

The [catalog guide](docs/catalog.md) covers general typed Table schemas, DDL/DML,
metadata, native role/object authority and exact saved-intent recovery, with `bigint`
identities and generated runtime validation through the native port.

The [handler Table guide](docs/tables.md) covers general typed rows, captured
reads, resumable creation and saved mutation intents within native turns.

Handler query failures use a typed callback with the authenticated origin,
correlation, result identity and reason. See
[negative query outcomes](../../../docs/reference/sdks.md#handler-query-failures)
for callback names, write budgets and recovery behavior.
