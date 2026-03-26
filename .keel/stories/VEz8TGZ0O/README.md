---
# system-managed
id: VEz8TGZ0O
status: done
created_at: 2026-03-26T07:48:58
updated_at: 2026-03-26T08:20:47
# authored
title: Implement Integrity Proof CLI Command With Segment Checksum And Digest Verification
type: feat
operator-signal:
scope: VEz2gV93L/VEz3V79iG
index: 1
started_at: 2026-03-26T08:13:01
completed_at: 2026-03-26T08:20:47
---

# Implement Integrity Proof CLI Command With Segment Checksum And Digest Verification

## Summary

Add an `integrity-proof` CLI mission subcommand to `transit-cli` that appends records, triggers segment roll, and verifies segment checksums (fnv1a64) and content digests (sha256) on the sealed segments. Reports pass/fail per segment with both human-readable and `--json` output.

## Acceptance Criteria

- [x] [SRS-01/AC-01] `transit mission integrity-proof --root <path>` appends records to a stream, rolls at least one segment, and reports checksum and digest verification results per segment. <!-- [SRS-01/AC-01] verify: cargo test -p transit-cli && cargo run -q -p transit-cli -- mission integrity-proof --root target/transit-mission/integrity-proof, SRS-01:start:end, proof: ac-1.log-->
- [x] [SRS-01/AC-02] The command produces structured JSON output via `--json` containing per-segment verification status. <!-- [SRS-01/AC-02] verify: cargo test -p transit-cli integrity_proof_ && cargo run -q -p transit-cli -- mission integrity-proof --root target/transit-mission/integrity-proof-json --json, SRS-01:start:end, proof: ac-2.log-->
- [x] [SRS-NFR-01/AC-01] Integrity verification runs after segment roll, not during append acknowledgement. <!-- [SRS-NFR-01/AC-01] verify: code review, SRS-NFR-01:start:end, proof: ac-3.log-->
