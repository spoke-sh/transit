---
# system-managed
id: VGn9VkdSt
status: backlog
created_at: 2026-04-14T11:35:35
updated_at: 2026-04-14T11:35:49
# authored
title: Keep Hosted Ack Durability Truthful
type: feat
operator-signal:
scope: VGn6PdlVK/VGn6z2GXx
index: 3
---

# Keep Hosted Ack Durability Truthful

## Summary

Make the hosted server and recovery paths tell the truth about durability. A
configured `tiered` posture cannot show up as an acknowledgement label unless
the runtime has actually reached the remote authority boundary required by that
claim.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] Hosted append or recovery paths never label responses `tiered` unless the runtime has actually reached the authoritative remote tier required by that claim. <!-- verify: manual, SRS-01:start:end -->
- [ ] [SRS-NFR-01/AC-02] The durability vocabulary used by hosted acknowledgements stays aligned with the proof and probe surfaces. <!-- verify: manual, SRS-NFR-01:start:end -->
