---
# system-managed
id: VEz8Td6GO
status: backlog
created_at: 2026-03-26T07:48:59
updated_at: 2026-03-26T08:05:29
# authored
title: Add Tamper Detection And Server Parity Verification To Integrity Command
type: feat
operator-signal:
scope: VEz2gV93L/VEz3V79iG
index: 3
---

# Add Tamper Detection And Server Parity Verification To Integrity Command

## Summary

Extend the `integrity-proof` command with a tamper-detection scenario that corrupts a sealed segment file and confirms `verify_local_lineage()` detects and reports the corruption. Also verify integrity operations produce consistent results through the networked server path.

## Acceptance Criteria

- [ ] [SRS-04/AC-01] The integrity proof corrupts a sealed segment file on disk and confirms that `verify_local_lineage()` detects and reports the corruption as a failed verification. <!-- [SRS-04/AC-01] verify: cargo test + just screen, SRS-04:start:end -->
- [ ] [SRS-05/AC-01] The integrity proof exercises integrity verification through the networked server path and confirms shared-engine parity. <!-- [SRS-05/AC-01] verify: cargo test + just screen, SRS-05:start:end -->
