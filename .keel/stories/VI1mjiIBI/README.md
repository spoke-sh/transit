---
# system-managed
id: VI1mjiIBI
status: done
created_at: 2026-04-27T14:08:05
updated_at: 2026-04-27T15:18:10
# authored
title: Define Blockchain-Style Finality And Fork Proof Contract
type: docs
operator-signal:
scope: VI1mcFKum/VI1mfwr25
index: 3
started_at: 2026-04-27T15:14:13
completed_at: 2026-04-27T15:18:10
---

# Define Blockchain-Style Finality And Fork Proof Contract

## Summary

Define the blockchain-style finality and fork proof contract that maps records, branches, checkpoints, and explicit merge or selection artifacts onto Transit lineage without claiming a full chain runtime.

## Acceptance Criteria

- [x] [SRS-05/AC-01] A public contract documents blocks as records, forks as branches, finality as checkpoints, and reorg handling as explicit merge or canonical-selection artifacts. <!-- [SRS-05/AC-01] verify: root=$(git rev-parse --show-toplevel) && rg -n "Block|Fork|Finality marker|Reorg decision|canonical-selection" "$root/FINALITY.md" "$root/website/docs/reference/contracts/finality.md", SRS-05:start, SRS-05:end, proof: ac-1.log-->
- [x] [SRS-05/AC-02] Proof envelope examples bind stream id, head offset, manifest root, parent heads, checkpoint kind, and optional application block metadata. <!-- [SRS-05/AC-02] verify: root=$(git rev-parse --show-toplevel) && rg -n "stream_id|head_offset|manifest_root|parent_heads|checkpoint_kind|application_block" "$root/FINALITY.md" "$root/website/docs/reference/contracts/finality.md", SRS-05:start, SRS-05:end, proof: ac-2.log-->
- [x] [SRS-NFR-03/AC-01] Documentation clearly states that Transit supplies lineage and finality primitives, not a complete blockchain consensus runtime. <!-- [SRS-NFR-03/AC-01] verify: root=$(git rev-parse --show-toplevel) && rg -n "not a complete blockchain consensus runtime|does not provide|applications still own consensus" "$root/FINALITY.md" "$root/website/docs/reference/contracts/finality.md", SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-3.log-->
