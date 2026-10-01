# Fuze bounded file sources v1

This contract defines deterministic CSV and JSONL discovery over bytes supplied
by an authorized host. Fuze performs no filesystem or network access. The host
owns acquisition, source freezing, cancellation and any explicitly budgeted
spooling. Replay reads captured immutable bytes; it never implicitly refetches.

## Binding and modes

A binding freezes the current algorithm definition, ordered source content
commitments and lengths, format/options, discovery mode, overrides, evidence and
resolved schema fingerprint before publishing a result. A filename, timestamp or
unverified remote tag is not a content commitment. Every pass validates its source
basis. Changed bytes/options/schema reject continuation and cache reuse.

Modes are complete explicit schema, partial overrides with bounded sampling,
bounded sampling, explicit full-input discovery and lossless raw. Samples are
prefixes with independently bounded records and bytes; evidence records actual
coverage and whether EOF was observed. A sample is not full-input validation.
Empty/all-null columns require an explicit override or raw representation.
Full discovery scans sequentially under a work budget and does not retain rows.
Raw CSV preserves decoded text and configured null distinctions; raw JSON keeps
JSON structure and numeric lexemes. Full discovery and sampled execution operate
on the same immutable source, with no accepted-job restart under new meaning.

## Framing and alignment

CSV explicitly configures a single-byte ASCII delimiter and quote, doubled-quote
escaping, header presence and null tokens. UTF-8 is required; an optional UTF-8
BOM is recognized only at source start. LF and CRLF delimit records outside
quotes. Quoted fields may contain newlines. Whitespace is data. Quoted empty text
is distinct from a configured unquoted null token. Malformed quoting, ragged rows,
duplicate/empty names and invalid UTF-8 reject. Dialect/header guessing is not
performed without an explicit contract.

JSONL accepts one complete JSON object per nonempty line, with LF or CRLF and an
optional final line without a newline. Blank lines reject. Keys are decoded UTF-8;
duplicate keys reject even when escape spellings differ. Missing fields differ
from null. Nested arrays/objects retain structure; numbers never pass through
binary floating point during discovery. Maximum record bytes, decoded bytes,
fields, children, nesting and parser work are independently checked.

Multiple sources align by exact decoded names, with deterministic schema order.
A missing field becomes missing only where the schema permits it. Unknown fields
and incompatible late values follow the selected strict failure or typed-error
policy; no row is skipped and projections cannot hide decoding errors. A new
schema requires a new binding. Ordered source identity determines row order.

## Host and completion boundary

The host provides bounded chunks and checks current access before disclosure.
Compressed data must be decoded by an explicit host adapter with separate encoded
and expanded byte quotas. Non-seekable discovery/execution requires an immutable
capture with explicit disk quota; otherwise replay-dependent modes reject. Source
and result cardinality may exceed resident memory; active buffers and metadata
are bounded independently. Cancellation is checked between bounded parser steps
and terminates with no complete result marker. Cleanup joins all active work and
releases host resources; a local cancel does not retract already disclosed rows.

A result prefix is provisional until the terminal source commitment and complete
coverage checks succeed. Failed, denied, changed or cancelled inputs have no
successful completion footer. Persisting accepted file work requires a separate
recorded capture/job integration and its disk-backed recovery proof; this pure
contract alone supplies neither durability nor authority.

## Implemented pure source profile

The [local Zig API](../packages/zig/transit-fuze/docs/file-sources.md) implements
explicit/partial/sampled/full/raw discovery, owned recursive values, current
host checks, source verification and frozen-binding save/restore. Its capability
and limit tables are authoritative for this profile. Acquisition, compression,
non-seekable spooling, native query admission and durable capture are host
integrations; no implementation of those boundaries is implied here.
Unknown fields always fail. The optional type-error policy applies only to
representable value-conversion failures, not framing, required/nullability,
authorization, cancellation, allocation or work-budget failures. Raw mode rejects
overrides. CSV accepts supported scalar literals; recursive/JSON/interval CSV
overrides reject. JSON object/array/null/value shapes are explicit in the guide.

## Canonical saved binding

`FSB1` contains magic, u8 definition length, the mandatory UTF-8 definition
`transit.fuze.source.v1.2026-09-30`, then options: u8 format (0 CSV, 1 JSONL),
u8 mode (0 explicit, 1 sampled, 2 full, 3 raw), u8 mismatch (0 fail, 1 typed
error), delimiter, quote and canonical boolean header. Six little-endian u64s
encode sample records/bytes, scan bytes, maximum records, record bytes and fields.
A u8 null-token count precedes each u16-length token. The next u16 length prefixes
a complete `FTY1` schema. Evidence is u64 sampled records/bytes and canonical
boolean complete-discovery flag. A u8 field count precedes origin bytes (0 inferred,
1 specified, 2 raw), followed by 32-byte source-list and binding commitments.
Missing/foreign definitions, invalid parameters, inconsistent evidence and
trailing bytes reject. No credential, path or callback pointer is serialized.

Source-list identity hashes the source definition string, u64 source count and
ordered `(u64 length, SHA-256 content)` pairs. Option identity hashes the same
definition, six option bytes, six u64 budgets and null-token encoding above.
Binding identity hashes the definition, `FTY1` fingerprint, option commitment,
source-list commitment, evidence u64 records/bytes, origin bytes and complete
boolean, in that order. These are content commitments, not signatures or grants.
Restore requires matching acquired handles and current host authorization.
