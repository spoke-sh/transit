---
# system-managed
id: VEz8Td6GO
status: done
created_at: 2026-03-26T07:48:59
updated_at: 2026-03-26T09:10:15
# authored
title: Add Tamper Detection And Server Parity Verification To Integrity Command
type: feat
operator-signal:
scope: VEz2gV93L/VEz3V79iG
index: 3
started_at: 2026-03-26T09:04:35
completed_at: 2026-03-26T09:10:15
---

# Add Tamper Detection And Server Parity Verification To Integrity Command

## Summary

Extend the `integrity-proof` command with a tamper-detection scenario that corrupts a sealed segment file and confirms `verify_local_lineage()` detects and reports the corruption. Also verify integrity operations produce consistent results through the networked server path.

## Acceptance Criteria

- [x] [SRS-04/AC-01] The integrity proof corrupts a sealed segment file on disk and confirms that `verify_local_lineage()` detects and reports the corruption as a failed verification. <!-- [SRS-04/AC-01] verify: cargo run -q -p transit-cli -- mission integrity-proof --root target/transit-mission/integrity-proof-tamper-verify --json, SRS-04:start, SRS-04:end, proof: ac-1.log-->
- [x] [SRS-05/AC-01] The integrity proof exercises integrity verification through the networked server path and confirms shared-engine parity. <!-- [SRS-05/AC-01] verify: cargo test -p transit-cli integrity_proof_, SRS-05:start, SRS-05:end, proof: ac-2.log-->
