# Direct Document Contract v1

This contract defines the shared wire, storage, and catalog vocabulary for
direct `DOCUMENT` resources in [`transit-protocol`](../packages/zig/transit-protocol/README.md)
(`DocumentDeclaration`, `DocumentOperation`, and `DocumentRead`) and
[`transit-storage`](../packages/zig/transit-storage/README.md). Every structure
requires the current `Growth.current_definition` value and rejects missing or
foreign definition markers before execution.

The reflected [data lifecycle schema](data-lifecycle-v1.schema.json) owns exact
field shapes; the [shared fixture](../packages/zig/transit-protocol/src/fixtures/document-v1.json)
exercises full-width 64-bit and 128-bit identities, causal CRDT and versioned
lineage, finite merge-window checkpoints, and pinned read cursors. The installed
[Station Document v1 service contract](STATION_DOCUMENT_V1.md) remains active
until the common transaction decision owner composes Station turn outputs with
direct partition commits.

## Declarations, profiles, and routing

`DocumentDeclaration.Declaration` binds the current definition, an immutable
`DataLifecycle.Definition` (`interpretation`) on branch one, an exact `schema`
content attribution (`DataLifecycle.Content`), `Configuration`, and `Limits`.

`Configuration` binds `Partitioning` (`count`, optional `key_column`,
`hash == .sha256_64`), a merge `Profile` (`causal_crdt` or `versioned`),
`Shredding`, and `Retention`:

- `causal_crdt`: conflict-free causal document trees and collaborative text
  using observed-remove multivalue registers, RGA sequences, and `SpanText`
  spans anchored by replica lineage.
- `versioned`: deterministic three-way structural tree merges (`VersionedMerge`)
  that preserve conflicting leaf or node-kind assignments as explicit `conflict`
  cells until resolved by a successor revision.

`Shredding` configures automatic subcolumn shredding in `.tseg` storage segments:

- `frequent_path_threshold` (`1..=4096`): minimum occurrences within a segment
  before an undeclared path is promoted to a typed subcolumn.
- `max_shredded_columns` (`1..=256`): maximum shredded path subcolumns per
  `.tseg` segment before remaining paths stay in the succinct balanced-parentheses
  (`SuccinctTree`) residual stream.
- `default_collation` (`utf8_binary`, `ascii_ci`, `ebcdic_cp037`): default text
  collation ($\kappa$) governing shredded string zone maps and key comparisons.

`Retention` has nullable positive `max_age_ms` and `merge_window_revisions`
bounds; `null` retains unlimited history. Zero values reject with
`InvalidDocumentRetention`. `Limits` requires non-zero budgets for
`change_bytes`, `operations_per_change`, `path_depth`, `read_steps`,
`read_bytes`, and `unresolved_conflicts`.

`Declaration.requireSuccessor` verifies that a definition successor retains the
same `Object`, advances `revision` by one, and preserves `partitioning`,
`configuration.profile`, and `configuration.shredding.default_collation`.
`Partitioning.select` hashes canonical collation-aware key bytes with SHA-256,
interprets the first eight digest bytes as a big-endian `u64`, and takes modulo
`count`.

## Target identity, lineage, and mutation receipts

`DocumentOperation.Partition` binds the current definition, an `interpretation`
on branch one, and a zero-based `partition` ordinal. `Target` combines
`Partition` with a non-zero 16-byte logical `document` identity.

`Lineage` records the causal or versioned ancestry of a document mutation:

- `profile` (`causal_crdt` or `versioned`) and non-zero `merge_epoch`.
- `base_revision` (`0` only for initial document creation; positive for updates)
  and optional `parent_revision` (permitted only for `versioned` three-way
  merges when `base_revision > 0`, `parent_revision > 0`, and
  `parent_revision != base_revision`).
- `replica` (`Replica`): required for `causal_crdt` and optional for
  `versioned`; binds non-zero 16-byte `id`, `epoch == merge_epoch`, `sequence`,
  and `preceding_sequence` (`preceding_sequence + 1 == sequence`).
- `raw_span` (`RawSpan`): optional `(part_id, byte_start, byte_end)` provenance
  anchor into an immutable raw envelope attachment.

`Mutation` binds `target`, `operation` (`DataLifecycle.Operation`), `lineage`, a
non-zero `operations` count, and a `payload` (`DataLifecycle.Content`).
`MutationReceipt` binds the accepted `mutation`, a strictly advancing
`accepted_revision`, resulting `state` (`DataLifecycle.Content`),
`unresolved_conflicts` count, and the durable `accepted` (`DataLifecycle.Position`).
`requireMutation` rejects conflicting retries with `DocumentMutationConflict`.

`ReplicaState` tracks per-replica deduplication and epoch fencing for a specific
`(target, principal, replica.id)`:

- `check` returns `.retry` when a candidate's sequence is within
  `(discarded_through, replica.sequence]`; `.apply` when
  `sequence == replica.sequence + 1` in the same epoch; and `.advance_epoch`
  when `epoch > replica.epoch` starting at `sequence == 1`.
- Older sequences at or below `discarded_through` reject with
  `DocumentReplicaReceiptExpired`; sequence gaps reject with
  `DocumentReplicaSequenceGap`; lower epochs reject with
  `DocumentReplicaFenced`; and mismatched principals or replica IDs reject with
  `DocumentReplicaConflict`.

## Cuts, finite merge-window checkpoints, and retained reads

`Cut` fixes `target`, `merge_epoch`, `retained_from`, `accepted_revision`
(`1 <= retained_from <= accepted_revision`), `state` (`DataLifecycle.Content`),
and `accepted` (`DataLifecycle.Position`). `Cut.requireRevision` rejects
revisions below `retained_from` with `DocumentHistoryUnavailable` and revisions
above `accepted_revision` with `DocumentRevisionBeyondCut`.

`Checkpoint` advances a document's merge epoch (`next_epoch == previous_epoch + 1`)
and establishes a validated `retained_from <= checkpoint_revision` with
a `checkpoint` content digest. `CheckpointReceipt` binds `checkpoint` and the
resulting `cut`.

`DocumentRead.Request` opens a bounded revision-range pin (`from_revision`,
optional `through_revision`, `max_steps`, `max_bytes`) under a
`DataLifecycle.Operation`. `Receipt` binds the original `request`, the pinned
`cut`, resolved `through_revision`, `source` (`DataLifecycle.Content`), and
`accepted` (`DataLifecycle.Position`). `Cursor` binds `read` (`Handle`),
cumulative `Coverage` (`cut`, `from_revision`, `through_revision`,
`next_revision`, `steps`, `bytes`, `complete`), and a non-zero 32-byte
`authentication` tag (`HMAC-SHA256` in storage). `Release` and `ReleaseReceipt`
record explicit pin release by the owning principal using a distinct operation.
