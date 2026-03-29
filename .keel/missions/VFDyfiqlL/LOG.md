# Ship Replicated Primary Handoff And Failover Semantics - Decision Log

<!-- Append entries below. Each entry is an H2 with ISO timestamp. -->
<!-- Use `keel mission digest` to compress older entries when this file grows large. -->

## 2026-03-28T20:48:00-07:00

- Opened this mission after the first replication handoff slice landed published frontier, read-only follower catch-up, and explicit `replicated` acknowledgements.
- Scoped this mission to the next bounded step: controlled primary transfer to a caught-up follower, explicit former-primary fencing, and proof surfaces that keep failover guarantees below quorum and multi-primary semantics.

## 2026-03-29T11:59:16

Mission achieved by local system user 'alex'

## 2026-03-29T11:59:36

Board repair note: the current keel CLI exposes pause/achieve/verify but not the matching mission resume command, so the paused mission was reactivated by repairing frontmatter state before the supported achieve/verify transitions were applied.
