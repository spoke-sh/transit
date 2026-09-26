# transit-protocol

The [v3 growing-profile contract](../../../contracts/TRANSIT_V3.md) is under M10
development and exported separately as `Growth`. Its generated schema is checked
alongside v2. The [explicit node profile](../../../apps/transit-node/docs/growing.md)
and Zig client now support its bounded command/query surface; launcher defaults,
default Station interfaces and legacy foreign behavior ABIs retain v2. The raw
[client ABI](../transit-client/docs/bindings.md) also exposes explicit v3
operations. Schema presence alone does
not advertise a running capability or migrate signing/checkpoint formats.
The additive growing `identity` query reports current coarse rights and scope
at an authority position; it is not a bearer grant for subsequent reads.

Public, language-neutral Transit contract types, exported as `transit_protocol`.
This library depends only on Zig's standard library. It contains no authority,
storage, HTTP client, or deployment implementation.

Both [transit-core](../transit-core/README.md) and
[transit-client](../transit-client/README.md) depend on this package. Applications
normally import the client; changing a public type changes the wire boundary for
both sides. The API is experimental v2, with no v1 migration.

## Source and contract ownership

[The module root](src/root.zig) exports commands, signed requests, receipts,
process views, rejection codes, opaque values, and provider-neutral evidence.
Package-owned [fixtures](src/fixtures) define shared request, sequence and
authenticated-input cases. `Delivery`, `Lifecycle` and `Collection` expose the M8
courier, process-control and opt-in reclamation contracts.
The [protocol profile](../../../contracts/TRANSIT_V2.md) specifies semantics;
the [service profile](../../../contracts/SERVICE_V2.md) specifies HTTP behavior.
Internal kernel state is not a public compatibility surface.

## Shared resource for future bindings

[`transit-v2.schema.json`](../../../contracts/transit-v2.schema.json) is generated from
the exact public Zig types. It includes requests, response views, receipts,
errors, defaults, field order, integer ranges, permission bits, routes and signing
metadata. Run `just contract::generate` after a public change and review the
result; `just contract::check` fails on drift. No hand-maintained parallel wire
schema is needed.

A future generator can use this resource to emit types and codecs. Interoperable
clients must also implement canonical signing and protocol semantics; JSON Schema
alone does not provide a correct SDK. Defaults and nulls are included in signed
canonical JSON, fields follow declaration order, and integers require lossless
handling over the documented ranges. Unknown/duplicate fields and noncanonical
hex values are rejected. Shared
[request vectors](src/fixtures/requests-v2.json)
and [sequence traces](src/fixtures/sequences-v2.json)
provide conformance input. Existing Python is infrastructure/fault orchestration
and an independent fixture check; both application callers remain Zig.

v2 deliberately rejects v1 requests and stored histories. Use a new development
realm; there is no migration implementation. See the
[protocol profile](../../../contracts/TRANSIT_V2.md) and
[service profile](../../../contracts/SERVICE_V2.md) for the full current contract.

## Build and verification

Use the repository's pinned `nix develop` shell. From the repository root:

```sh
(cd packages/zig/transit-protocol && zig build test)
just test::packages
```

See the [test guide](../../../tests/README.md) for integration evidence and limits.

## Inspection

[Inspection v1](../../../contracts/INSPECTION_V1.md) adds domain-separated signed
queries and owned bounded pages without changing command signatures.
`Inspection` owns the types and limits; the generated contract includes them.

## State resources

[`State`](src/State.zig) defines the M7 v1 resource, association, mutation and
revision-read types, limits, and shared canonical fixture. The
[state contract](../../../contracts/STATE_V1.md) records compatibility and proof
obligations. The signed `capabilities` state query advertises a running
authority’s supported limits; schema presence alone does not.
