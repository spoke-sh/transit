---
id: VDeb9ncrT
title: Implement Cold Restore From Remote Manifests
type: feat
status: backlog
created_at: 2026-03-12T05:02:19
updated_at: 2026-03-12T05:03:22
operator-signal: 
scope: VDeYUdLSW/VDeb794qi
index: 1
---

# Implement Cold Restore From Remote Manifests

## Summary

Implement cold restore so the local engine can rebuild usable state from remote manifests and segment objects without requiring a server-mode wrapper.

## Acceptance Criteria

- [ ] [SRS-02/AC-01] The story implements cold restore that reconstructs local engine state from remote manifests and referenced segment objects. <!-- [SRS-02/AC-01] verify: manual, SRS-02:start, proof: ac-1.log-->
- [ ] [SRS-02/AC-02] The restored engine state supports logical replay using the same manifest and segment semantics as normal local execution. <!-- [SRS-02/AC-02] verify: manual, SRS-02:continues, SRS-02:end, proof: ac-2.log-->
- [ ] [SRS-NFR-03/AC-01] The restore path remains single-node and local-first even while sourcing history from object storage. <!-- [SRS-NFR-03/AC-01] verify: manual, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-3.log-->
