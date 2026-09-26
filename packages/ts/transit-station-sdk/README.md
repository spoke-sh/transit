# @transit/station

Typed Station runners for Node.js 24, over the version-matched shared Zig host.
This M11 package is separate from the compatible `@rey/transit-station` M9 wrapper.
It depends on the independent `@transit/client` and `@transit/native-station`
artifacts. Importing starts no process and discovers no credentials.

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

`config` explicitly selects `growing_v3`, URL, activation, association and optional
query-result support. `Activation(ProcessRef, principal, generation, seedFile)`
does not read its seed; opening the owned native host does. `nativeHost` overrides
installed executable discovery. Both host versions and authority capabilities
are checked. No implicit legacy fallback exists.

See [runtime and recovery](docs/runtime.md), the
[HTTP call and replay guide](docs/http.md), the
[executable examples](../../../examples/station-sdk/typescript/README.md) and
[proof guide](../../../tests/README.md). Public types own application contracts;
generated wire schemas remain internal. Existing M9 low-level usage retains its
original package and semantics.
