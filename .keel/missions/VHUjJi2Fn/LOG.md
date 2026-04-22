# Unify Published Transit Storage Around Object-Store Authority - Decision Log

<!-- Append entries below. Each entry is an H2 with ISO timestamp. -->
<!-- Use `keel mission digest` to compress older entries when this file grows large. -->

## 2026-04-21T23:18:00-07:00

- Defined the published frontier contract with explicit `PublishedFrontier` metadata so latest manifest discovery is carried as a first-class object instead of an implicit mutable manifest rewrite.
- Routed local published segments, manifest snapshots, and `frontiers/latest.json` through the same object-style namespace used by remote publication, while keeping `active.segment` and `state.json` as the mutable working plane.
- Added `transit proof object-store-authority`, wired it into `just screen`, and updated public plus operator docs to explain the working-plane versus published-plane split and the frontier pointer boundary.

## 2026-04-21T23:00:07

Mission achieved by local system user 'alex'
