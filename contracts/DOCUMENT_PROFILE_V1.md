# Document interpretation and provenance v1

[`DocumentProfile`](../packages/zig/transit-protocol/src/DocumentProfile.zig)
defines offline interpretation descriptors, bounded processing limits, part
coverage and byte provenance. The reflected
[schema](document-profile-v1.schema.json) is generated from these public Zig
types. The [independent fixture](../packages/zig/transit-protocol/src/fixtures/document-profile-v1.json)
binds exact commitment bytes and full-width identities. The schema root
`SchemaTypes` groups these types for reflection and fixture checking; it is not
a stored revision or transmitted operation envelope.

This vocabulary does not add a catalog operation, SQL syntax, direct Document
publication, transport adapter or effect authority. Installed Document behavior
remains governed by the [Document service](STATION_DOCUMENT_V1.md); direct storage
identities and acceptance belong to [direct Documents](DOCUMENT_V1.md).

## Interpretation

`Descriptor` requires the current contract definition with no default. It binds
a format, positive interpretation revision, nonempty grammar content commitment,
optional schema and segmenter commitments, encoding, framing, key/value collations,
processing limits and a verified SHA-256 digest. Format names identify the
interpretation family; they are not parser capability claims. An implementation
must separately accept the exact grammar and supported descriptor combination
before processing input. Merge profiles, storage codecs and authorization are
independent of this descriptor.

The digest is SHA-256 over the following bytes in order:

1. `transit.document.profile.v1` followed by one zero byte.
2. The current 32-byte contract definition.
3. The one-byte format tag and big-endian u64 interpretation revision.
4. Grammar content: big-endian u64 byte length then its 32-byte SHA-256.
5. Schema then segmenter, each a one-byte presence flag followed by content
   only when present.
6. One-byte encoding, framing, key-collation and value-collation tags.
7. Every limit in declaration order, each encoded as big-endian u64, including
   fields whose public width is u32.

The stored digest is excluded from its own commitment. Public enums assign the
exact numeric tags. `sealed` checks fields and computes a descriptor for local
construction; it does not publish or authorize it. `validate` rejects a changed
field with the old digest. Schema and segmenter identifiers cannot be rebound by
changing a human-readable name.

`Limits` requires positive input bytes, expanded bytes, expansion ratio, parts,
nodes, depth, token bytes, attributes, diagnostics and work. These are per-operation
budgets, not durable collection limits. Parsers enforce their applicable budgets
and publish narrower support where necessary. Resource admission and shared
deployment quotas remain separate. A valid descriptor does not allocate its
maximum capacity or promise a storage/CPU budget reservation.

## Exact capability metadata

`Capabilities` pairs a complete descriptor with independent boolean operations:
`parse`, `construct`, `validate_schema`, `edit`, `persist`, `query`, `search`,
`branch` and `live_transport`. All fields are explicit. `require` validates both
descriptors, requires exact equality and refuses an unsupported operation.
Grammar checking during parsing is distinct from application schema validation.

The pure library's `Profile.capabilities` accepts only its exact JSON/restricted
XML interpretations and reports parse/construct support. Every other operation
is false. Resealing an unsupported grammar, schema, encoding or framing cannot
inherit support from the format name. A capability record is implementation
metadata, not a signed permission, capacity reservation or proof of execution;
adapters must obtain it from their actual owning implementation.

## Parts and provenance

`Span` is a half-open byte interval in a nonzero, full-width `part_id` and an
explicit coordinate space: `raw`, `decoded` or `derived`. Zero-length spans
are permitted. `requireWithin` checks the exact part, space and observed extent.
Lengths and identifiers use u64; host JSON consumers must preserve that range.

`Provenance.exact` names one span. `derived` names an exact source span and an
immutable transformation content commitment. It does not claim a one-to-one
mapping between encoded and transformed bytes. Storage readers must resolve the
named part/revision and verify its extent before disclosing a provenance slice;
shape validation alone cannot do so.

