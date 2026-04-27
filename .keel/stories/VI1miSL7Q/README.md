---
# system-managed
id: VI1miSL7Q
status: done
created_at: 2026-04-27T14:08:01
updated_at: 2026-04-27T14:50:52
# authored
title: Add Typed AI Trace Event Builders
type: feat
operator-signal:
scope: VI1mbSnsy/VI1mf8o0n
index: 2
started_at: 2026-04-27T14:47:20
completed_at: 2026-04-27T14:50:52
---

# Add Typed AI Trace Event Builders

## Summary

Add typed AI trace helpers for canonical agent workload entities so downstream runtimes can construct replayable traces without private label conventions.

## Acceptance Criteria

- [x] [SRS-02/AC-01] Typed builders cover task roots, retry branches, critique branches, tool-call events, evaluator decisions, merge artifacts, and completion checkpoints. <!-- [SRS-02/AC-01] verify: cargo test -p transit-core typed_builders_cover_ai_trace_contract_shapes -- --nocapture, SRS-02:start, SRS-02:end, proof: ac-1.log-->
- [x] [SRS-NFR-02/AC-01] Tests prove helper-generated traces preserve append-only history, branch ancestry, and explicit merge metadata. <!-- [SRS-NFR-02/AC-01] verify: cargo test -p transit-core ai_trace_helpers_preserve_lineage_and_explicit_merge_metadata -- --nocapture, SRS-NFR-02:start, SRS-NFR-02:end, proof: ac-2.log-->
