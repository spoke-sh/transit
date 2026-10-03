# Declarative diagnostic v1

The [public `Diagnostic` type](../packages/zig/transit-protocol/src/Diagnostic.zig)
defines a bounded, owned projection of a failure and its execution evidence.
The [generated JSON schema](diagnostic-v1.schema.json) describes its exact shape.
A diagnostic is not a receipt, authorization proof, cancellation acknowledgement
or permission to dispatch. Domain owners establish those facts before projecting
them. Transport adapters must preserve that distinction.

## Fields and bounds

`version` is 1. `definition` is mandatory and equals the shared current contract
definition. Missing/foreign definitions, unknown fields, malformed tagged unions,
unknown enum tags and noncanonical counters reject. Codes have at most 96 ASCII
bytes from lowercase letters, digits, underscores and nonempty dot-separated
components. Codes are stable registry identifiers; English messages and raw
compiler causes are not recovery interfaces. A receiver may display an unfamiliar
well-formed code, but cannot infer retry or outcome from it.

`category`, `stage`, `outcome` and `evidence` are independent fields. The message
holds at most 384 UTF-8 bytes; optional `cause` holds a bounded implementation
identifier. An optional identity names its owning domain and exact operation ID,
with realm/resource/sequence when known. IDs and measurements use canonical
decimal strings with full signed/unsigned 64-bit ranges; native scoped counters
still obey their native ranges. A zero operation ID is invalid.

The optional source location holds a bounded 512-byte source name/path, explicit
path truncation, `source_encoding` (`utf8` or `escaped_bytes`), one-based
statement/line/byte-column coordinates, zero-based
byte offset and byte length. A location without SQL source remains absent; typed
callers do not receive fabricated SQL positions. Numeric coordinates are exact
decimal strings, not JavaScript floating-point values. An escaped byte path uses
printable ASCII bytes except quote/backslash; all other bytes use `\xhh` with
lowercase hex. Escapes are complete even at truncation. The encoding field
prevents mistaking escaped non-UTF-8 filesystem bytes for a Unicode filename.

Sixteen nullable fact slots carry typed text, signed/unsigned integers, booleans,
digests or locations. Present slots form a prefix. Every fact names its semantic
field, origin (caller, execution, schema, authority or owner) and availability.
`provided` and `truncated` require a value; `unrecorded`, `unavailable`, `withheld`
and `inapplicable` forbid one. Bounded text contains at most 256 UTF-8 bytes;
truncation preserves complete code points. Missing detail is never replaced by
an inferred value. `expected_bytes` names an exact required byte length separately
from row, chunk or element counts; its value is an unsigned decimal integer. Entire JSON input/output is bounded to 32 KiB. Validation includes the encoded
size after Unicode/control escaping, including locations nested inside facts.

Four nullable action slots likewise form a prefix. Action kinds are typed;
adapters supply their own correct command spelling. Repeated action kinds reject.
`resume_exact` and cancellation actions require the exact identity in the
diagnostic and an unresolved operation. They are forbidden for applied, rejected,
cancelled or retired outcomes. Effect identities permit `reconcile_effect`, not
generic resume or cancellation. `correct_input` and `recompile` cannot recommend
fresh work while an operation is unresolved or has rejected input still requiring
reconciliation. Read/inspection actions do not grant access.

## Evidence and disclosure

`not_submitted` requires local before-dispatch evidence; `prepared` requires saved
intent; pending requires native acceptance or domain status. Applied, rejected,
cancelled, retired, input-rejected and closed-with-unknown-outcome require domain
status. Unknown send cannot carry a fabricated receipt or terminal domain result.
Failures during result reading/output/cleanup do not change a saved domain outcome.

Relevant caller-owned names, values, parameter indices and attempted keys are
valid correction context. Owners must not enrich them with unauthorized stored
values, inaccessible catalog names or credential/SECRET contents. Retained
execution evidence remains subject to current disclosure rights. Human renderers
must escape control/terminal bytes; JSON encoding alone is not terminal escaping.
The entire diagnostic is excluded from telemetry payloads and unrelated logs.

Construction and fact insertion allocate no memory. Decoding uses caller-owned
bounded input and parser allocation, then returns fully owned values. Failure to
allocate, retain or render diagnostic detail cannot change execution authority,
replace the primary cause, declare uncertain work rejected or authorize a new
submission. A caller that cannot obtain detail must retain its original saved
operation and outcome evidence.

The standalone generated diagnostic schema describes emitted envelopes: fields
with Zig defaults are still present in JSON. The neutral browser
[`transit-diagnostics`](../packages/ts/transit-diagnostics/README.md) library owns
validation and rendering for query, application and reactive callers. Invalid
optional detail cannot replace their primary transport or domain result.

## Coverage

The [source inventory](diagnostics/README.md) owns diagnostic-surface drift.
Per-domain mappings and executable adapter evidence determine which public
surfaces expose this contract. The existence of this type/schema alone does not
establish adapter adoption or complete semantic coverage.
