---
# system-managed
id: VIIPPsTgW
status: done
created_at: 2026-04-30T10:22:05
updated_at: 2026-04-30T10:29:04
# authored
title: Materialize Json Payloads For SQL
type: feat
operator-signal:
started_at: 2026-04-30T10:22:10
completed_at: 2026-04-30T10:29:04
---

# Materialize Json Payloads For SQL

## Summary

Materialize hosted JSON stream payloads into SQL event tables instead of
exposing only opaque key/value rows. Preserve one row per Transit record,
surface lineage metadata as reserved columns, and support `LAST(column)` as a
current-state shorthand ordered by stream offset.

## Acceptance Criteria

- [x] [SRS-02/AC-01] Hosted `transit sql --server-addr` tables expose top-level JSON object fields as queryable columns while preserving one row per record. <!-- [SRS-02/AC-01] verify: cargo test -p transit-cli sql_command_materializes_hosted_json_payload_fields -- --nocapture, SRS-02:start, SRS-02:end, proof: ac-1.log-->
- [x] [SRS-02/AC-02] `LAST(column)` over hosted SQL tables returns the value at the highest `_offset` in each group. <!-- [SRS-02/AC-02] verify: cargo test -p transit-cli sql_command_last_alias_reads_current_state_by_offset -- --nocapture, SRS-02:start, SRS-02:end, proof: ac-2.log-->
- [x] [SRS-NFR-03/AC-01] User-facing docs describe hosted JSON SQL columns, metadata columns, and `LAST(column)` current-state queries. <!-- [SRS-NFR-03/AC-01] verify: just docs-build, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-3.log-->
