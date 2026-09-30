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
