---
# system-managed
id: VGh5t7Eih
status: done
created_at: 2026-04-13T10:43:34
updated_at: 2026-04-13T12:54:03
# authored
title: Expose Thin Client Acknowledgement Guidance For Hosted Authority
type: docs
operator-signal:
scope: VGh59soBt/VGh5B5qMT
index: 3
started_at: 2026-04-13T12:52:48
submitted_at: 2026-04-13T12:53:58
completed_at: 2026-04-13T12:54:03
---

# Expose Thin Client Acknowledgement Guidance For Hosted Authority

## Summary

Document the acknowledgement, error, and durability-posture guidance that thin clients and operators need when hosted Transit becomes the authority for downstream consumer workloads.

## Acceptance Criteria

- [x] [SRS-03/AC-02] Operator-facing guidance explains how hosted authority acknowledgements, errors, and durability posture should be interpreted without reinterpreting server semantics in the client. <!-- verify: manual, SRS-03:start:end, proof: ac-1.log-->
- [x] [SRS-04/AC-01] The authored docs state that local embedded Transit storage is not the authority for hosted consumer-owned workloads and describe the cutover boundary for Hub-like consumers. <!-- verify: manual, SRS-04:start:end, proof: ac-2.log-->
- [x] [SRS-NFR-03/AC-01] The guidance keeps hosted authority integration focused on remote contracts and operator posture rather than moving consumer-owned policy into Transit core. <!-- verify: manual, SRS-NFR-03:start:end, proof: ac-3.log-->
