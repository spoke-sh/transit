# Ursula integration boundary

Engineering background and historical design. Use [Storage and recovery boundary](../reference/storage.md)
for the current public explanation shared by users, developers and agents.
Consult this record for rationale and proposals; it does not extend a qualified profile.

Ursula is the storage provider behind the public Transit boundary. Application
code uses the client, not raw Ursula streams. Start with the
[local server](../../apps/transit-cli/docs/server.md) for a configured installation
or the [backend guide](../../packages/zig/transit-backend-ursula/README.md) for implementation.

Status: Ursula is the selected durable storage and transport implementation.
[transit-backend-ursula](../../packages/zig/transit-backend-ursula/README.md) integrates
the pinned server through upstream `ursula-zig`. Its [component guides](../../packages/zig/transit-backend-ursula/README.md#guides) own
API mappings, persistence setup, dependency pins, cursor findings, and recovery limits.

## Why an adapter

Transit defines legal execution, logical stream identity, retained boundaries,
and application lifetime guarantees. Ursula supplies persistence and transport.
Keeping those responsibilities separate allows another backend to implement the
same guarantees without making Ursula cursors, TTLs, or physical names part of
the programming model. New backends need their own conformance evidence; their
existence is not implied by this boundary.

The current mapping serializes policy and process operations in one realm
journal through conditional append. This avoids requiring cross-stream
transactions for authority. It is a bounded M1 profile, not a general scaling
architecture. Checkpoints plus retained history preserve the recovery basis;
provider snapshots alone cannot authorize execution.

## Trust and lifecycle requirements

Only trusted protocol services receive raw Ursula access. Application callers
use Transit; bucket names or provider credentials cannot replace current realm,
action, and resource authorization. Keep storage listeners private. See
[security](SECURITY.md) for the authority boundary.

Native provider trimming, TTL, and deletion are mechanisms, not application
permission. The adapter must reject unsupported guarantees and preserve required
control evidence outside reclaimed data. An unavailable or missing stream is
not proof of process expiry or authorization to recreate its identity. See
[retention](RETENTION.md) and [streams](STREAMS.md).

Use disk-backed Ursula for persistence/recovery work. The pinned in-memory preset
is suitable only for disposable experiments. Container deployments use the
upstream image; the development shell uses the overlay binaries. Follow the
[backend startup instructions](../../packages/zig/transit-backend-ursula/docs/storage.md#conditional-authority-and-startup)
and [reference runbook](../../deploy/reference/README.md).

## Evidence

The [test guide](../../tests/README.md) records single-node disk interruption,
conditional authority, bounded reads, checkpoint/trim, and deletion proofs.
Multi-node routing, host/disk loss, backups, and broader provider durability
claims require separate qualification. The [upstream integration guide](../../packages/zig/transit-backend-ursula/docs/upstream.md) records the corrected
client cursor API and the separately reported upstream server behavior; those
findings must inform future dependency upgrades.
