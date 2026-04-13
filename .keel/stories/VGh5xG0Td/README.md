---
# system-managed
id: VGh5xG0Td
status: done
created_at: 2026-04-13T10:43:50
updated_at: 2026-04-13T13:03:39
# authored
title: Prove Hosted Restart And Warm-Cache Recovery Through Just Screen
type: feat
operator-signal:
scope: VGh59soBt/VGh5BgrVO
index: 3
started_at: 2026-04-13T13:03:13
completed_at: 2026-04-13T13:03:39
---

# Prove Hosted Restart And Warm-Cache Recovery Through Just Screen

## Summary

Extend the human proof path so operators can watch tiered publication, warm-cache loss, server restart, and authoritative recovery without guessing whether the result is only local or truly tiered.

## Acceptance Criteria

- [x] [SRS-04/AC-01] `just screen` or its equivalent proof surface demonstrates restart or deliberate cache-loss recovery from the authoritative remote tier. <!-- verify: nix develop --command just screen, SRS-04:start:end, proof: ac-1.log-->
- [x] [SRS-03/AC-01] The proof output distinguishes `local` from `tiered` posture so the recovery claim stays explicit. <!-- verify: nix develop --command just screen, SRS-03:start:end, proof: ac-2.log-->
