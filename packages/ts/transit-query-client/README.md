# Transit query browser primitives

Private package for Board and generated applications. Request, response and
draft-budget declarations derive directly from `transit-query.Workspace`, with
CSP-compatible generated validators. Board's OpenAPI reflection is checked against
the same owning definitions. This package does not compile SQL or confer authority.

`httpTransport(path, timeoutMs)` calls one configured same-origin host. It bounds
requests to 64 KiB and decoded replies to 1 MiB before parsing, validates response
structure and semantic cell/budget bounds. At most three retries
use the identical request for pre-dispatch 429s or explicit 409 read conflicts
(`QueryReadConflict` / Board's `QueryExpired`) or classified 503 authority failures
(`AuthorityUnavailable` / `AuthorityTimeout`) on an allowlisted read/preparation
operation. Throttling and read conflicts wait 250 ms between attempts; classified
503 reads back off for 500 ms, one second and two seconds so occupied native
request slots can drain. Signed `submit` never retries a conflict or 503 automatically. Denial, changed
contracts and unknown failures do not acquire this retry policy. Keep frozen
prepared tokens through every uncertain submission. Choose the timeout above the host's bounded request deadline; the
default six seconds matches Board's five-second host profile.

`QueryError` retains the primary HTTP `status` and finite `code`. Its optional
`diagnostic` is an owned, bounded copy of the current diagnostic contract;
`diagnosticInvalid` flags rejected detail without changing the primary failure
or retry policy. Validation checks shape, definition, UTF-8/byte/number bounds,
evidence and action targets. Saved status diagnostics must agree with their
returned domain outcome. `diagnosticLines` produces caller-facing text, including
unavailable facts and exact counters; it does not issue requests. Error messages
contain the finite identifier so a caller chooses explicitly when to display
detailed names or values. `DraftSnapshot.diagnostic` retains the failed attempt
or saved outcome and clears on a new state transition.

`{ inspect: { sql } }` reads scoped `DESCRIBE`, `SHOW TABLES` or `EXPLAIN SELECT`
metadata through the same transport. Its `inspection` response remains separate
from compiled bundles and Arrow results. Validation checks full-width revisions,
configured Table scope, operator order, projection/output agreement and budgets;
it rejects extra literal values through the generated strict schema. Nullable
comparison atoms validate their source column/type without inventing a literal
value; they remain distinct from `IS NULL` state predicates. Inspection
is on the explicit read-conflict retry allowlist and cannot submit a query.

`verifiedPage` performs a bounded full-coverage pass over one immutable result,
then rereads the selected visible page under current authority. It holds one
segment at a time and rejects mixed manifests, incorrect coverage and cancellation.
The supplied read adapter owns transport and must validate its responses.
`unifiedCellText` preserves full-width integers and distinguishes missing, null,
type errors and concurrent alternatives. A source/result contract is evidence,
not an access grant.

Board now consumes the package for v1 transport, semantic values and full-result
verification. Focused types/transport/coverage checks and the actual native Table
API/browser regression pass. `DraftSession` now owns one coalesced edit, one accepted finite query and one
frozen native input above route lifetimes. Explicit enable/resume uses the recorded
one-to-eight intent budget; debounce, retries, navigation and browser recovery
cannot reset it. Pause closes scheduling without cancelling accepted work; explicit
cancel remains separate. Save recovery before reloading while work is pending,
then restore and explicitly recover the original namespace/bundle/signature. Files
contain no keys or result pages and confer no authority. Query result publication
requires full coverage and a current visible reread; embedding applications must
continue current-authority checks while displaying held results.

The actual Table host/browser proof passes lost upload replies, browser reload,
exact recovery, rapid edit coalescing, two-intent exhaustion and current denial.
Seven scheduler tests cover pause, explicit cancellation, known rejection and
control recovery. KV/Document Live draft execution is not enabled. Timings are
browser-observed compilation, upload through observed completion, and verification;
server execution time and source age remain unavailable.

`pageProfile` derives exact cell-state counts from the supplied verified visible
page, preserving value, null, missing, type error and conflict. It neither reads
more data nor changes the result basis. Board's monochrome chart uses a fixed
eight-row page scale and labels the query, source revision and limited coverage.

`AssistanceReader` consumes the native [cursor-assistance contract](../../../contracts/QUERY_ASSISTANCE_V1.md).
It owns one outstanding request and one coalesced edit, discards stale generations,
and refreshes an open list every five seconds under current authority. Closing,
hiding or disposing a view aborts its read and clears metadata. Source-contract
changes fail visibly; denial also invokes the embedding owner's clearing path.
`byteCursor` validates UTF-16/UTF-8 boundaries; `applySuggestion` replaces the
complete token suffix without submitting. The UI owns one-step undo and rendering;
this package contains no SQL keywords, parser or catalog replica. Its fixtures
cover late replies, edit coalescing, denial, changed contracts and Unicode ranges.

Query columns carry the complete logical descriptor, nullability and optionality.
Results admit at most eight rows and 128 columns per page; recursive descriptors
retain the shared 16-level, 256-node and 4096-name-byte limits. Names contain up to
255 UTF-8 bytes. Generated validators resolve recursive references within their
own document, and a finite JSON shape check precedes their traversal. Semantic
checks preserve each scalar width, finite floats, decimal coefficients/scale,
temporal units, nested states, exact array lengths, ordered map keys and distinct
union alternatives. JSON cells retain their numeric lexemes and reject duplicate
decoded field names. The 1 MiB transport response limit remains independent of
logical value and Arrow segment bounds.

`unifiedCellText(cell, type)` uses the column descriptor to format decimal scale
and nested names, quotes text, and preserves signed zero and full-width integers.
Without a decimal descriptor it labels the stored coefficient explicitly.
`logicalTypeText` renders the descriptor for labels. Query manifests retain
`basis.cut` (kind, resource, revision, immutable head commitment), the source
contract and the logical schema separately. These fields never extend current
read access or retained coverage.
