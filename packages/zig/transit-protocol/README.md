# transit-protocol

Public, language-neutral Transit contract types, exported as `transit_protocol`.
The library depends only on Zig's standard library. Core and client both import
it; no storage, transport or provider implementation belongs here.

[Growth.zig](src/Growth.zig) owns the single native v1 command/query definition,
including paged state, lifecycle, delivery, runtime bindings and inspection.
The module root exports common request/command aliases, receipts, values,
permission bits and rejection codes. `State` supplies state permission constants;
[NativeInspection](src/NativeInspection.zig) owns bounded inspection selectors.

## Contract and generation

The [native contract](../../../contracts/TRANSIT_V1.md),
[service contract](../../../contracts/SERVICE_V1.md) and
[state contract](../../../contracts/STATE_V1.md) specify behavior.
[`transit-v1.schema.json`](../../../contracts/transit-v1.schema.json) is generated
from the exact public types. It includes defaults, field order, integer ranges,
routes, signing metadata and the current contract definition identifier.
Run `just contract::generate` after public changes; `just contract::check` detects
drift. Incompatible changes replace that identifier and update all consumers
under the [hard-cutover policy](../../../docs/reference/versioning.md).

Canonical signing includes defaults/nulls, declaration order and decimal integers.
Opaque `Value` fields use lowercase hexadecimal. Keep numeric values lossless
within their documented range. Shared [request vectors](src/fixtures/requests-v1.json)
and [inspection vectors](src/fixtures/inspection-v1.json) pin independent bytes,
hashes and Ed25519 signatures. The shared Zig client owns those semantics across
language SDKs; generated declarations alone do not constitute a correct SDK.

Capabilities describe supported operations, not cached authorization. Each read
rechecks current keys, PID scope, resource grants and lifetime, then verifies the
authority-tail fence before disclosure. Metadata inspection alone cannot
substitute for value-read permission. Bounded `read_entries` preserves missing-key
slots and optional exact revision; it does not retain a historical version.

## Build and verification

Use the repository's pinned `nix develop` shell. From the repository root:

```sh
(cd packages/zig/transit-protocol && zig build test)
just test::packages
```

See the [test guide](../../../tests/README.md) for integration evidence and limits.

## Schema helpers

The shared `Schema` reflection writer keeps kernel wire arrays fixed. A consuming
host ABI may explicitly opt into `sequence_max_length` for bounded JSON sequences;
domain validation still enforces narrower per-field limits. This generation option
does not widen protocol frames, mutation budgets or running-service capabilities.

`Schema` and `Json` support schema-aligned host descriptions and values. Fixed
byte arrays always encode as arrays, including inside bounded host sequences,
even when they happen to contain UTF-8;
text slices remain strings and owning `jsonStringify` codecs remain authoritative.
Public scalar types can supply `jsonSchema`; versioned structs can override a
field with `json_schema_fields` beside their runtime declarations. These helpers
do not replace the native protocol's canonical digest/signing functions.

Host decoding checks scalar JSON kinds too: integer fields reject quoted numbers,
booleans and enum strings keep their declared shapes, and empty payloads require
an empty object. Escaped UTF-8 and full-width protocol counters round-trip through
the shared encoder/parser; these host checks do not change native signing bytes.
