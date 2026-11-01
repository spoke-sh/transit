# Go SDK

The `client` package submits application inputs, reads current authority
capabilities and recovers exact signed operations. Process references identify
the destination and realm; current grants determine access. An admission receipt
establishes acceptance of an input, independently of its processing or result.
The shared Zig implementation owns canonical encoding, signatures, response
validation and recovery. Go owns typed values, cancellation and native lifetime.

The module is `github.com/spoke-sh/transit/sdks/go`. Its raw entry point is
`github.com/spoke-sh/transit/sdks/go/client`. The additive
[`serving` package](serving/README.md) uses a bounded installed native process for
Serving recovery and subject proofs. The C ABI instructions below apply to `client`.
Catalog, query and Station handler
packages are not exposed. The raw client has no Station library dependency.

## Installation

Build from a matching source revision using the
[binding tasks](../../bindings/README.md#build-and-verification). Use the pinned
Go 1.26.7 toolchain, Linux amd64 and cgo with a C compiler. The package has no
external Go module dependencies. The native libraries retain their build's Nix
runtime closure; portable native artifacts and public module releases are not
provided by these tasks.

The source build produces two local installation archives:

- `transit-go-0.0.1.tar.gz`: the Go module and generated ABI resources.
- `transit-go-native-0.0.1.tar.gz`: `lib/libtransit_client.so`.

Extract them into separate SDK and native installation directories. In a consumer
module, require `github.com/spoke-sh/transit/sdks/go v0.0.1` and use a Go `replace`
directive pointing to the extracted SDK module. Build with `CGO_ENABLED=1`.
Set `Config.NativeDirectory` to the installed native `lib` directory. The runtime
needs that directory and the native Nix closure, independently of the Go source
and build cache. It does not need `LD_LIBRARY_PATH` or a Zig compiler at runtime.

Open checks every required native symbol, the complete current ABI definition
and supported operation kinds before creating a handle. Missing or mismatched
libraries reject; no alternate library or protocol is selected. Other platforms
and builds with cgo disabled retain the value types but reject native open.
Package versions do not establish protocol compatibility. Follow the
[current-v1 policy](../../docs/handbook/reference/versioning.md).

## Prepare, save and dispatch

```go
package application

import (
    "context"
    "github.com/spoke-sh/transit/sdks/go/client"
)

func Send(ctx context.Context, config client.Config, credential client.Credential,
    peer client.ProcessRef, sequence client.Sequence, value []byte,
    persist func([]byte) error) (client.AdmissionReceipt, error) {
    caller, err := client.Open(config)
    if err != nil { return client.AdmissionReceipt{}, err }
    defer caller.Close()

    pending, err := caller.PrepareSend(ctx, peer, value, credential, sequence)
    if err != nil { return client.AdmissionReceipt{}, err }
    if err := persist(pending.Export()); err != nil {
        return client.AdmissionReceipt{}, err
    }
    return caller.Dispatch(ctx, pending)
}
```

Supply credentials explicitly with `NewCredential(realm, principal, seedFile)`.
The seed file contains 32 bytes encoded as hexadecimal. Import and construction
read no credentials and start no network work. The seed is read only when signing
a prepared send or capability query. Temporary key buffers are cleared after use.

`PrepareSend` creates private owned work without submission. `Export` returns a
copy of the exact recovery envelope. Persist it durably before dispatch if the
application needs recovery after process loss. The envelope contains application
data and a signature, but no private seed. Its presence does not prove acceptance.
The [complete example](../../examples/go-client/README.md) saves and syncs that
file before a separate dispatch invocation.

`RecoverSend` imports the original envelope and validates its native operation
kind; `RecoverMutation` accepts other native mutations. Both work without the
original signing seed. `Dispatch` and `DispatchMutation` attempt the same frozen
operation once. They never assign a new sequence, alter the payload, or retry
automatically. The authority checks the original signature and current grants.

Native counters are bounded by `MaxCounter` (`2^53 - 1`). Realm, process and
sequence values are positive; principal zero is valid. A send contains at most
`MaxValueBytes` (256 bytes). Constructors and operations reject invalid values.
The current profile and credentials must be selected explicitly; locally loaded
ABI support does not establish server capability or authorization.

## Cancellation and ownership

Methods accept `context.Context`. An already cancelled context prevents admission.
Cancellation after admission stops waiting while the client continues to own
native work. For dispatch, the returned error matches both `ErrUnknownOutcome`
and the context cause. Inspect `*DispatchError` with `errors.As` and retain its
copied `Recovery()` bytes. Cancellation does not undo an accepted input.

One operation may be active per client. Concurrent calls return `ErrBusy`,
including after an await is cancelled while native I/O remains active. Separate
clients sharing a principal need an application-owned sequence allocator.
Native I/O uses the configured timeout, 1 millisecond through 60 seconds;
zero selects 30 seconds. Context cancellation does not shorten that native timeout.

`Close` stops admission, joins active work, destroys native ownership and releases
the client's worker. It is idempotent and safe to call concurrently. Use
`defer caller.Close()`; garbage collection does not release an open client.
The last successfully observed admission and mutation receipts remain available
through `LastAdmission` and `LastMutation`, including after cancellation or close.
Each receipt carries its original operation `Identity`; compare it with the
pending operation before attributing the receipt to a particular attempt.
A failed later attempt does not replace previously observed evidence. Go values
and exported bytes remain valid after closing the client.

Every native call runs on one owned POSIX thread with at least the ABI's 8 MiB
stack. Inputs crossing cgo use C-owned memory; returned buffers are copied before
native release. Loaded native code stays mapped until process exit while detached
native I/O threads finish returning. Repeated opens reuse the same mapping, with
at most sixteen distinct loaded images. Keep installed library files immutable:
replacement or removal rejects a subsequent open of that configured path.

## Errors and diagnostics

Use `errors.Is` for categories such as `ErrAccessDenied`, `ErrBusy`, `ErrClosed`,
`ErrIncompatibleNative`, `ErrReadFailed` and `ErrUnknownOutcome`. `errors.As` exposes
`*Error` with native status, bounded authority code and optional owned diagnostic.
`Diagnostic()` returns a copy. Malformed optional detail is discarded and marks
`DiagnosticInvalid`; it never changes the primary outcome. All formatting verbs
exclude diagnostic content, credential paths and saved request bytes.

Read failure establishes no write outcome. A denied retry does not undo an earlier
acceptance. Follow [caller semantics](../../docs/handbook/reference/callers.md)
for current authorization, exact recovery and uncertainty.

## Development and verification

The [Go binding tasks](../../bindings/README.md#go-source-builds) cover formatting,
vetting, race detection, strict cgo pointer checks and generated-resource drift.
The installed-consumer task builds the installation archives and exercises an
external consumer and the real example against a disk-backed authority. The
[proof ledger](../../docs/history/qualification/sdk.md#go-raw-client) records executed coverage.
