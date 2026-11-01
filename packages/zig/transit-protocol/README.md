# transit-protocol

Public, language-neutral Transit contract types, exported as `transit_protocol`.
The library depends only on Zig's standard library. Core and client both import
it; no storage, transport or provider implementation belongs here.

[Growth.zig](src/Growth.zig) owns the single native v1 command/query definition,
including paged state, lifecycle, delivery, runtime bindings and inspection.
The module root exports common request/command aliases, receipts, values,
permission bits and rejection codes. `State` supplies state permission constants;
[NativeInspection](src/NativeInspection.zig) owns bounded inspection selectors.
[Blocks](src/Blocks.zig) owns immutable byte descriptors and the bounded owned
batch codec; [its contract](../../../contracts/BLOCK_V1.md) separates content
identity from resource authority and physical placement.

[`DataLifecycle`](src/DataLifecycle.zig) supplies neutral data identities,
operation bindings, snapshot coverage descriptors and the publication bounds
shared by named resource declarations and Document storage. Its
[contract](../../../contracts/DATA_LIFECYCLE_V1.md) separates validation from
authorized durable acceptance. The generated schema describes those types;
it does not add a native route or implement a storage cutover.

[`Branch`](src/Branch.zig) supplies exact branch identities, immutable manifest
references, frozen merge/restore attempts, complete-validation bindings and
forward publication decisions. Its [contract](../../../contracts/BRANCH_V1.md)
separates neutral validation from retained cuts, current authority and atomic
catalog publication. These types do not enable multi-branch service execution.
[`Transaction`](src/Transaction.zig) freezes explicit scoped object/partition
targets and kind-specific state/log guards. Appends and settlements for one log
partition share an action directory and one preparation. Its neutral membership
and terminal-transfer types do not enable log runtime participation; the
[transaction contract](../../../contracts/DATA_LIFECYCLE_V1.md#transaction-bindings-and-evidence)
states the remaining owner and publication obligations.

[`IndexLifecycle`](src/IndexLifecycle.zig) supplies offline index declarations,
build identities, exact source coverage and conditional publication bindings.
Its [contract](../../../contracts/INDEX_LIFECYCLE_V1.md) pins column comparison
and constraint dependencies independently of physical layout. Validation adds
no index service operation or planner capability.

## Contract and generation

[`StreamQueue`](src/StreamQueue.zig) supplies neutral Stream/Queue partition,
append, finite coverage, group-checkpoint and lease/settlement bindings. The
[Stream](../../../contracts/STREAM_V1.md) and
[Queue](../../../contracts/QUEUE_V1.md) contracts separate pure shape/guard
validation from authorized durable execution. These types add no installed
Stream/Queue operations or executable transaction participants.
`StreamQueueDeclaration` adds immutable routing, retention, compaction and Queue
scheduling policies, operation budgets, checked deadlines and bounded retry
backoff. Its successor checks preserve object identity and partition/key rules;
catalog publication and schema-column binding remain separate responsibilities.
`QueueRead` binds original claim cursors and separates immutable payload
selection from observed Queue state and lease liveness. Its shared clock bounds,
state and blocked-reason types also serve the storage owner. These descriptors
are read attribution, not consumption proofs, grants or present settlement
authority.

[`DocumentDeclaration`](src/DocumentDeclaration.zig),
[`DocumentOperation`](src/DocumentOperation.zig) and
[`DocumentRead`](src/DocumentRead.zig) supply neutral direct Document
declarations, merge profiles (`causal_crdt`, `versioned`), subcolumn shredding
and collation configurations, lineage and replica deduplication floors, finite
merge-window checkpoints and retained revision read pins. Their
[contract](../../../contracts/DOCUMENT_V1.md) separates shape/lineage validation
from durable partition acceptance.

The [native contract](../../../contracts/TRANSIT_V1.md),
[service contract](../../../contracts/SERVICE_V1.md) and
[state contract](../../../contracts/STATE_V1.md) specify behavior.
[`transit-v1.schema.json`](../../../contracts/transit-v1.schema.json) is generated
from the exact public types. It includes defaults, field order, integer ranges,
routes, signing metadata and the current contract definition identifier.
Run `just contract::generate` after public changes; `just check contracts` detects
drift. Incompatible changes replace that identifier and update all consumers
under the [hard-cutover policy](../../../docs/handbook/reference/versioning.md).

Canonical signing includes defaults/nulls, declaration order and decimal integers.
Opaque `Value` fields use lowercase hexadecimal. Keep numeric values lossless
within their documented range. Shared [request vectors](src/fixtures/requests-v1.json)
and [inspection vectors](src/fixtures/inspection-v1.json) pin independent bytes,
hashes and Ed25519 signatures. The shared Zig client owns those semantics across
language SDKs; generated declarations alone do not constitute a correct SDK.

Signed command/query envelopes require an explicit current `definition` in their
body. Missing or foreign definitions fail decoding before signature verification
or execution, including when a signed envelope is nested in saved caller work.
Unsigned request authoring can use the current-definition construction default;
that default is never applied while decoding a signed wire body.
Signed envelopes also preserve fixed byte arrays when encoded by ordinary Zig
JSON writers, including envelopes nested in saved work. Valid UTF-8 bytes do not
change a nonce, signature or runtime identity into a wire string. This transport
encoding uses the existing typed signing digests and strict decoder.

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

`Schema.writeRecursive` emits a root-local `$defs` graph for recursive host
values. References preserve scalar codecs, field overrides, required fields and
the generation options of each occurrence. Host consumers validate each complete
root independently; generated TypeScript uses separate aliases for its references.
The graph describes value shapes, not domain admission or aggregate memory limits.

`Schema` and `Json` support schema-aligned host descriptions and values. Fixed
byte arrays always encode as arrays, including inside bounded host sequences,
even when they happen to contain UTF-8;
text slices remain strings and owning `jsonStringify` codecs remain authoritative.
Public scalar types can supply `jsonSchema`; versioned structs can override a
field with `json_schema_fields` beside their runtime declarations. These helpers
do not replace the native protocol's canonical digest/signing functions.
Custom decoders can declare `json_schema_type` to reflect the ordinary wire type
they actually decode. Signed envelopes derive that type from their public fields,
making the definition mandatory without duplicating command/query declarations.
Owners can scope reflected text and sequence bounds to a field with
`json_schema_text_bounds` and `json_schema_sequence_bounds`.
`json_schema_outer_sequence_bounds` limits only the next slice dimension, so
an eight-row page can still contain 128 columns and larger nested lists.
An enclosing host can describe a larger catalog message without widening other
profiles.

`Diagnostic` defines the shared bounded [diagnostic v1](../../../contracts/DIAGNOSTICS_V1.md)
value: stable code, stage, outcome/evidence, identity, typed context and recovery
actions. It validates evidence/action consistency and owns all returned context.
Domain owners retain error classification, current disclosure checks and durable
outcome authority; the protocol type performs no I/O or recovery operation.

Host decoding checks scalar JSON kinds too: integer fields reject quoted numbers,
booleans keep their declared shape, enum strings must exactly match a declared
name, and empty payloads require an empty object. Quoted numeric enum ordinals
are rejected, including all-zero strings in contract definition fields. Escaped
UTF-8 and full-width protocol counters round-trip through
the shared encoder/parser; these host checks do not change native signing bytes.
