---
# system-managed
id: VFDykmbyK
status: done
created_at: 2026-03-28T20:44:27
updated_at: 2026-03-29T11:48:02
# authored
title: Fence Former Primaries After Handoff
type: feat
operator-signal:
scope: VFDyfjLlI/VFDyiCVpL
index: 3
started_at: 2026-03-29T11:46:19
submitted_at: 2026-03-29T11:47:58
completed_at: 2026-03-29T11:48:02
---

# Fence Former Primaries After Handoff

## Summary

Fence and demote the former primary after handoff so stale leaders cannot continue acknowledged writes and the post-transfer ownership posture stays explicit.

## Acceptance Criteria

- [x] [SRS-03/AC-01] Fence the former primary from further acknowledged writes after the handoff completes. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end, proof: ac-1.log-->
- [x] [SRS-03/AC-02] Leave the former primary in a non-primary or read-only posture until ownership is explicitly regained. <!-- [SRS-03/AC-02] verify: manual, SRS-03:continues, SRS-03:end, proof: ac-2.log-->
- [x] [SRS-NFR-01/AC-01] Preserve immutable acknowledged history and avoid rewrite or split-brain semantics while enforcing fencing. <!-- [SRS-NFR-01/AC-01] verify: manual, SRS-NFR-01:start, SRS-NFR-01:end, proof: ac-3.log-->
