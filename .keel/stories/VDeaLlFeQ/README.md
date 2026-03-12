---
id: VDeaLlFeQ
title: Implement Replay And Tail Reads From Local Manifests
type: feat
status: backlog
created_at: 2026-03-12T04:59:06
updated_at: 2026-03-12T05:01:14
operator-signal: 
scope: VDeYUdLSW/VDeaFjrZW
index: 1
---

# Implement Replay And Tail Reads From Local Manifests

## Summary

Implement the first local read path so replay and tail use committed segment and manifest state instead of ad hoc in-memory assumptions.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] The story implements replay over committed local segments in logical stream order using manifest metadata. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, proof: ac-1.log-->
- [ ] [SRS-03/AC-02] The story implements tail reads from the active local head without breaking replay correctness across rolled segments. <!-- [SRS-03/AC-02] verify: manual, SRS-03:continues, SRS-03:end, proof: ac-2.log-->
- [ ] [SRS-NFR-01/AC-01] The story keeps the read path local-first and single-node, without requiring remote hydration or server mode for correctness. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log-->
