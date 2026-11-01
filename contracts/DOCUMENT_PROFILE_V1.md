# Document interpretation and provenance v1

[`DocumentProfile`](../packages/zig/transit-protocol/src/DocumentProfile.zig)
defines offline interpretation descriptors, bounded processing limits, part
coverage and byte provenance. The reflected
[schema](document-profile-v1.schema.json) is generated from these public Zig
types. The [independent fixture](../packages/zig/transit-protocol/src/fixtures/document-profile-v1.json)
binds exact commitment bytes and full-width identities.

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

This is an additive offline contract; existing declarations, native requests,
stored Document revisions and Exchange records are unchanged. Missing or foreign
definitions reject at strict JSON decoding. The independent Python fixture
computes descriptor commitment bytes; Zig validates that fixture and exercises
changed interpretation, budgets, extents, coverage and validation errors.
Reflected schema validation checks shape, field presence and enum spelling;
domain validation and actual parser/storage acceptance remain separate checks.
