# Transit query browser primitives

Private M23 package for Board and generated applications. Request, response and
draft-budget declarations derive directly from `transit-query.Workspace`, with
CSP-compatible generated validators. Board's OpenAPI reflection is checked against
the same owning definitions. This package does not compile SQL or confer authority.

`httpTransport(path, timeoutMs)` calls one configured same-origin host. It bounds
requests to 48 KiB and decoded replies to 1 MiB before parsing, validates response
structure and semantic cell/budget bounds, and retries only pre-dispatch 429s with
the identical request. Keep frozen prepared tokens through every uncertain
submission. Choose the timeout above the host's bounded request deadline; the
default six seconds matches Board's five-second host profile.

`verifiedPage` performs a bounded full-coverage pass over one immutable result,
then rereads the selected visible page under current authority. It holds one
segment at a time and rejects mixed manifests, incorrect coverage and cancellation.
The supplied read adapter owns transport and must validate its responses.
`unifiedCellText` preserves full-width integers and distinguishes missing, null,
type errors and concurrent alternatives. A source/result contract is evidence,
not an access grant.

Board now consumes the package for v2 transport, semantic values and full-result
verification. Focused types/transport/coverage checks and the actual native Table
API/browser regression pass. Finite draft scheduling will compose these owners; it is not yet
implemented by this package.
