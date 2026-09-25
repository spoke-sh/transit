# Explicit growing client (M10 development)

`Client.submitGrowing(SignedRequest)` and `Client.queryGrowing(Query, KeyPair)`
use the [v3 contract](../../../../contracts/TRANSIT_V3.md). They call only
`/v3/command` and `/v3/query`; they never fall back to v2 or reinterpret a legacy
identity, view or cursor. Select a node configured for the
[development profile](../../../../apps/transit-node/docs/growing.md) and inspect
its capabilities before using an extension. `Session`, Station and foreign
bindings remain v2 until their growing interfaces are qualified.

## Caller responsibilities

The client owns bounded HTTP exchange; the application owns sequencing and retry.
Use the current `principal_sequence` to prepare the next signed mutation, retaining
its exact bytes until resolved. Shared handles for the same principal contend for
one sequence. No helper silently retries a transport call or reserves a sequence.
An error after submission can mean uncertain acceptance. Retry the same signed
request; a revoked principal cannot recover even its own old receipt.

Read process metadata and its next input, then capture an associated resource
view for that activation/input/revision. Read individual keys or bounded entry
pages. Propose up to four mutations plus input progress and outputs in one turn.
A view captures a resource version; it does not retain permission after grant,
ownership or lifetime changes. Keep every opened view's durable identity and
include the appropriate identities in the final proposal. Opening a view is a
mutation and consumes a principal sequence.

Current-resource reads specify the resource revision. Catalog continuations carry
the original authority position; changed cuts fail instead of mixing revisions.
Only a null cursor means completion. Filtered catalog pages may be empty with a
non-null cursor. Returned fields own their bytes; pages do not borrow HTTP buffers.
The library does not collect a whole resource or build a hidden resident queue.

## Response and transport guarantees

The shared transport preserves its monotonic deadline, guaranteed concurrency,
bounded body, redirect refusal and one in-flight call per client. Successful
mutation responses require a positive supported receipt position. Read validation
checks version/realm, variant, identities, resource/view basis, integer range,
ordered dense pages and advancing cursors. A malformed success is
`InvalidAuthorityResponse`; it is not proof that a preceding command was rejected.

Request diagnostics distinguish `read`, `receipt`, rejection and uncertainty on
the v3 routes. They omit keys, values, credentials and signed payloads. These
validations do not authenticate an HTTP endpoint; use the same private/TLS trust
boundary as the existing client.

The [Zig proof caller](../../../../tests/growing_client.zig) uses this public
package without a kernel or provider dependency. It demonstrates bounded handler
reads and exact retry across loss, not a complete Station runner or an idiomatic
SDK. M10 still owns framework paging, retained calls/results, capacity contracts,
lifecycle/provider integration and explicit migration before M11 can stabilize
the public language APIs.
