# Local logical types and values

The `logical` namespace owns immutable `Type` and `Value` documents through an
asynchronous `Codec`. Shared Zig validates types, casts, structural operations
and Arrow layout. Opening starts one local host without credentials, source
access or an authority connection.

```typescript
import { logical } from "@transit/station";

const codec = await logical.Codec.open();
try {
  const type = await logical.Type.fromJson(
    codec,
    '{"definition":"transit.fuze.types.v1.2026-09-30","type":{"uint128":{}}}',
  );
  const value = await logical.Value.bind(codec, type, "340282366920938463463374607431768211455");
  const saved = value.bytes;
  const ipc = await codec.arrow(value);
  // Both byte arrays and the logical value survive codec.close().
} finally {
  await codec.close();
}
```

`Type.fromJson/fromBytes` and `Value.fromJson/fromBytes` validate complete logical
documents or canonical binary. `json` is an immutable canonical string; every
`bytes` or `fingerprint` access returns independent bytes. Types expose the
`equality` and `ordering` traits. Values support `cast(codec, type, rounding)`;
rounding defaults to `reject`, with explicit `toward_zero` and `nearest_even`.
The codec also supplies `equal`, `order`, `hash` and `arrow`. Native responses
receive generated runtime validation before public owners are constructed.

The [logical JSON contract](../../../../contracts/FUZE_TYPES_V1.md#neutral-logical-json)
uses strings for exact integers/coefficients and bit strings for floats,
including recursive cells and conflict alternatives. These document APIs do not
coerce JavaScript numbers or arbitrary objects. Requests/results are bounded to
256 KiB, binary values to 96 KiB and Arrow export to one 64 KiB segment. Close
joins the owned host. Invalid/foreign documents, unsupported traits and calls
after close reject their promises. Local codecs do not expand stored Table,
native query or Flight capabilities.
