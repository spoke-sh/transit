# Hosted Transit Authority For External Workloads And Derived State - Decision Log

<!-- Append entries below. Each entry is an H2 with ISO timestamp. -->
<!-- Use `keel mission digest` to compress older entries when this file grows large. -->

## 2026-04-13T10:45:00Z

- Created mission `VGh598Oz0` to make hosted Transit the authority for external workload history and derived state instead of letting downstream consumers such as Spoke Hub keep local embedded authority.
- Attached epic `VGh59soBt` with three voyages covering remote authority wiring, object-store authority with warm cache, and replayable reference projections.
- Decomposition intentionally keeps consumer business policy out of Transit core while still making room for downstream workloads such as Spoke auth/account/session.

## 2026-04-13T17:57:06Z

- Narrowed the mission vocabulary after operator feedback so Transit owns generic hosted authority, tiering, and projection mechanics rather than auth-specific concepts.
- Kept Spoke auth/account/session as a downstream motivating workload and adoption target, not a schema or policy surface defined inside Transit.
