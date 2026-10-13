# Clients, SDKs and Station

This account explains how language-native programming models preserve one
execution protocol. It combines caller, SDK and Station reasoning. Installation
and usage remain in the [SDK index](../reference/sdks.md),
[caller reference](../reference/callers.md) and [Station reference](../reference/station.md).

## Ownership model

| Owner | Responsibility |
| --- | --- |
| Shared Zig client | Canonical operations, signatures, validation and exact recovery |
| Station | Private turns, durable calls, names, supervision and state helpers |
| Neutral ABI/native port | Explicit value, handle, operation and lifetime boundary |
| Language SDK | Native types/codecs, handler dispatch, scheduling and packaging |
| Application | Domain validation, durable workflow state and external-effect policy |

Generated wire declarations expose the shared boundary; they are not themselves
an idiomatic public API. Host tasks, futures and handler fields exist only for
their host lifetime. A durable operation needs identities and recovery evidence
that survive that lifetime.

## Recovery and cancellation

A handler receives the next input and computes a private proposal. Abandoning or
throwing from that handler must not leak its draft into a later turn. Only
accepted commit makes the proposal durable. Borrowed views and buffers expire
at their declared scope; retaining data requires copying or the owning API's
explicit retention operation.

Suppose an asynchronous caller is cancelled while native I/O is active. Cancelling
the host await does not determine whether the protocol operation was accepted.
The binding must finish or join native ownership before releasing referenced
memory, and preserve uncertainty for reconciliation. Conflating task cancellation
with durable cancellation would permit both use-after-free and false rollback
claims, depending on which boundary was ignored.

The SDK profile bounds overlap per handle/runner. Independent handles sharing a
principal still need coordinated principal sequences. Separate language schedulers
cannot each invent a valid next sequence for the same authority identity.

## Native code lifetime after owned cleanup

For Linux x86_64 native SDKs, when does closing an owner permit unloading its
library? The relevant actors are the SDK owner, the pinned Zig I/O pool and the
platform loader. Handle destruction waits for I/O completion. That completion
notification can precede a detached worker's final return through native code.
Let `C` denote the notification, `U` the loader unmapping the image, and `R` the
worker's return. Waiting for `C` permits the unsafe order `C < U < R`; it does
not establish `R < U`. Joining the SDK's host thread does not join a different
detached I/O thread.

The [Rust loader](../../packages/rust/transit-client/src/library.rs) and
[.NET loader](../../packages/dotnet/transit-client/Internal/NativePackage.cs)
therefore retain and reuse bounded code mappings until process exit. Handles,
buffers and accepted-work evidence keep their explicit cleanup/recovery rules.
Removing a private extraction file leaves its existing mapping valid. Each
loader admits at most sixteen code images; the package guides define the exact
scope and override identity checks. This is a bound on resident executable
images, independent of durable collection size or caller permissions.

The alternative of unloading on a delay cannot prove that every detached return
has completed. A true thread-exit fence in the native runtime could permit earlier
unloading, but the current ABI supplies no such fence. Retention spends resident
code space to remove the unsafe ordering without changing the compiler or
protocol. It does not retain client handles or authorize work after close.

The [Rust investigation](../../tests/README.md#rust-native-lifetime-investigation--2026-09-30)
contains a native stack returning through an unmapped image. The integrated
[query qualification](../../tests/README.md#integrated-vector-execution) records
the .NET crash observation and deterministic mapping regression separately.
`nix develop .#bindings --command just bindings::dotnet-sdk-test` and the
corresponding `bindings::rust-sdk-test` run installed consumers against the real
authority. Their Linux mapping assertions require retained, nonduplicated images
after I/O/close and removed extraction files. Such assertions detect unsafe
unloading even when a particular run avoids a crash; they do not prove every
host scheduler, loader context or platform safe.

## Framework mechanisms

Station calls record correlation and reply destinations durably. A registry
resolves names to PIDs; later rebinding cannot retarget accepted calls. Conditional
cleanup must not delete a newer binding. Supervision records logical child intent,
while a provider or local manager handles physical execution. Neither can revive
a retired PID or supply a missing grant.

These mechanisms retain the [execution model](execution-model.md) rather than
creating a second commit protocol. A Table helper, Document object or convenient
language transaction does not extend the [resource boundary](state-model.md).

## Alternatives and evidence

Independent per-language protocol implementations could integrate directly with
each runtime, but every codec, retry rule and lifecycle change would need a
separate correspondence argument. Sharing the Zig implementation centralizes
those semantics at the cost of a native ownership and packaging boundary that
must itself be tested.

The [client binding owner](../../packages/zig/transit-client/docs/bindings.md) and
[Station binding owner](../../packages/zig/transit-station-bindings/README.md)
define that boundary. [Station and binding evidence](../../tests/README.md#m9-station-bindings-and-tables)
and the [SDK verification inventory](../../tests/verification/sdk.json) identify
independent consumers, host scenarios and reproduction tasks. Shared implementation
does not prove every host scheduler or platform correct.

For earlier design choices, consult the [client](../history/CLIENT.md),
[SDK](../history/SDK.md), [Station](../history/STATION.md) and language-specific
[Python](../history/sdk/PYTHON.md), [TypeScript](../history/sdk/TYPESCRIPT.md) and
[Rust](../history/sdk/RUST.md) records. Their historical API sketches do not
override current package APIs.
