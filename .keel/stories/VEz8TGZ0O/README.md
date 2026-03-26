---
# system-managed
id: VEz8TGZ0O
status: backlog
created_at: 2026-03-26T07:48:58
updated_at: 2026-03-26T08:05:29
# authored
title: Implement Integrity Proof CLI Command With Segment Checksum And Digest Verification
type: feat
operator-signal:
scope: VEz2gV93L/VEz3V79iG
index: 1
---

# Implement Integrity Proof CLI Command With Segment Checksum And Digest Verification

## Summary

Add an `integrity-proof` CLI mission subcommand to `transit-cli` that appends records, triggers segment roll, and verifies segment checksums (fnv1a64) and content digests (sha256) on the sealed segments. Reports pass/fail per segment with both human-readable and `--json` output.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] `transit mission integrity-proof --root <path>` appends records to a stream, rolls at least one segment, and reports checksum and digest verification results per segment. <!-- [SRS-01/AC-01] verify: cargo test + just screen, SRS-01:start:end -->
- [ ] [SRS-01/AC-02] The command produces structured JSON output via `--json` containing per-segment verification status. <!-- [SRS-01/AC-02] verify: cargo test, SRS-01:start:end -->
- [ ] [SRS-NFR-01/AC-01] Integrity verification runs after segment roll, not during append acknowledgement. <!-- [SRS-NFR-01/AC-01] verify: code review, SRS-NFR-01:start:end -->
