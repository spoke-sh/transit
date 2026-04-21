# Improve Hosted Transit Robustness For Producer Consumer Workloads - Decision Log

<!-- Append entries below. Each entry is an H2 with ISO timestamp. -->
<!-- Use `keel mission digest` to compress older entries when this file grows large. -->

## 2026-04-21T18:10:00Z

- Landed configurable hosted I/O timeout surfaces in `transit-core`,
  `transit-client`, and the CLI proof/runtime entry points.
- Moved accepted connections onto per-connection worker threads while keeping a
  server-side request gate over the shared engine to preserve append and tail
  semantics under overlapping producer/consumer traffic.
- Published operator-facing proof flags and downstream guidance so hosted
  timeout tuning is explicit without implying any protocol or durability change.

## 2026-04-21T10:45:03

Mission achieved by local system user 'alex'
