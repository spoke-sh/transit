---
# system-managed
id: VGnPMhkYT
status: backlog
created_at: 2026-04-14T12:38:34
updated_at: 2026-04-14T12:41:54
# authored
title: Add Projection Read Consumer API To Transit Client
type: feat
operator-signal:
scope: VGnPIhJl2/VGnPLHvGm
index: 1
---

# Add Projection Read Consumer API To Transit Client

## Summary

Publish the first generic `transit-client` projection-consumer helper so
downstream Rust repos can derive current projection views from hosted Transit
replay without carrying a private projection-read wrapper.

## Acceptance Criteria

- [ ] [SRS-01/AC-01] `transit-client` publishes a generic projection-consumer API that reduces authoritative hosted replay into a current view. <!-- verify: cargo test -p transit-client projection_read_ -- --nocapture, SRS-01:start:end -->
- [ ] [SRS-02/AC-02] The helper preserves the hosted acknowledgement boundary while surfacing projection revision/output metadata a downstream wrapper can reuse. <!-- verify: cargo test -p transit-client projection_read_ -- --nocapture, SRS-02:start:end -->
- [ ] [SRS-03/AC-03] A hosted proof or example flow demonstrates a representative reference projection read through the new upstream client surface. <!-- verify: cargo run -q -p transit-client --example proof, SRS-03:start:end -->
- [ ] [SRS-NFR-01/AC-04] The API remains generic and replay-driven instead of codifying consumer schema or introducing a projection-only server truth path. <!-- verify: manual, SRS-NFR-01:start:SRS-NFR-02:end -->
