# C ABI v1

The shared library is the first M9 binding foundation. Build it with
`zig build client-abi` from the repository root. This installs
`zig-out/lib/libtransit_client.so` on Linux. The generated
[C header](../include/transit_client.h) and [machine-readable ABI](../abi-v1.json)
come from exported Zig signatures through `just contract::client-generate`.
`just contract::client-check` rejects drift and runs in `just check`.

This is currently a low-level synchronous client interface, not the completed
Station SDK or the qualification of every planned language. It reuses the same
Zig signing, parsing and HTTP implementation as native callers. There are no
language-specific authority routes.

M11 adds `growing_command` (6) and `growing_query` (7) without changing existing
ABI v1 calls, operation tags or frozen v2 bytes. The optional additive
`transit_client_supports_kind(kind)` export returns 1 for a supported operation
kind and 0 otherwise, without allocation or I/O. It describes the local library,
not the configured authority. A caller requiring growing support must reject a
library without that export or those kinds; it must not fall back to v2. Existing
clients remain compatible with the extended library. New generated bindings
require the matching native library exports.

## Calls and ownership

1. `transit_client_create(version, url, url_length, timeout_ms, &client)` creates
   an explicit client. URLs are bounded to 2048 bytes and deadlines to 1–60000 ms.
   It discovers no credentials and performs no request during construction.
2. `transit_operation_prepare(kind, seed32, json, json_length, &operation)` parses
   one public request/query, validates it, and freezes its signature and owned
   values. The seed is borrowed for this call; the native temporary key is erased.
   Caller-owned seed memory remains the caller's responsibility.
3. `transit_client_call(client, operation, &buffer)` makes one bounded exchange.
   The buffer contains canonical JSON for the typed response, or an error object.
   It never retries or advances a mutation sequence automatically.
4. `transit_buffer_data/size` borrow bytes until `transit_buffer_destroy`.
   `transit_operation_destroy` and `transit_client_destroy` release their objects.
   Destroy accepts null; other pointers must designate valid objects/buffers.

Prepare accepts unsigned `Request` for command/view, or the corresponding public
State, Inspection or Delivery query. JSON payload encoding remains the public
protocol's lowercase hex. The header's `TRANSIT_KIND_*` values select the route.
Use explicit lengths: buffers are not NUL-terminated. Native buffers may be freed
on another thread after the operation completes; handles must never be freed or
used concurrently with their destruction. There are no callbacks into the host.

The growing kinds accept the public `Growth.Request` and `Growth.Query` from
the [v3 contract](../../../../contracts/TRANSIT_V3.md). Zig validates and signs
them under the v3 domains and sends only `/v3/command` or `/v3/query`. IDs retain
the full public range. Query results use the shared growing response validation,
including realm, identity, revision and page coverage. Growing mutations preserve
`uncertain` after a lost or malformed accepted response or response-allocation
failure. The separate [growing Station ABI](../../transit-station/docs/bindings.md#explicit-growing-turns)
adds gated/scoped turns; raw v3 operations alone do not advertise a handler runner.

One operation may execute per client at a time; another call returns `busy`.
Sharing a principal across clients still requires application-level sequencing.
The host schedules blocking calls on bounded runtime workers, joins them before
destroying the client, and does not block its event loop/BEAM scheduler. Dropping
a host await does not cancel a native call, commit or remote operation. Deadline
handling joins native I/O before returning. A future asynchronous adapter must
preserve these ownership and uncertainty rules.

Each native handle retains its bounded two-worker I/O pool. Sequential calls can
observe completed workers before the scheduler releases their slots; acquisition
waits within the same request deadline instead of expanding the pool or retrying
the transport. Scheduling exhaustion returns `AuthorityTimeout`, preserving the
ABI's conservative uncertainty for mutations. Genuine transport errors still
return immediately with no automatic retry.

## Recovery and errors

`transit_operation_export` produces a versioned, canonical envelope containing
the operation kind, signed request/query and signature. It contains no private
seed, but can contain application data and must be protected. A host can persist
those exact bytes and reconstruct the operation with `transit_operation_import`
after losing every native handle. Import rejects a different version, malformed
shape or noncanonical representation. It grants no permission and does not
authenticate an imported signature locally; the authority checks both signature
and current grants during execution.

`transit_operation_metadata` returns native-classified kind/profile, realm,
principal, decimal sequence, command tag and send destination. Its identity is
the SHA-256 of the exact exported envelope. Public send helpers must validate
the recovered kind, profile and command before exposing a pending send; they
need not parse signed retry bytes in the host language. Metadata contains no
payload or signature and does not authenticate the operation or prove admission.
Like other buffers, its bytes belong to the caller until explicitly destroyed.

The standalone [client port](../../../../apps/transit-client-host/README.md)
exposes the same operations without a Station dependency. Its generated schemas
and capability response include the native 8 MiB stack requirement and bounded
line budget. Station's existing port delegates raw requests to the same owner;
its original hello stays compatible.

Persist retry material before sending if the host requires recovery of uncertain
submissions. Such material is a pending request, never authoritative evidence of
acceptance. The ABI supplies no hidden filesystem store or background queue.
Station's durable waiting and activation recovery remain separate work.

`ok` returns a receipt/read; a receipt does not establish that this attempt caused
a new transition. `rejected`, `denied` and `conflict` retain the authority's exact
error code in the response buffer. `uncertain` means a mutation may have committed,
including receipt loss or a local allocation failure after a successful response.
Retry the same frozen operation; do not invent a new sequence. Read failures
return `unavailable` or `invalid_response`. Preflight/ownership statuses include
`invalid_argument`, `out_of_memory`, `busy` and `incompatible_version`.

Unit checks enumerate every allocation in the receipt-to-ABI response path after
a deterministic transport reports acceptance. They require `uncertain`, exactly
one submission and released buffers on failure. The package's standalone `test`
target and root unit suite run those ABI tests; the real C/HTTP proof separately
qualifies host loss, exact retries and current revocation. The allocator seam is
internal and does not change the C interface or production allocator.

JSON is parsed and canonicalized in Zig. Host adapters must retain integer
precision and distinguish payload integers from the protocol's current 53-bit
counter ceiling. The ABI does not silently expand that public limit. Returning
JSON bytes alone is not a promise that a host's default JSON parser is suitable
for every future protocol version.

## Evidence

`just test::client-abi` compiles a C program against the generated header and
loads the same library from Python against disk-backed Ursula and the real
authority. It compares signatures with the Zig CLI, drops a successful receipt,
retries from a fresh host without the signing seed, checks identical transmitted
bytes, and exercises public view/state reads and malformed-input rejection.
It also races independent handles sharing one principal: different bodies at
one sequence produce one admission and one `ConflictingRetry` rejection;
identical bodies return the same receipt. The application still owns shared
principal sequencing. These checks use the
[shared SDK scenarios](../../../../tests/verification/sdk.json), including
distinct admission, processing, reply delivery and reply consumption boundaries.
The same task exercises the growing kinds against a one-page-cache node and
disk Ursula: principal 65,536, opaque retry from a fresh process after node/store
restart, byte-identical retransmission, rejected malformed reads/receipts and
current revocation before historical retry. The shared
[operation fixtures](../../../../tests/verification/sdk-operations-v1.json)
include IDs at the public maximum and reject legacy versions and overflow.
Allocation enumeration covers both legacy and growing mutations.
The same task also runs the standalone client port against disk-backed Ursula,
checking native metadata identities, canonical import, profile classification,
absence of Station requests and fresh-process retry after removing the seed file.
M9's separate Station handler/Table matrix remains available; these raw proofs
do not qualify the proposed M11 public SDKs.
