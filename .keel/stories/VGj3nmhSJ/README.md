---
# system-managed
id: VGj3nmhSJ
status: done
created_at: 2026-04-13T18:47:49
updated_at: 2026-04-13T19:27:19
# authored
title: Define Hosted Endpoint Grammar And Auth Posture
type: feat
operator-signal:
scope: VGj3EvcuK/VGj3HXPMa
index: 1
started_at: 2026-04-13T19:24:44
submitted_at: 2026-04-13T19:27:15
completed_at: 2026-04-13T19:27:19
---

# Define Hosted Endpoint Grammar And Auth Posture

## Summary

Define how downstream consumers identify the authoritative hosted Transit
endpoint and how auth posture is expressed without falling back to
consumer-local protocol semantics.

## Acceptance Criteria

- [x] [SRS-01/AC-01] The hosted consumer contract defines the canonical endpoint grammar and auth posture for downstream repos. <!-- verify: manual, SRS-01:start:end, proof: ac-1.log -->
- [x] [SRS-NFR-01/AC-02] The authored endpoint and auth posture stays generic and does not absorb consumer-specific business semantics. <!-- verify: manual, SRS-NFR-01:start:end, proof: ac-2.log -->
