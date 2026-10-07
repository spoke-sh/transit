# Rust public SDK examples

Strictly typed counter/requester and Table/query handlers use the
[shared version-one application codecs](../README.md). Full-width values use
`u64` and `i64`; correlations are saved in associated state before later reply
handling. The library exports the handlers, schemas, keys and role-specific codecs.

The Table service follows the shared [durable FIFO contract](../TABLES.md).
Creation and insert/update/delete use original admitted input identities across
bounded self continuations. It records terminal outcomes before removing work,
including rejected mutations. Queries receive an authenticated NotReady reply
while work remains; a later explicit Start reads four columns with UTF8 and LIST
defaults. Queue records use strict neutral codecs and keep the four-write budget.

The installed CLI is `transit-rust-counter CONFIG service --commits 1`
(or `requester`). CONFIG supplies `url`, explicit `profile: "native_v1"`, realm,
PID, principal, generation, seed file and peer PID. Provision ownership, grants
and the `data` association first. The example requires fresh ownership after
host loss; applications needing exact crash recovery provide persistence hooks.

Build crates with `nix develop .#bindings --command just bindings::rust-build`,
then add `transit-sdk-examples-rust = "=0.2.0"` and patch the unpublished artifacts
as described in the [SDK guide](../../../packages/rust/transit-station-sdk/docs/USAGE.md).
The library import is `transit_sdk_examples`. Cargo builds the counter CLI from
this package; the Table/query handlers are library examples used by the live proof.
`QueryRequester` accepts a callback consuming each owned original `IpcSegment`.
Callback effects need their own replay/idempotency policy.

`nix develop .#bindings --command just bindings::rust-sdk-test` compiles installed
examples outside the checkout, invokes both CLI roles across worker replacement,
and verifies shared codec fixtures, retained Tables and complete query IPC. The
test consumer decodes optional Arrow batches after runner close and independently
checks the same segments with PyArrow. See the [proof guide](../../../tests/README.md).
