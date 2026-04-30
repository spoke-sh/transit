---
# system-managed
id: VIEZWlExV
status: done
created_at: 2026-04-29T18:37:10
updated_at: 2026-04-29T18:40:30
# authored
title: Allow Produce To Create Missing Stream
type: bug
operator-signal:
started_at: 2026-04-29T18:37:10
completed_at: 2026-04-29T18:40:30
---

# Allow Produce To Create Missing Stream

## Summary

Make the hosted operator `produce` path usable against a fresh server by
creating a missing root stream with explicit CLI lineage metadata before the
first append, then keep `consume` working against that stream.

## Acceptance Criteria

- [x] [SRS-02/AC-01] `transit produce` can append to a missing hosted root stream and `transit consume` can read the resulting record. <!-- [SRS-02/AC-01] verify: cargo test -p transit-cli produce_auto_creates_missing_root_stream_for_operator_flow -- --nocapture, SRS-02:start, SRS-02:end, proof: ac-1.log-->
- [x] [SRS-NFR-03/AC-01] Documentation states when to use explicit `streams create` metadata versus quick producer auto-create behavior. <!-- [SRS-NFR-03/AC-01] verify: root=$(git rev-parse --show-toplevel) && rg -n 'explicit .*streams create|transit produce.*creates a missing root stream' "$root/USER_GUIDE.md" && rg -n 'explicit creation step|transit produce.*creates' "$root/website/docs/start-here/server-first-run.mdx", SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-2.log-->
