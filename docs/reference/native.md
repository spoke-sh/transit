# Native signed protocol

Use `transit-client` or a [language SDK](sdks.md) for native calls. The shared
implementation owns canonical bytes, Ed25519 signatures, validation, sequencing
and exact recovery. The node exposes versioned JSON envelopes over HTTP; it is
not the Board or application serving API.

The [versioning policy](versioning.md) requires a single v1 definition for each
Transit-owned protocol before 1.0, with hard cutovers and removal of legacy
implementations.

| Contract | Owns |
| --- | --- |
| [Native HTTP service v2](../../contracts/SERVICE_V2.md) | Request/response envelopes, signature domains, HTTP framing and trust |
| [Transit protocol v2](../../contracts/TRANSIT_V2.md) | Legacy bounded commands, reads and ownership |
| [Growing protocol v3](../../contracts/TRANSIT_V3.md) | Explicit growing profile, paged catalogs/resources and signed operation rules |
| [State v1](../../contracts/STATE_V1.md) | Resource identity, associations, read views and commit constraints |
| [Installation/bootstrap v1](../../contracts/APPLICATION_INSTALLATION_V1.md) | Neutral declaration, local management operations, worker bootstrap and caller exports |
| [Client ABI](../../packages/zig/transit-client/docs/bindings.md) | Shared native handles, saved requests and cross-language ownership |

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

## Implementing another language client

The neutral boundary already has generated declarations and independent signing
fixtures. Bind the shared Zig client rather than duplicating protocol semantics.
Validate all values crossing the boundary at runtime, preserve full-width integer
encodings and distinguish an uncertain remote outcome from a local cancellation.
The [caller model](callers.md) and [SDK contracts](callers.md) define ownership
and scheduling. Generated declarations are not the language-native public API.
