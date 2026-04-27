# Finality And Fork Proof Contract

This document defines how blockchain-style downstream systems can use Transit
lineage without turning Transit into a blockchain runtime.

Transit supplies append-only records, streams, branches, manifests, and lineage
checkpoints. Applications supply block validation, transaction execution,
signing, fork-choice policy, validator membership, and any Byzantine-consensus
mechanism.

## Design Center

The contract should let a downstream system answer three questions from Transit
history:

- which stream head was considered canonical at a named boundary
- which parent heads or fork candidates led to that head
- which manifest root and checkpoint bind the claimed head to immutable history

Those answers must be replayable from Transit storage. They should not depend on
hidden mutable application state.

## Primitive Mapping

| Blockchain-style concept | Transit primitive | Contract rule |
|--------------------------|-------------------|---------------|
| Block | Record or append batch | Store the block body, block reference, or application envelope as immutable payload bytes. |
| Chain or lane | Stream | A stream id names the ordered lane being audited. |
| Block height | Offset plus application metadata | Transit offset is the storage position; application block height remains payload metadata when it differs. |
| Parent block | `StreamPosition` or payload metadata | Parent links must be recoverable from Transit lineage and/or the application block envelope. |
| Fork | Branch | A fork is a child stream created from the parent stream at the divergence offset. |
| Candidate fork head | Branch head | Each candidate advances its own stream head without mutating the parent. |
| Reorg decision | Merge artifact or canonical-selection artifact | Reorg handling must be explicit data that names selected and superseded heads. |
| Finality marker | Lineage checkpoint | A checkpoint binds a chosen stream head to a manifest root and checkpoint kind. |
| State root | Application metadata or materialized snapshot ref | Transit can carry the reference, but it does not compute chain state. |

## Proof Envelope

A blockchain-style proof envelope is an application-facing view over existing
Transit integrity surfaces. It should carry enough information for another
process to reload the manifest, verify the checkpoint, and replay the selected
history.

Minimum fields:

- `proof_kind`: stable proof schema name, such as `transit.finality.v1`
- `stream_id`: stream whose head is being proven
- `head_offset`: stream-local offset of the proven head
- `manifest_root`: manifest root observed at the proof boundary
- `parent_heads`: ordered parent, fork, or merge heads as `stream_id` plus offset
- `checkpoint_kind`: checkpoint role, such as `finality`, `fork-choice`,
  `reorg-selection`, or `published-result`
- `checkpoint_ref`: optional durable id or object reference for the checkpoint
- `application_block`: optional block metadata owned by the downstream system
- `selection_artifacts`: optional records that explain fork choice or reorg
  policy

Root or genesis proofs may use an empty `parent_heads` list. Every other proof
should name the parent head or candidate heads that explain how the proven head
was reached.

Example finality envelope:

```json
{
  "proof_kind": "transit.finality.v1",
  "stream_id": "chain.main",
  "head_offset": 12042,
  "manifest_root": "blake3:5f3d4e9c...",
  "parent_heads": [
    {
      "stream_id": "chain.main",
      "offset": 12041,
      "role": "parent-block"
    }
  ],
  "checkpoint_kind": "finality",
  "checkpoint_ref": "checkpoints/chain.main/12042.json",
  "application_block": {
    "chain_id": "example-l2",
    "block_height": 12042,
    "block_hash": "0x8f1c...",
    "parent_block_hash": "0x4b7a...",
    "state_root": "0xa51d..."
  }
}
```

Example fork-choice envelope:

```json
{
  "proof_kind": "transit.fork-choice.v1",
  "stream_id": "chain.main.canonical-selection",
  "head_offset": 88,
  "manifest_root": "blake3:ad21c0...",
  "parent_heads": [
    {
      "stream_id": "chain.main.fork-a",
      "offset": 12044,
      "role": "selected"
    },
    {
      "stream_id": "chain.main.fork-b",
      "offset": 12043,
      "role": "superseded"
    }
  ],
  "checkpoint_kind": "reorg-selection",
  "checkpoint_ref": "checkpoints/chain.main.canonical-selection/88.json",
  "selection_artifacts": [
    {
      "stream_id": "chain.main.canonical-selection",
      "offset": 88,
      "policy": "application-fork-choice-v3"
    }
  ],
  "application_block": {
    "chain_id": "example-l2",
    "selected_block_hash": "0x91ab...",
    "superseded_block_hashes": ["0x733a..."]
  }
}
```

## Fork And Reorg Handling

Transit never rewrites acknowledged records to represent a reorg.

Downstream applications should use one of two explicit patterns:

- create a branch for each fork candidate and append candidate blocks to that
  branch until the application chooses a winner
- append a canonical-selection artifact that names the selected head,
  superseded heads, fork-choice policy, actor, reason, and timestamp

When paths need to converge into a new Transit lineage state, use an explicit
merge with parent heads and merge policy. When the application only needs to
declare a canonical chain head, use a selection artifact rather than pretending
that the losing branch never existed.

## Finality Semantics

In this contract, finality means "this application accepted this Transit stream
head at this checkpoint boundary." A finality proof must bind:

- the selected stream id
- the selected head offset
- the manifest root for the immutable history behind that head
- parent heads or selected/superseded fork heads when relevant
- checkpoint kind and optional checkpoint reference
- optional application block metadata such as block hash, height, parent hash,
  state root, or validator evidence reference

Transit can prove that the records, branch ancestry, manifest root, and
checkpoint envelope are internally consistent. It does not decide whether the
application's validator set, fork-choice rule, or block execution result is
correct.

## Verification Flow

A verifier should:

1. Load the named stream and head offset.
2. Load the manifest referenced by `manifest_root`.
3. Verify the manifest root and referenced segment digests according to
   [INTEGRITY.md](INTEGRITY.md).
4. Verify the lineage checkpoint for `stream_id`, `head_offset`,
   `manifest_root`, parent heads, and `checkpoint_kind`.
5. Replay records through the chosen head and inspect any
   `selection_artifacts`.
6. Apply application-owned validation to `application_block` metadata.

Step 6 is intentionally outside Transit core.

## Non-Claims

Transit is not a complete blockchain consensus runtime.

Transit does not provide:

- a mempool
- transaction execution or a virtual machine
- validator-set management
- peer gossip
- Byzantine consensus
- proof-of-work, proof-of-stake, slashing, or staking logic
- canonical fork choice for an application
- application block signing or key management
- a light-client protocol for another chain

Transit provides lineage and finality primitives that make those application
decisions replayable and auditable once the application records them.

## Relationship To Materialization

Materialized state can cite the same finality proof surface. A materializer may
store a state root, Prolly snapshot root, or opaque state reference in
application metadata, then bind it to a Transit lineage checkpoint. The state is
valid only to the extent that it can be rebuilt or verified from Transit replay
plus application-owned reducer logic.
