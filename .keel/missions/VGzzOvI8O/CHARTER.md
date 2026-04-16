# Ship First-Class Consumer Cursors For Independent Stream Progress - Charter

Archetype: Strategic

## Goals

| ID | Description | Verification |
|----|-------------|--------------|
| MG-01 | Make Transit tracks durable consumer cursors so multiple independent readers on the same stream can advance separately without the client persisting offsets out of band. A cursor is identified, stores a durable position on the authoritative engine, and exposes explicit advance/ack semantics that stay consistent across reconnect, restart, and failover. | board: VGzzXWgvv |

## Constraints

- Cursors are additive to the existing stream and branch model; branches keep their lineage-fork meaning and are not used as per-consumer progress carriers.
- Cursor position is durable on the server's authoritative engine, survives restart and cache loss, and does not depend on client-side state.
- Ack semantics are explicit: a cursor advance returns an acknowledgement with the same durability boundaries Transit already exposes for append.
- Cursors stay compatible with the one-writer-per-stream-head model; they do not introduce a second write authority or mutate history.
- Both the embedded engine and the hosted server surface the cursor primitive; the CLI and `transit-client` expose it with consistent semantics.

## Halting Rules

- DO NOT halt while any MG-* goal has unfinished board work
- HALT when epic `VGzzXWgvv` is complete, mission verification is recorded, and `keel doctor` reports no blocking board-health errors
- YIELD to human when satisfying the goal would require overloading branches with cursor semantics, weakening the one-writer invariant, or inventing a second authoritative storage model for cursor state
