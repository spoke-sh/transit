---
# system-managed
id: VGh5sVPck
status: done
created_at: 2026-04-13T10:43:32
updated_at: 2026-04-13T12:51:42
# authored
title: Add Hosted Authority Proof For External Producers And Readers
type: feat
operator-signal:
scope: VGh59soBt/VGh5B5qMT
index: 2
started_at: 2026-04-13T12:45:51
completed_at: 2026-04-13T12:51:42
---

# Add Hosted Authority Proof For External Producers And Readers

## Summary

Add a repo-native hosted-authority proof that writes representative consumer-owned records through a running transit-server, replays the acknowledged history back, and proves the workflow does not rely on a local embedded authority store.

## Acceptance Criteria

- [x] [SRS-02/AC-01] A proof path appends representative consumer-owned records to transit-server and replays the acknowledged history back through the hosted contract only. <!-- verify: cargo test -p transit-client hosted_authority_ -- --nocapture && cargo run -q -p transit-cli -- mission hosted-authority-proof --root target/transit-mission/hosted-authority, SRS-02:start:end, proof: ac-1.log-->
- [x] [SRS-NFR-02/AC-01] The proof output keeps durability posture explicit and does not claim `tiered` safety before the hosted authority path actually publishes to the remote tier. <!-- verify: cargo test -p transit-client hosted_authority_ -- --nocapture && cargo run -q -p transit-cli -- mission hosted-authority-proof --root target/transit-mission/hosted-authority --json, SRS-NFR-02:start:end, proof: ac-2.log-->
