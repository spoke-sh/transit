---
# system-managed
id: VHRmM9dNP
status: backlog
created_at: 2026-04-21T10:20:47
updated_at: 2026-04-21T10:25:32
# authored
title: Publish Hosted Timeout Proof Coverage And Operator Guidance
type: feat
operator-signal:
scope: VHRmIhDsm/VHRmIjGvL
index: 3
---

# Publish Hosted Timeout Proof Coverage And Operator Guidance

## Summary

Expose operator-facing timeout configuration and publish proof coverage and
guidance so the new hosted robustness behavior is visible on the CLI/server
surface instead of remaining test-only.

## Acceptance Criteria

- [ ] [SRS-03/AC-01] The CLI/server proof surface can configure the new hosted timeout values explicitly for proof runs. <!-- verify: cargo test -p transit-cli hosted_timeout_proof_ -- --nocapture, SRS-03:start:end -->
- [ ] [SRS-NFR-03/AC-02] Downstream-facing guidance documents the timeout knobs, their intended use, and the semantics they do not change. <!-- verify: manual, SRS-NFR-03:start:end -->
