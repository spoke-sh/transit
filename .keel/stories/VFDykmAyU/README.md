---
# system-managed
id: VFDykmAyU
status: backlog
created_at: 2026-03-28T20:44:27
updated_at: 2026-03-28T20:49:38
# authored
title: Implement Lease-Backed Primary Transfer
type: feat
operator-signal:
scope: VFDyfjLlI/VFDyiCVpL
index: 2
---

# Implement Lease-Backed Primary Transfer

## Summary

Implement the explicit lease-backed handoff path that transfers writable ownership to an eligible follower without smuggling in quorum acknowledgement or multi-primary behavior.

## Acceptance Criteria

- [ ] [SRS-02/AC-01] Transfer writable ownership only through an explicit lease-backed handoff path. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, SRS-02:end -->
- [ ] [SRS-02/AC-02] Reject handoff attempts when the target follower is not eligible or the current primary state is incompatible with transfer. <!-- [SRS-02/AC-02] verify: manual, SRS-02:continues, SRS-02:end -->
- [ ] [SRS-NFR-02/AC-01] Keep the transfer flow below quorum acknowledgement, majority election, and multi-primary semantics. <!-- [SRS-NFR-02/AC-01] verify: manual, SRS-NFR-02:start, SRS-NFR-02:end -->
