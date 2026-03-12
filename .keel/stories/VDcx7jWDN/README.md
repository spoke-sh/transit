---
id: VDcx7jWDN
title: Upgrade Just Mission To Exercise The Storage Kernel
type: feat
status: backlog
created_at: 2026-03-11T22:17:01
updated_at: 2026-03-11T22:21:40
operator-signal: 
scope: VDcx2lQGz/VDcx4sb6D
index: 3
---

# Upgrade Just Mission To Exercise The Storage Kernel

## Summary

Upgrade the human-facing proof path so `just mission` validates the storage-kernel slice rather than
only bootstrap health, and keeps the CLI proof surface aligned with the mission.

## Acceptance Criteria

- [ ] [SRS-04/AC-01] `just mission` exercises the current storage-kernel slice through tests and CLI proofs. <!-- [SRS-04/AC-01] verify: nix develop path:/home/alex/workspace/spoke-sh/transit --command just mission, SRS-04:start, proof: ac-1.log-->
- [ ] [SRS-04/AC-02] CLI mission status output surfaces kernel-oriented progress in human-readable form. <!-- [SRS-04/AC-02] verify: cargo run -p transit-cli --bin transit -- mission status --repo-root ., SRS-04:continues, proof: ac-2.log-->
- [ ] [SRS-NFR-03/AC-01] The proof path remains one obvious operator entrypoint instead of spreading across ad hoc commands. <!-- [SRS-NFR-03/AC-01] verify: just mission, SRS-NFR-03:start, SRS-NFR-03:end, proof: ac-3.log-->
