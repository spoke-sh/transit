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
Raw CSV preserves text, quoting and configured null distinctions; raw JSON keeps
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