`Part` binds the current definition, nonzero profile digest and part identity,
retained byte count, SHA-256, coverage and optional provenance. An empty part has
the SHA-256 of the empty byte string. For nonempty parts the reader must verify
the actual bytes; this descriptor cannot establish their presence. Coverage is:

- `prefix`: the retained bytes do not establish the whole frame.
- `complete`: all declared permitted bytes are present without an omission.
- `redacted`: explicit omissions prevent an unredacted replay claim.

The hash covers the retained permitted representation only. Never hash or stage
resolved credentials into this representation. `requireExact` rejects prefix or
redacted coverage. Complete byte coverage says nothing about grammar validity,
application success or remote execution. Parent/child references and hashes grant
no read permission or retention hold by themselves.

## Compound representation commitments

`DocumentProfile.Container` adds offline `Manifest`, `Relationship` and exact
external `Reference` types. These do not replace direct Document revisions or
add a stored publication operation. A manifest names its current definition,
interpretation digest, root part ordinal, local part/relationship counts,
retained byte total, separate complete/redacted/prefix counts and directory
commitment. Parts are streamed in strictly increasing nonzero `Part.id` order;
ordinals are zero-based positions in that directory. Relationship order is
significant and follows all local parts. Counts use checked u64 arithmetic.

A relationship binds `contains`, `references`, `derived_from`, `response_to` or
`attachment`, a local source ordinal, a local destination ordinal or an external
reference, and an optional immutable label content commitment. Local endpoints
must exist in the finished part directory. Shared destinations and cycles are
representable; a format validator separately decides their validity and bounds
traversal. A complete directory does not prove root reachability or valid ZIP,
MIME, PDF, XML or application grammar.

An external reference binds a direct Document target (including exact catalog
interpretation and partition), a positive accepted-revision number, a nonzero
manifest digest, an ordinal and the complete expected `Part`. Resolving it must
check the exact accepted revision/manifest and that ordinal's part under current
rights. A name/latest-revision lookup cannot satisfy it. Shape validation does
not establish that any referenced revision or bytes exist, and neither a label
nor a reference acquires access, a retention pin or an effect permit. Provenance
coordinates remain assertions until their named part/extent is resolved.

The manifest digest uses SHA-256 over this canonical stream. Numbers below are
big-endian u64, including partition ordinals whose public width is u32. Tags are
single bytes; there is no implicit native struct encoding.

1. `transit.document.container.v1` plus zero, current 32-byte definition,
   32-byte profile digest and root ordinal.
2. For each local part: tag `1`, then its canonical part bytes.
3. For each relationship: tag `2`, kind (`contains=1`, `references=2`,
   `derived_from=3`, `response_to=4`, `attachment=5`), source ordinal, then
   destination. Local destination is tag `1` and ordinal. External destination
   is tag `2`, target partition definition, realm/resource/catalog/branch/object
   IDs, interpretation revision and digest, partition ordinal, 16-byte logical
   Document ID, accepted revision, manifest digest, part ordinal and canonical
   part bytes. Follow with label presence (`0`/`1`), then content when present.
4. Tag `3`, part count, relationship count, retained bytes, complete part count,
   redacted part count and prefix part count.

Canonical part bytes are definition, profile digest, ID, retained byte count,
SHA-256, coverage (`prefix=1`, `complete=2`, `redacted=3`) and source. Source is
`0` for absent, `1` plus a span for exact, or `2` plus source span and transform
content for derived. A span is part ID, space (`raw=1`, `decoded=2`, `derived=3`),
start and end. Content is byte count followed by SHA-256. The independent
[container fixture](../packages/zig/transit-protocol/src/fixtures/document-profile-container-v1.json)
includes all coverage/source forms, full-width identities, a local cycle and an
unresolved external reference.

`Container.Commitment` computes metadata commitments without reading bytes.
The profile library's `Container` builder additionally hashes every local part's
permitted bytes in bounded calls and refuses incorrect length/hash before adding
that part. `verify` requires the final manifest to match all frozen fields;
intermediate parts never establish container completion. `requireExact` refuses
redacted/prefix local parts. Even exact local coverage leaves external references,
profile grammar, schema validity and durable acceptance unproved. Retain only
permitted bytes: callers redact secrets before feeding this component.

