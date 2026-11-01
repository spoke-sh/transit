# transit-document-profiles

Pure, incremental interpretation of bounded Document parts. Applications can
parse JSON or the XML subset below using caller-owned buffers, inspect ordered
events and raw source coordinates, and verify a retained part's complete byte
commitment. The package imports only `transit-protocol`; it has no allocator,
socket, TLS, clock, storage, Station or effect-dispatch interface.

The [profile contract](../../../contracts/DOCUMENT_PROFILE_V1.md) owns descriptor
identity, processing limits, coverage and provenance. This library is an offline
component. It does not publish Documents, shred paths into storage, validate an
application schema, resolve dependencies, or activate a gateway. The installed
[Document service](../transit-station-document/README.md) keeps its own acceptance
and merge lifecycle.

## Qualified interpretations

`Profile.descriptor(format, limits)` seals the exact implemented grammar,
UTF-8 encoding, single-part framing and binary key/value collation. `Json.init`,
`Xml.init` and `Reader.init` reject a different grammar, interpretation revision,
schema, segmenter, encoding, framing or collation, including a correctly resealed
unsupported descriptor. Names in the neutral format enum are vocabulary; other
formats return `UnsupportedDocumentProfile`.

| Profile | Interpretation | Explicit exclusions |
| --- | --- | --- |
| JSON | [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259) UTF-8 values; ordered object keys including duplicates; exact number lexemes; decoded Unicode scalars and surrogate pairs | BOM, lone surrogate escapes, nonfinite numbers, schema validation, numeric coercion and duplicate-key selection |
| XML | [XML 1.0 fifth edition](https://www.w3.org/TR/2008/REC-xml-20081126/) UTF-8 subset; one root; ASCII element/attribute/PI names; ordered unique attributes; mixed content, comments, CDATA and processing instructions; optional version 1.0 declaration with UTF-8 encoding and yes/no standalone; predefined/numeric entities; line-ending and attribute whitespace normalization | BOM, non-ASCII names, namespaces/`xmlns`, DTDs, custom/external entities, external resolution, non-UTF-8 encodings and application schema validation |

These are scalar reference parsers. No SIMD throughput, full XML conformance,
namespace processing, container support or installed runtime claim follows from
these component checks. Raw bytes remain the caller's responsibility; decoded
values do not replace the source representation.

## Workspace and stepping

JSON takes `[]Json.Frame` with at least `limits.depth` entries and a token buffer
with at least `limits.token_bytes` bytes. XML takes `Xml.Workspace`: depth frames,
`depth * token_bytes` bytes of name-stack storage, `attributes` attribute slots,
and separate raw/decoded buffers of `token_bytes` bytes each. Initialization
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
XML can additionally finalize one bounded token or emit one pending attribute.
XML finalization is bounded by `token_bytes * (attributes + 4)` byte inspections;
duplicate detection is bounded by the per-element attribute quota. The total
`limits.work` counter charges input bytes and XML's additional scans; it is a
deterministic processing meter, not a CPU-cycle estimate. Exceeding it fails.
A host needing a smaller scheduling quantum must also choose smaller token and
attribute limits.

Both parsers enforce input, expanded-output, node, depth, token and work limits;
XML also enforces attributes per element. JSON token limits count decoded string
bytes or exact number/literal bytes. XML token limits bound each complete raw
markup/text token, including all attributes of an opening tag. The XML name
stack therefore has an explicit `depth * token_bytes` bound. No entity expansion
can exceed its input length, so every positive expansion-ratio limit is honored.
Each parser has one part and one sticky diagnostic, within any positive parts
and diagnostics quota. Quotas limit an operation, not a stored collection.

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

`Reader.init(descriptor, part, workspace)` additionally requires complete,
unredacted coverage, a matching profile digest and a part length within the
input budget. Its `next` hashes exactly the consumed bytes and reports complete
only when grammar, byte count and SHA-256 all agree. `verifiedPart()` refuses
until then. A valid replacement document with a different hash fails. An event
prefix remains provisional even when it was emitted before a late grammar/hash
failure. Applications staging projections must discard or explicitly mark such
prefixes; these APIs never accept a stored revision or grant effect authority.

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
100,000-field/element inputs with unchanged workspace. The probe owns its I/O;
production parsing remains pure. The oracle runs under `test-fixtures`, package
tests under `test-components`, and standalone manifests under
`just test::packages-build`. These checks establish no disk durability, gateway
exchange or remote-effect result.
