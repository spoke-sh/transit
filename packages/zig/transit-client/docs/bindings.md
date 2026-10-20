# C ABI v1

Build `zig build client-abi` to install `zig-out/lib/libtransit_client.so` on
Linux. The generated [C header](../include/transit_client.h) and
[machine-readable ABI](../abi-v1.json) come from shared Zig signatures through
`just contract::client-generate`; `just contract::client-check` detects drift.
The implementation owns canonical bytes, signatures, parsing, HTTP and exact retry.

Before creating handles, call `transit_client_abi_definition_matches` with the
complete generated `TRANSIT_CLIENT_ABI_DEFINITION` identifier and its length.
A zero result or missing export rejects the library. ABI version 1 alone does
not establish compatibility between builds. The supported operation kinds are
`growing_command` (6) and `growing_query` (7); `transit_client_supports_kind`
reports local support without I/O. No other operation kinds are supported.

The additive `transit_json_extract` helper lets C/C++ SDK implementation layers
read native metadata without depending on Station or another JSON parser. It
accepts at most the public body bound and a 128-byte slash-separated object/array
path. Format 0 returns owned JSON; format 1 returns owned string bytes, including
embedded NULs. Length remains authoritative. Full-width numeric values remain
exact. The helper does not classify, authenticate or validate an operation;
canonical recovery still uses `transit_operation_import` and native metadata.
Station's existing JSON helper delegates to the same implementation. Unit checks
cover invalid selectors/formats and allocation-failure cleanup.

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

Prepare accepts the current native `Growth.Request` or `Growth.Query` from the
[native v1 contract](../../../../contracts/TRANSIT_V1.md). The shared library
fills canonical defaults and signs the contract definition, realm and operation.
It uses `/v1/command` or `/v1/query` and validates response identity, revision and
page coverage. Values use lowercase hex; IDs retain the public 53-bit range.
The [Station ABI](../../transit-station-bindings/docs/bindings.md#explicit-growing-turns)
adds private turns, handler dispatch gates and framework state above this boundary.

Use explicit lengths: buffers are not NUL terminated. Native buffers may be freed
on another thread after completion; handles must not be used concurrently with
destruction. No callback enters the host through this ABI.

One operation may execute per client at a time; another call returns `busy`.
Sharing a principal across clients still requires application-level sequencing.
The host supplies at least the generated `minimum_stack_bytes` (8 MiB) for each
calling thread. It schedules blocking calls on bounded runtime workers, joins them before
destroying the client, and does not block its event loop/BEAM scheduler. Dropping
a host await does not cancel a native call, commit or remote operation. Deadline
handling joins native I/O before returning. A future asynchronous adapter must
preserve these ownership and uncertainty rules.

Keep a loaded native library mapped until process exit. The pinned I/O pool
drains work before its detached threads finish returning through native code;
destroying all handles does not make `dlclose` safe. Host loaders must bound and
reuse retained images separately from handle ownership. Installed C/C++, Rust
and .NET loaders enforce a sixteen-image limit; native handles and buffers still
have their ordinary explicit release lifecycle.

Each native handle retains its bounded two-worker I/O pool. Sequential calls can
observe completed workers before the scheduler releases their slots; acquisition
waits within the same request deadline instead of expanding the pool or retrying
the transport. Scheduling exhaustion returns `AuthorityTimeout`, preserving the
ABI's conservative uncertainty for mutations. Genuine transport errors still
return immediately with no automatic retry.

## Recovery and errors

`transit_operation_export` produces a versioned, canonical envelope containing
the contract definition, operation kind, signed request/query, signature and any
owned block body. A command without a body retains `blocks: null` in this saved
representation; its ordinary signed HTTP request omits the optional body field.
The envelope contains no private
seed, but can contain application data and must be protected. A host can persist
those exact bytes and reconstruct the operation with `transit_operation_import`
after losing every native handle. Import rejects a missing or different definition, unsupported version, malformed
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

## Verification

`just test::client-abi` exercises the generated C header, independent Python and
standalone port against the node and disk-backed Ursula. Its schedules cover
canonical signatures, saved-request recovery without a seed, lost receipts,
current revocation and competing handles sharing one principal. The
[proof ledger](../../../../tests/README.md) distinguishes executed outcomes from
planned coverage. The [shared SDK scenarios](../../../../tests/verification/sdk.json)
cover the separate admission, turn, reply delivery and consumption boundaries.

`transit_diagnostic_validate(bytes, length)` validates a shared diagnostic without
an authority connection. It returns 1 only for a current-definition envelope
within 32 KiB that satisfies its field, evidence and recovery-action rules;
otherwise it returns 0. The Station library exposes the same implementation as
`station_diagnostic_validate`. Validation neither authenticates a diagnostic nor
establishes a domain outcome. It makes no network requests.
