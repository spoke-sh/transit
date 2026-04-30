---
# system-managed
id: VIEdDmAax
status: done
created_at: 2026-04-29T18:51:50
updated_at: 2026-04-29T18:54:12
# authored
title: Add Server Address To SQL Command
type: feat
operator-signal:
started_at: 2026-04-29T18:51:50
completed_at: 2026-04-29T18:54:12
---

# Add Server Address To SQL Command

## Summary

Add `--server-addr` to `transit sql` so hosted stream records can be loaded
from a transit server as Prolly-backed DataFusion tables, while preserving the
existing local `--row` SQL mode.

## Acceptance Criteria

- [x] [SRS-02/AC-01] `transit sql --server-addr <addr>` loads hosted streams as SQL tables and can query them by stream id. <!-- [SRS-02/AC-01] verify: cargo test -p transit-cli sql_command_loads_hosted_streams_from_server_addr -- --nocapture, SRS-02:start, SRS-02:end, proof: ac-1.log-->
- [x] [SRS-02/AC-02] Existing local Prolly-backed `transit sql --row ...` behavior still works without `--server-addr`. <!-- [SRS-02/AC-02] verify: cargo test -p transit-cli sql_command_initializes_prolly_backend_and_pretty_prints_results -- --nocapture, SRS-02:continues, SRS-02:end, proof: ac-2.log-->
- [x] [SRS-NFR-03/AC-01] User-facing docs describe querying hosted streams with `transit sql --server-addr`. <!-- [SRS-NFR-03/AC-01] verify: root=$(git rev-parse --show-toplevel) && rg -n 'transit sql --server-addr|--server-addr 127.0.0.1:7171' "$root/USER_GUIDE.md" "$root/website/docs/start-here/server-first-run.mdx", SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-3.log-->
