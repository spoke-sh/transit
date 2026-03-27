---
created_at: 2026-03-26T23:55:06
---

# Reflection - Add Lineage Inspection To Rust Client

## Knowledge

- [VM6kT4nQe](../../knowledge/VM6kT4nQe.md) Thin Client Tests Should Assert Both Ack And Body

## Observations

- The lineage story fit the thin-wrapper rule well because `RemoteClient::inspect_lineage()` already exposed the exact operation and result type needed.
- The missing-stream error path was better asserted via code, topology, and request-id presence than via literal filesystem wording, which is implementation-specific.
- Verifying both branch and merge lineage in one success-path test gave better coverage of the DAG contract without growing the client surface.
