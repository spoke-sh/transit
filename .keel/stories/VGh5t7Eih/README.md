---
# system-managed
id: VGh5t7Eih
status: backlog
created_at: 2026-04-13T10:43:34
updated_at: 2026-04-13T10:45:58
# authored
title: Expose Thin Client Acknowledgement Guidance For Hosted Authority
type: docs
operator-signal:
scope: VGh59soBt/VGh5B5qMT
index: 3
---

# Expose Thin Client Acknowledgement Guidance For Hosted Authority

## Summary

Document the acknowledgement, error, and durability-posture guidance that thin clients and operators need when hosted Transit becomes the authority for downstream consumer workloads.

## Acceptance Criteria

- [ ] [SRS-03/AC-02] Operator-facing guidance explains how hosted authority acknowledgements, errors, and durability posture should be interpreted without reinterpreting server semantics in the client. <!-- verify: manual, SRS-03:start:end -->
- [ ] [SRS-04/AC-01] The authored docs state that local embedded Transit storage is not the authority for hosted consumer-owned workloads and describe the cutover boundary for Hub-like consumers. <!-- verify: manual, SRS-04:start:end -->
- [ ] [SRS-NFR-03/AC-01] The guidance keeps hosted authority integration focused on remote contracts and operator posture rather than moving consumer-owned policy into Transit core. <!-- verify: manual, SRS-NFR-03:start:end -->
