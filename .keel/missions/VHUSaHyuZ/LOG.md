# Implement Immutable Segment Compression In Transit - Decision Log

<!-- Append entries below. Each entry is an H2 with ISO timestamp. -->
<!-- Use `keel mission digest` to compress older entries when this file grows large. -->

## 2026-04-21T22:28:00-07:00

- Delivered segment compression as a shared-engine storage feature with `zstd` as the default codec for sealed rolled segments and explicit descriptor metadata for codec, stored byte length, and uncompressed byte length.
- Preserved record semantics across local replay, tiered restore, and hosted reads by decoding compressed immutable segments back into normal Transit records at read time.
- Added operator proof coverage through `transit proof compression`, wired it into `just screen`, and updated public docs to distinguish segment compression from payload compression and transport compression.
- Closed a concurrent replay race surfaced by the hosted mixed producer/consumer workload test by tolerating the brief manifest-ahead-of-state window during segment roll publication.

## 2026-04-21T21:50:17

Mission achieved by local system user 'alex'
