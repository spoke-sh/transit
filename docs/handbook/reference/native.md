# Native signed protocol

Use `transit-client` or a [language SDK](sdks.md) for native calls. The shared
implementation owns canonical bytes, Ed25519 signatures, validation, sequencing
and exact recovery. The node exposes versioned JSON envelopes over HTTP; it is
not the Board or application serving API.

The [versioning policy](versioning.md) requires a single v1 definition for each
Transit-owned protocol before 1.0, with hard cutovers and removal of legacy
implementations.

Native signatures bind a contract `definition` identifier as well as v1. Stored
authority heads, saved operations and SDK/native-library checks use the same
identifier to reject incompatible builds. The [compatibility policy](versioning.md#current-native-definition)
explains its ownership and replacement rule.

| Contract | Owns |
| --- | --- |
| [Native HTTP service v1](../../../contracts/SERVICE_V1.md) | Request/response envelopes, signature domains, HTTP framing and trust |
| [Transit protocol v1](../../../contracts/TRANSIT_V1.md) | Paged catalogs and resources, commands, reads, ownership and recovery |
| [State v1](../../../contracts/STATE_V1.md) | Resource identity, associations, read views and commit constraints |
| [Installation/bootstrap v1](../../../contracts/APPLICATION_INSTALLATION_V1.md) | Neutral declaration, local management operations, worker bootstrap and caller exports |
| [Client ABI](../../../packages/zig/transit-client/docs/bindings.md) | Shared native handles, saved requests and cross-language ownership |

## A native mutation

Prepare an operation under the caller's explicit realm, principal and request
sequence. Retain its exact canonical signed bytes before dispatch if it must
survive caller loss. A receipt identifies native admission; the owning worker
still needs to commit any resulting domain work. If the response is lost, retry
those same bytes. Do not mint another sequence to guess whether it happened.

Current grants remain independent from PID ownership, provider credentials,
names and resource associations. Reads and replay also require current rights.
A worker replacement changes its ownership generation; restoring an old snapshot
or credential file cannot recreate authority.

Standalone immutable payloads use accepted declarations plus the local owner's
`POST /v1/payload` byte service. Publication and verification require the recorded
publisher's current `publish` privilege; reads require current `inspect` rights
for the process. After uncertain creation, verify the original attempt before
publishing native readiness. Never create the bytes again to guess their outcome.
See [payload envelopes and lifecycle](../../../contracts/SERVICE_V1.md#standalone-payload-bytes).

## Implementing another language client

The neutral boundary already has generated declarations and independent signing
fixtures. Bind the shared Zig client rather than duplicating protocol semantics.
Validate all values crossing the boundary at runtime, preserve full-width integer
encodings and distinguish an uncertain remote outcome from a local cancellation.
The [caller model](callers.md) and [SDK contracts](callers.md) define ownership
and scheduling. Generated declarations are not the language-native public API.
