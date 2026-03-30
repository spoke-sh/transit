---
# system-managed
id: VFOQ1qjvK
status: done
created_at: 2026-03-30T15:35:31
updated_at: 2026-03-30T16:20:18
# authored
title: Implement Quorum Acknowledgement Logic
type: feat
operator-signal:
scope: VFOPrFVvq/VFOPuiaUH
index: 4
started_at: 2026-03-30T15:37:12
completed_at: 2026-03-30T16:20:18
---

# Implement Quorum Acknowledgement Logic

## Summary

Implement the logic to block acknowledgements until a quorum of nodes has confirmed receipt.

## Acceptance Criteria

- [x] [SRS-04/AC-01] The engine blocks a quorum-mode append until `quorum_size()` nodes have acknowledged it. <!-- verify: cargo test -p transit-core engine::tests::engine_requires_quorum_to_acknowledge, SRS-04:start, SRS-04:end, proof: ac-1.log -->
- [x] [SRS-04/AC-02] Timeouts and partial acknowledgement scenarios are handled without data loss or corruption. <!-- verify: cargo test -p transit-core engine::tests::engine_quorum_append_times_out_if_no_acks, SRS-04:continues, SRS-04:end, proof: ac-2.log -->
- [x] [SRS-04/AC-03] A quorum of `(n/2)+1` is correctly calculated for various cluster sizes. <!-- verify: cargo test -p transit-core membership::tests, SRS-04:continues, SRS-04:end, proof: ac-3.log -->
