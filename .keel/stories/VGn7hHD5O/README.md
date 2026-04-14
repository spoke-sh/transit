---
# system-managed
id: VGn7hHD5O
status: backlog
created_at: 2026-04-14T11:28:23
updated_at: 2026-04-14T11:35:49
# authored
title: Publish Canonical Downstream Cutover Contract
type: feat
operator-signal:
scope: VGn6PdlVK/VGn6zxceG
index: 1
---

# Publish Canonical Downstream Cutover Contract

## Summary

Refresh the upstream docs and client examples so downstream repos have one
published cutover target and clear instruction to delete private adapters
instead of preserving them.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] The published runtime contract describes the canonical hosted endpoint grammar and runtime posture downstream repos should target. <!-- verify: manual, SRS-01:start:end -->
- [ ] [SRS-02/AC-02] `transit-client` remains the documented Rust import surface for hosted consumers. <!-- verify: manual, SRS-02:start:end -->
- [ ] [SRS-03/AC-03] Direct-cutover guidance explicitly tells downstream repos to remove duplicate private adapters rather than keep them as a compatibility lane. <!-- verify: manual, SRS-03:start:end -->
