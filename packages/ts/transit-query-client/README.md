# Transit query browser primitives

Private package for Board and generated applications. Request, response and
draft-budget declarations derive directly from `transit-query.Workspace`, with
CSP-compatible generated validators. Board's OpenAPI reflection is checked against
the same owning definitions. This package does not compile SQL or confer authority.

`httpTransport(path, timeoutMs)` calls one configured same-origin host. It bounds
requests to 48 KiB and decoded replies to 1 MiB before parsing, validates response
structure and semantic cell/budget bounds. At most three retries, 250 ms apart,
use the identical request for pre-dispatch 429s or explicit 409 read conflicts
(`QueryReadConflict` / Board's `QueryExpired`) or classified 503 authority failures
(`AuthorityUnavailable` / `AuthorityTimeout`) on an allowlisted read/preparation
operation. Signed `submit` never retries a conflict or 503 automatically. Denial, changed
contracts and unknown failures do not acquire this retry policy. Keep frozen
prepared tokens through every uncertain submission. Choose the timeout above the host's bounded request deadline; the
default six seconds matches Board's five-second host profile.

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
