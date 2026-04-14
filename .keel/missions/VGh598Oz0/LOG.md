# Hosted Transit Authority For External Workloads And Derived State - Decision Log

<!-- Append entries below. Each entry is an H2 with ISO timestamp. -->
<!-- Use `keel mission digest` to compress older entries when this file grows large. -->

## 2026-04-13T10:45:00Z

- Created mission `VGh598Oz0` to make hosted Transit the authority for external workload history and derived state instead of letting downstream control planes keep local embedded authority.
- Attached epic `VGh59soBt` with three voyages covering remote authority wiring, object-store authority with warm cache, and replayable reference projections.
- Decomposition intentionally keeps consumer business policy out of Transit core while still making room for downstream workload adoption.

## 2026-04-13T17:57:06Z

- Narrowed the mission vocabulary after operator feedback so Transit owns generic hosted authority, tiering, and projection mechanics rather than auth-specific concepts.
- Kept the motivating workload generic so adoption remains a downstream concern, not a schema or policy surface defined inside Transit.

## 2026-04-13T13:18:05

Mission achieved by local system user 'alex'