## Offline candidate bindings

`DocumentProfile.Candidate.Binding` freezes a current definition, exact direct
Document target, original `DataLifecycle.Operation`, optional edit base, profile
descriptor and source manifest. The operation's scope must match the target.
An edit base is an exact `Container.Revision` with that same target, including
interpretation; null selects creation. The data owner must establish existence,
current authority and the base precondition independently at acceptance.

The source's profile digest must match the descriptor. Local part count and
retained bytes cannot exceed descriptor `parts` and `input_bytes`; relationship
count cannot exceed `work` (at least one work unit per relationship). The selected
parser/driver enforces its further processing limits. Coverage remains explicit:
a binding can describe incomplete/redacted source metadata, but cannot certify
complete interpretation of that source.

`sealed` validates attribution and computes a commitment. `validate` detects
changed fields; `requireSame` rejects a conflicting original binding. The SHA-256
commitment is the following canonical sequence, with all numbers big-endian u64:

1. `transit.document.candidate.v1` plus zero and current 32-byte definition.
2. Target: partition definition, scope realm/resource/catalog, branch/object,
   interpretation revision and 32-byte digest, partition ordinal and 16-byte
   logical Document ID.
3. Operation scope realm/resource/catalog, principal and operation ID.
4. Base presence (`0`/`1`), then when present its complete target encoding from
   step 2, accepted revision and 32-byte manifest digest.
5. The validated profile descriptor's 32-byte digest.
6. Source manifest definition and profile digest, root/parts/relationships/
   retained-bytes/complete-parts/redacted-parts/prefix-parts counts, then its
   32-byte directory digest. The binding's own digest is excluded.

Neither a binding nor a verified offline candidate registers private staging,
acquires a retention hold, checks that an edit base exists, validates external
part availability, or publishes a revision. There is no candidate storage route
or recovery receipt in this contract. Direct accepted state retains its
[Document operation](DOCUMENT_V1.md) owner. Process-local event-consumption
tickets are buffer handoffs, not durable continuations or acknowledgements.

The pure `Candidate` driver requires one complete local part, root ordinal zero
and no relationships. It recomputes the source metadata commitment and verifies
the complete part's bytes/grammar through `Reader`. It reoffers one pending event
without consuming more input until its exact binding/ordinal ticket is consumed.
Verification requires every event consumed and the source's final length/hash
check. Sink failure, parse/integrity refusal or cancellation invalidates the
candidate; private output must be discarded. A generated output part retains a
new identity/commitment and does not replace the verified source binding.

## Independent observations

`Capture` describes availability: preparing, ready, capturing, complete, unknown
or retired. It is a vocabulary, not an executable effect state machine.
`Validation` separately binds a positive accepted revision, nonempty validator
content commitment, status and diagnostic count. Valid has zero diagnostics;
invalid has at least one; incomplete can have either. It certifies only the
specified validation observation, not byte completeness or remote outcome.

Acknowledgements, native effect intents/permits, attempt budgets, observation
closure and replay/retirement holds keep their existing authority owners under
the [Exchange](STATION_EXCHANGE_V1.md) and [Serving](SERVING_V1.md) contracts.
No value in this module can dispatch, settle, renew authority or release a hold.
Uncertain effects and incomplete frames must remain distinguishable.

## Compatibility and verification

The compound representation types are additive offline contracts; existing declarations, native requests,
stored Document revisions and Exchange records are unchanged. Missing or foreign
definitions reject at strict JSON decoding. The independent Python fixture
computes descriptor commitment bytes; Zig validates that fixture and exercises
changed interpretation, budgets, extents, coverage and validation errors.
Reflected schema validation checks shape, field presence and enum spelling;
domain validation and actual parser/storage acceptance remain separate checks.
