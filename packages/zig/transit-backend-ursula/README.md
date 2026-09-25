# transit-backend-ursula

Ursula storage and transport adapter, exported as `transit_backend_ursula`.
[The module root](src/root.zig) exposes the backend integration used by
[transit-node](../../../apps/transit-node/README.md). It depends on
[transit-core](../transit-core/README.md) and pinned upstream `ursula-zig`, importing
its `ursula` module. Callers never receive this raw storage capability.

The [Ursula design](../../../docs/URSULA.md) owns the provider boundary;
the guides below own API mappings, pinned behavior, integration findings, and operations.

## Guides

- [Storage and recovery](docs/storage.md): disk startup, conditional append, checkpoint/trim, payload deletion, and ownership.
- [Immutable pages](docs/pages.md): M10 page staging, bounded cache, root persistence and current integration limits.
- [Upstream integration](docs/upstream.md): pinned server/client, cursor findings, unsupported APIs, and dependency updates.

## Security boundary

[The integration design](../../../docs/URSULA.md) defines logical ownership and
provider independence. The backend adds retry/recovery and retention policy around
upstream HTTP operations; handlers use the public Transit client.

Keep Ursula nodes private behind Transit's trusted protocol boundary. Authenticate
and authorize process admissions, commits, and connector records there; do not
expose raw stream APIs to workloads or browsers. In v0.5.1, node listeners lack
authentication/ACLs; the optional gateway can validate access tokens and enforce
bucket access. A bucket alone is not a security boundary, and gateway ownership
does not authorize a Transit turn or deletion. See the
[pinned upstream security contract](https://github.com/tonbo-io/ursula/blob/v0.5.1/docs/web/src/content/docs/pages/security.mdx)
and [Transit's authority model](../../../docs/SECURITY.md).

## Source and ownership

[Journal](src/root.zig) wraps bounded upstream HTTP operations and copies the
transport metadata it needs before releasing responses. [Store](src/Store.zig)
implements core's immutable-position/tail/conditional-append interface, a bounded
replay cache, checkpoint publication/loading, trim and immutable payload handling.
Protocol validation belongs to core; storage success alone is not a legal turn.

`Store.loadCheckpoint` returns an owned parsed pointer and its arena. Callers
must release it with `deinit()` after copying the required state. See the
[ownership guide](docs/storage.md#checkpoint-ownership). Package tests do not
prove the external server's durability or cursor semantics; use the real disk
proof when changing this boundary.

## Build and verification

Use the repository's pinned `nix develop` shell. From the repository root:

```sh
(cd packages/zig/transit-backend-ursula && zig build test)
just test::packages
```

See the [test guide](../../../tests/README.md) for integration evidence and limits.

Run `just test::storage` and `just test::service` after changing backend or client
behavior; package tests alone cannot prove persistence or server semantics.

## Instrumentation

`Journal.observer` optionally borrows a
[telemetry runtime](../telemetry/README.md); `parent_context` relates storage work
to its host operation. The adapter depends on
[transit-observability](../transit-observability/README.md) for event vocabulary.
Journal create/tail/read/conditional append and checkpoint/payload operations
emit bounded spans. Successful operations are debug; conflicts/errors are warnings.
No stream names, bodies, credentials or provider responses are logged. Cached
reads are not counted as network reads, and replay never creates fresh-turn metrics.
