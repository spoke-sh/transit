---
id: VDd5Cv9mT
title: Specify Artifact And Metadata Envelope Conventions
type: feat
status: done
created_at: 2026-03-11T22:49:08
updated_at: 2026-03-11T22:59:27
operator-signal: 
scope: VDd1EybWm/VDd551Q7R
index: 2
started_at: 2026-03-11T22:58:19
submitted_at: 2026-03-11T22:59:27
completed_at: 2026-03-11T22:59:28
---

# Specify Artifact And Metadata Envelope Conventions

## Summary

Specify how AI workloads should represent large prompts, outputs, attachments, and execution traces through `transit` records plus object-store-backed artifact references, including the metadata fields needed for replay and audit.

## Acceptance Criteria

- [x] [SRS-03/AC-01] The story defines the artifact-envelope contract for large AI payloads and its relationship to object storage. <!-- [SRS-03/AC-01] verify: manual, SRS-03:start, SRS-03:end, proof: ac-1.log-->
- [x] [SRS-02/AC-02] The story records which metadata must stay inline versus which content should be referenced externally. <!-- [SRS-02/AC-02] verify: manual, SRS-02:continues, SRS-02:end, proof: ac-2.log-->
