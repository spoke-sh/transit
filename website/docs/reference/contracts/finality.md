---
title: "Finality And Fork Proofs"
sidebar_label: "Finality And Fork Proofs"
description: "Blockchain-style finality and fork proof contract over Transit lineage."
---

# Finality And Fork Proof Contract

Transit can support blockchain-style audit flows without becoming a blockchain
runtime. Applications own block validation, transaction execution, validator
membership, signing, fork choice, and consensus. Transit owns immutable records,
streams, branches, manifests, and lineage checkpoints.

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

Minimum fields:

- `proof_kind`
- `stream_id`
- `head_offset`
- `manifest_root`
- `parent_heads`
- `checkpoint_kind`
- `checkpoint_ref`
- `application_block`
- `selection_artifacts`

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

## Finality And Reorg Rules

Transit never rewrites acknowledged records to represent a reorg.

Use branches for fork candidates. Use an explicit merge or
canonical-selection artifact when an application chooses one path. Use a
lineage checkpoint to bind the selected stream id, head offset, manifest root,
parent heads, and checkpoint kind.

In this contract, finality means "this application accepted this Transit stream
head at this checkpoint boundary." Transit can prove the records, branch
ancestry, manifest root, and checkpoint envelope are internally consistent. It
does not decide whether the application's validator set, fork-choice rule, or
block execution result is correct.

## Non-Claims

Transit is not a complete blockchain consensus runtime. It does not provide a
mempool, transaction execution, validator-set management, peer gossip,
Byzantine consensus, proof-of-work, proof-of-stake, slashing, application fork
choice, signing, key management, or a light-client protocol for another chain.

Transit provides lineage and finality primitives that make application
decisions replayable and auditable once the application records them.
