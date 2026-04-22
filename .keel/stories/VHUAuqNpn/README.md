---
# system-managed
id: VHUAuqNpn
status: done
created_at: 2026-04-21T20:10:53
updated_at: 2026-04-21T20:26:47
# authored
title: Add Per-Stream Retention Metadata And Create-Time Surface
type: feat
operator-signal:
scope: VHUAlZWZG/VHUApus0L
index: 1
started_at: 2026-04-21T20:15:22
submitted_at: 2026-04-21T20:26:46
completed_at: 2026-04-21T20:26:47
---

# Add Per-Stream Retention Metadata And Create-Time Surface

## Summary

Add the explicit per-stream retention policy model, thread it through stream creation surfaces, and surface configured retention age/bytes in `transit streams list` without changing the default `retention = none` behavior.

## Acceptance Criteria

- [x] [SRS-01/AC-01] Stream metadata can represent `retention = none` plus optional `max_age_days` and `max_bytes` without changing existing unconfigured streams. <!-- [SRS-01/AC-01] verify: manual, SRS-01:start, SRS-01:end, proof: ac-1.log -->
- [x] [SRS-02/AC-01] Stream creation surfaces accept `--retention-max-age-days` and `--retention-max-bytes` so retention is configured explicitly per stream. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end, proof: ac-2.log -->
- [x] [SRS-03/AC-01] `transit streams list` shows `retention_age` and `retention_bytes` in human and JSON output for each stream. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end, proof: ac-3.log -->
- [x] [SRS-NFR-01/AC-01] Streams without an explicit retention policy continue to behave as `retention = none`; no implicit `30 day` default is introduced. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-4.log -->
