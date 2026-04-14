---
# system-managed
id: VGn7fT2QB
status: done
created_at: 2026-04-14T11:28:16
updated_at: 2026-04-14T12:00:45
# authored
title: Keep Storage Probe Honest For Hosted Providers
type: feat
operator-signal:
scope: VGn6PdlVK/VGn6z2GXx
index: 1
started_at: 2026-04-14T11:58:16
submitted_at: 2026-04-14T12:00:43
completed_at: 2026-04-14T12:00:45
---

# Keep Storage Probe Honest For Hosted Providers

## Summary

Update the storage probe so it tells the truth for hosted providers and tiered
config. It should surface explicit guarantee and non-claim language instead of
pretending the old local-only probe contract still applies.

## Acceptance Criteria

- [x] [SRS-02/AC-01] `transit storage probe` reports hosted-provider guarantee and non-claim language that matches the actual runtime posture. <!-- verify: manual, SRS-02:start:end -->
  proof: `EVIDENCE/ac-1.log`
- [x] [SRS-NFR-01/AC-02] Probe output uses the same durability vocabulary as the hosted server and proof surfaces. <!-- verify: manual, SRS-NFR-01:start:end -->
  proof: `EVIDENCE/ac-2.log`
