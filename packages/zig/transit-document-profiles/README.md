# transit-document-profiles

Pure, incremental interpretation and construction of bounded Document parts.
Applications can parse or construct JSON and the XML subset below, or parse
MIME entity frames, using caller-owned buffers. They can inspect ordered events
and raw source coordinates, verify retained bytes, and build compound
representation commitments. The package
imports only `transit-protocol`; it has no allocator,
socket, TLS, clock, storage, Station or effect-dispatch interface.

The [profile contract](../../../contracts/DOCUMENT_PROFILE_V1.md) owns descriptor
identity, processing limits, coverage and provenance. This library is an offline
component. It does not publish Documents, shred paths into storage, validate an
application schema, resolve dependencies, or activate a gateway. The installed
[Document service](../transit-station-document/README.md) keeps its own acceptance
and merge lifecycle.

## Qualified interpretations

`Profile.descriptor(format, limits)` seals the exact implemented grammar,
encoding, single-part framing and key/value collations. JSON/XML use UTF-8 and
binary collation; MIME uses binary encoding and ASCII case-insensitive field-name
comparison while preserving original spelling. `Json.init`, `Xml.init`,
`Mime.init` and `Reader.init` reject a different grammar, interpretation revision,
schema, segmenter, encoding, framing or collation, including a correctly resealed
unsupported descriptor. Names in the neutral format enum are vocabulary; other
formats return `UnsupportedDocumentProfile`.

