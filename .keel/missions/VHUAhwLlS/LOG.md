# Add Explicit Per-Stream Retention To Transit - Decision Log

<!-- Append entries below. Each entry is an H2 with ISO timestamp. -->
<!-- Use `keel mission digest` to compress older entries when this file grows large. -->

## 2026-04-22T03:48:28Z

- Landed explicit per-stream retention metadata with no default policy and
  create-time CLI/protocol flags for `max_age_days` and `max_bytes`.
- Added shared-engine retention enforcement that trims only whole rolled
  segments, preserves the active segment, and surfaces the retained frontier as
  `retained_start_offset` across embedded and hosted status surfaces.
- Published a dedicated `transit proof retention` path, wired it into
  `just screen`, and updated the public docs to explain bounded replay and the
  distinction between retention, compaction, and selective erasure.

## 2026-04-21T20:48:40

Mission achieved by local system user 'alex'