| Profile | Interpretation | Explicit exclusions |
| --- | --- | --- |
| JSON | [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259) UTF-8 values; ordered object keys including duplicates; exact number lexemes; decoded Unicode scalars and surrogate pairs | BOM, lone surrogate escapes, nonfinite numbers, schema validation, numeric coercion and duplicate-key selection |
| XML | [XML 1.0 fifth edition](https://www.w3.org/TR/2008/REC-xml-20081126/) UTF-8 subset; one root; ASCII element/attribute/PI names; ordered unique attributes; mixed content, comments, CDATA and processing instructions; optional version 1.0 declaration with UTF-8 encoding and yes/no standalone; predefined/numeric entities; line-ending and attribute whitespace normalization | BOM, non-ASCII names, namespaces/`xmlns`, DTDs, custom/external entities, external resolution, non-UTF-8 encodings and application schema validation |
| MIME entity frame | Ordered duplicate-preserving ASCII fields, CRLF unfolding, a required empty CRLF line and an opaque binary body; [exact framing contract](../../../contracts/DOCUMENT_PROFILE_V1.md#mime-entity-frame-interpretation) | Non-ASCII headers, bare CR/LF, field/media-type validation, multipart interpretation, transfer decoding, encoded-word decoding, construction and transport |

These are scalar reference parsers. No SIMD throughput, full XML conformance,
namespace processing, archive unpacking or installed runtime claim follows from
these component checks. Raw bytes remain the caller's responsibility; decoded
values do not replace the source representation.

`Profile.capabilities(descriptor)` reports parse/construct support for the exact
JSON/XML interpretations and parse-only support for MIME framing. Schema
validation, editing, persistence, query,
search, branching and live transport are separately false. Use the returned
`require(descriptor, capability)` check when selecting a local implementation;
it grants no data permission or resource reservation. Unsupported resealed
descriptors refuse rather than inheriting capabilities from their format name.

## Workspace and stepping

JSON takes `[]Json.Frame` with at least `limits.depth` entries and a token buffer
with at least `limits.token_bytes` bytes. XML takes `Xml.Workspace`: depth frames,
`depth * token_bytes` bytes of name-stack storage, `attributes` attribute slots,
and separate raw/decoded buffers of `token_bytes` bytes each. MIME takes
`Mime.Workspace` with separate raw/unfolded buffers of `token_bytes` bytes each.
Initialization
checks size multiplication and buffer lengths before processing. Buffers must be
non-overlapping and exclusively owned by that parser until it is discarded.
Durable/input cardinality does not grow this resident workspace. Choose limits
appropriate to the operation before allocating workspace; descriptors reserve no
memory or deployment quota.

`next(input, eof, work)` returns the number of consumed bytes and one result:

- `event`: consume its borrowed `value` and `detail` before the next parser call.
  Copy into separately owned output if it must survive. The input slice itself
  may be released after the call; parser state never retains a pointer into it.
- `need_input`: this slice was consumed and a final frame boundary is still needed.
- `yield`: the input-byte work allowance was reached with an unconsumed tail.
- `complete`: the entire frame and trailing permitted whitespace were consumed.

Pass each unconsumed tail again. `eof` marks the end of the supplied final slice;
continue using it while draining that tail and any pending events. An event can
consume zero input bytes. Never equate a root-end event, a filled display window
or transport EOF with completion. Parsing/refusal errors are sticky and expose
a `failure_offset` through the raw parsers: the number of bytes consumed when the
failure was observed, not necessarily the beginning of the offending lexeme.
`work == 0` is a caller error and does not poison state. Repeated completion is
idempotent; extra bytes after completion are refused. Reinitialization starts a
new explicitly separate frame.

Each call consumes at most `work` new bytes. JSON does constant work per byte;
XML can additionally finalize one bounded token or emit one pending attribute;
MIME can unfold one field with at most `token_bytes` additional inspections.
XML finalization is bounded by `token_bytes * (attributes + 4)` byte inspections;
duplicate detection is bounded by the per-element attribute quota. The total
`limits.work` counter charges input bytes and additional scans; it is a
deterministic processing meter, not a CPU-cycle estimate. Exceeding it fails.
A host needing a smaller scheduling quantum must also choose smaller token and
attribute limits.

The JSON/XML parsers enforce input, expanded-output, node, depth, token and work limits;
XML also enforces attributes per element. JSON token limits count decoded string
bytes or exact number/literal bytes. XML token limits bound each complete raw
markup/text token, including all attributes of an opening tag. The XML name
stack therefore has an explicit `depth * token_bytes` bound. No entity expansion
can exceed its input length, so every positive expansion-ratio limit is honored.
Each parser has one part and one sticky diagnostic, within any positive parts
and diagnostics quota. Quotas limit an operation, not a stored collection.

MIME has no nesting. Its input, expanded-output, token and work limits bound the
complete entity, and `attributes` bounds its field count. Each field and one
logical body, including an empty body, count against `nodes`; fetching smaller
body windows does not consume additional nodes. A folded field, including its
final CRLF, must fit `token_bytes`, and every physical header line is limited to
998 bytes excluding CRLF. A body can exceed either buffer: each call copies at
most the smaller of input, work allowance and `token_bytes` into a borrowed event.

## Events and provenance

Events retain order and use half-open raw `(part_id, byte_start, byte_end)` spans.
Keys, scalar values and attributes carry their complete source lexemes. JSON
container starts/ends each cover their punctuation. XML element events cover
the complete opening/closing markup; an empty element's start and end share the
same span. CDATA text covers its complete markup. Decoded values may differ from
the raw span through escapes or normalization.

Container/element starts and ends have the parent's depth. Their fields, text
and attributes have the child depth. Attributes use `value` for the name and
`detail` for the decoded value; processing instructions use the target and body.
Other scalar/text values use `value`. The XML declaration and whitespace outside
the root emit no events. Empty CDATA may emit empty text; chunk boundaries do not
split text events. JSON duplicate keys remain separate ordered events.

MIME emits `mime_field` with the original field name in `value` and unfolded
field bytes in `detail`. Only internal CRLFs are removed; spaces, tabs and
duplicate order remain. Its span includes folds and excludes the final CRLF.
`mime_headers_end` spans the mandatory empty separator line. `mime_body` events
cover contiguous binary body slices, including any NUL or non-UTF-8 bytes.
Their window boundaries have no semantic part identity. All MIME events have
depth zero; an empty body emits no body slice. This grammar validates framing
only: a `Content-Type` field does not activate multipart parsing or decoding,
and no SMTP envelope or full mail-message validation is supplied.

`Reader.init(descriptor, part, workspace)` additionally requires complete,
unredacted coverage, a matching profile digest and a part length within the
input budget. Its `next` hashes exactly the consumed bytes and reports complete
only when grammar, byte count and SHA-256 all agree. `verifiedPart()` refuses
until then. A valid replacement document with a different hash fails. An event
prefix remains provisional even when it was emitted before a late grammar/hash
failure. Applications staging projections must discard or explicitly mark such
prefixes; these APIs never accept a stored revision or grant effect authority.

## Resumable candidate handoff

`Candidate.init(binding, part, workspace)` composes `Reader` with an explicit
consumer handoff. The [candidate binding](../../../contracts/DOCUMENT_PROFILE_V1.md#offline-candidate-bindings)
freezes an original operation, target, optional exact edit base, interpretation
and source manifest. The driver supports one complete local part, root ordinal
zero and no relationships. It checks the manifest's metadata commitment against
that part, then verifies source bytes and grammar as they are consumed. This is
offline preparation; the target and edit base are not looked up or authorized.

`next(input, eof, work)` returns consumed input bytes and `event`, `need_input`,
`yield` or `verified`. An event contains a binding/ordinal `ticket` and the
borrowed parser event. Copy or finish consuming its values, then call
`consume(ticket)`. Until that succeeds, repeated `next` calls return the same
event with zero input consumption, preserving parser workspace. Consume the
reported input prefix exactly once and resubmit its tail. A stale/foreign ticket
or a second consumption refuses without poisoning the current candidate.
The source input may be released after each call; event bytes must not survive
consumption followed by another parser call. Keep the caller-owned workspace
exclusive for the candidate's entire lifetime.

`pump(input, eof, work, sink)` is an optional push adapter. A sink implements
`pub fn offer(self, event) !Candidate.Offered`, returning `consumed` only after
using/copying the whole event, or `blocked` without consuming a prefix. One pump
invokes the sink at most once and reports `progress` or `blocked` in addition to
the input/verification states. The sink bounds its own work and output storage;
the driver adds no queue or allocator. Sink errors, parser errors and late
length/hash failure poison the candidate and preserve the first error in `cause`.
Discard all private sink output on failure. Further calls return
`DocumentCandidateFailed`; they cannot resume a partly failed parse.

`verifiedPart` and `verifiedBinding` succeed only after every event is consumed
and the reader verifies its final bytes. Root-end events, empty input and filled
output windows do not establish verification. `cancel` invalidates even a locally
verified candidate, drops its pending event and is idempotent; existing failures
keep their original cause. Zero work and trailing input after verification remain
caller errors with the same non-poisoning behavior as `Reader`.

For semantic serialization, pass a pending event to `JsonWriter.beginEvent` or
`XmlWriter.beginEvent`, drain bounded output windows, then consume its ticket.
Generated output gets a new part ID and commitment. A completed writer or
compound verifier cannot establish that the original source finished: require
the source candidate's verified binding separately before using derived output.
The driver owns constant state plus the existing parser workspace. It supplies
no durable staging continuation, edit engine, graph resolver or publication
operation; a binding cannot acquire a retention hold by itself.

## JSON construction and semantic serialization

`JsonWriter.init(descriptor, new_part_id, frames)` accepts the same exact JSON
interpretation as `Json`. Provide `limits.depth` caller-owned `JsonWriter.Frame`
slots. Submit `JsonWriter.Token` values with `begin`, then drain the token with
`drain(output, work_budget)` until `needsDrain()` is false. `beginEvent` adapts a
JSON parser event and checks its nesting depth. Strings, keys and number lexemes
are borrowed until fully drained; drain before advancing the source parser or
resetting its workspace. Output belongs to the caller and is never retained.

Construction preserves member order, duplicate keys, UTF-8 values and exact
number lexemes without floating-point conversion. It emits compact JSON, quotes
and backslashes with escapes, and control characters as `\u00xx`. It validates
Unicode, number grammar, object/key/value order and nesting. XML events are
refused. This is semantic serialization into a new part: original whitespace,
escape spelling and source byte coordinates are not preserved. A source
`Reader` must still reach verified completion before its re-encoded candidate
can be accepted; a complete generated root cannot validate unread source bytes.

`finish` requires one complete root and no pending token and returns a complete
`Part` with the generated byte count and SHA-256, without publishing it. Repeated
finish returns the same part. A busy writer or zero drain window/work budget is
a recoverable caller error. Invalid tokens, budget exhaustion and finishing an
incomplete root poison the writer; discard partial output or retain it only as
explicit incomplete evidence. No allocator or growing node array is used.

Descriptor limits bound generated raw bytes (`input_bytes`), scalar/key bytes
(`expanded_bytes`), nodes, nesting and token bytes. Work charges one per token,
one per scalar/key byte inspected during `begin`, and one per emitted byte.
`begin` does at most one bounded token validation; `drain` emits at most the
smaller of its output window and work allowance. These are deterministic work
units, not CPU cycles. Empty strings and duplicate keys remain meaningful.

## XML construction and semantic serialization

`XmlWriter` accepts the same exact interpretation descriptor as `Xml`, with
`Token` values for elements, attributes, text, comments and processing
instructions. `beginEvent` also checks parser-event depth and closing names.
Submit one token with `begin`, drain its bytes, then submit the next. Its
`Workspace` owns `depth` frames, `depth * token_bytes` name-stack bytes,
`attributes` duplicate-detection slots, `token_bytes` attribute-name bytes and
`token_bytes + 1` encoded bytes. Initialization checks all sizes. Keep workspace
buffers non-overlapping and exclusively owned until the writer is discarded.
Each token is copied into workspace during `begin`; its source may then be
released. Output is caller-owned. No allocator or resident node list is used.

Construction preserves ordered unique attributes and mixed content, escapes
reserved characters, and uses numeric references for carriage returns and
attribute tabs/newlines. Empty elements use `/>`. XML declarations, CDATA
spelling, original quotes and raw source coordinates are not reproduced.
Comments containing `--`, a trailing `-` or carriage returns, and processing
instructions with `?>`, carriage returns or leading body whitespace are refused
because they cannot preserve the supplied value in this grammar. Namespace
names and `xmlns`, non-ASCII names, invalid XML characters and duplicate
attributes are refused. A completed source `Reader` remains necessary when
re-encoding retained bytes; writer completion does not validate that source.

Generated bytes, names/values, nodes, depth and attributes have the descriptor's
limits. `expanded_bytes` includes generated nonempty closing names. Escaped
opening markup and consecutive text also fit the parser's `token_bytes` limit;
escaping can therefore refuse an otherwise short semantic value. Work charges
one per token, three per supplied name/value byte (and generated nonempty closing
name byte), each attribute-name comparison byte, and each emitted byte. `begin`
stages one bounded token; `drain` emits at most its output window and work budget.
These bounds do not claim CPU-cycle timing or that a separately budgeted reader
will accept every generated part.

`finish` requires exactly one closed root with all bytes drained and returns the
generated complete `Part` and SHA-256. Busy/zero-window/zero-work caller errors
are recoverable. Invalid input, exceeded limits and premature finish are sticky;
partial output cannot establish complete coverage. Repeated successful finish is
idempotent. As with JSON construction, publication, revision acceptance and
effect authority belong to other owners.

## Compound representation construction

`Container.init(profile_digest, root_ordinal, limits)` builds a manifest from
local parts in increasing `Part.id` order. Call `beginPart`, repeatedly
`append(bytes, work_budget)`, then `endPart`; each call consumes at most its byte
work allowance and retains no input pointer. Only one part is active. After all
parts, call `addRelationship` for each ordered relationship and `finish`.
`Container.verify(expected_manifest, limits)` uses the same protocol and requires
exact final metadata/commitment equality. `verifiedManifest` refuses before
successful finish or after a sticky failure. Repeated finish is idempotent;
additional input after finish is rejected.

The builder owns constant-sized state and no allocator. Limits separately bound
local part count, relationship count, retained bytes and work; only part count
and work must be positive. Empty parts and a directory with no relationships are
valid. Work charges each hashed input byte and one unit per successful begin,
end, relationship and finish operation; it is a deterministic accounting unit,
not CPU cycles. Metadata records have fixed bounded shape. `append` accepts only
bytes inside the current part's declared remaining extent; its zero work budget
is a non-sticky caller error. Other processing refusals poison the builder, so a
partially verified container cannot later report success.

The [contract](../../../contracts/DOCUMENT_PROFILE_V1.md#compound-representation-commitments)
owns canonical metadata bytes and exact external references. Local endpoints
use directory ordinals; cycles/shared references are preserved. This component
verifies local byte commitments and endpoint membership, not graph reachability,
external-reference resolution, grammar, decompression, authorization, retention
or stored revision acceptance. `finish` preserves incomplete/redacted coverage;
call `requireExact` separately when complete local replay is required. A caller
must obtain current rights and redact resolved credentials before feeding bytes.
Format-specific expansion/validation still belongs to the selected parser.

## Verification

Inside the pinned `nix develop` shell:

```sh
cd packages/zig/transit-document-profiles
zig build check
zig build test
zig build test -Doptimize=ReleaseSafe
```

From the repository root, `zig build test-document-profiles` compares the shared
parsers against Python JSON and Expat using deterministic generated documents,
byte mutations and multiple chunk sizes. It checks exact JSON source spans,
scalar values, duplicate ordering, XML attributes/mixed content, completion and
malformed-input refusal. Package tests cover every split in reference inputs,
resource limits, unsupported interpretation, late hash/length failure and
100,000-field/element inputs with unchanged workspace. The same probe re-encodes
JSON and XML through one-byte and larger output windows; Python/Expat independently
check duplicate order, exact number lexemes, ordered attributes, mixed content,
semantic round trips and generated SHA-256 commitments. The probe owns its I/O;
production parsing remains pure. The oracle runs under `test-fixtures`, package
tests under `test-components`, and standalone manifests under
`just test::packages-build`. Container tests additionally verify the independent
manifest fixture, sticky failures, changed parts/references, quotas and 100,000 streamed parts/relationships
without a resident directory. These checks establish no disk durability, gateway
exchange or remote-effect result.

The same probe compares MIME fields and order with Python's `email` header
parser and checks independently generated raw spans, unfolded values and binary
body bytes across reader/candidate schedules. Explicit strict-framing refusals
are checked separately from that parser's permissive recovery. Package tests
cover every split, header quotas, late hash failure and cancellation; a
400,000-byte body streams through two three-byte buffers with one logical node.

Candidate checks cover every input split with overwritten caller input, delayed
event consumption, stale/foreign tickets, cancellation, sink errors, resource
refusal and late hash failure after generated output is already complete. A
100,000-value stream uses unchanged workspace. The independent Python/Expat
probe checks both raw readers and candidate delivery against its own expected
events/spans and routes semantic construction through the candidate handoff.
