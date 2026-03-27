---
source_type: Story
source: stories/VEz8Y3TQE/REFLECT.md
scope: VEz2iOasp/VEz3VaL0a
source_story_id: VEz8Y3TQE
created_at: 2026-03-26T23:55:06
---

### VM6kT4nQe: Thin Client Tests Should Assert Both Ack And Body

| Field | Value |
|-------|-------|
| **Category** | testing |
| **Context** | When adding thin wrapper methods to `transit-client`. |
| **Insight** | Wrapper tests need to assert both the acknowledgement envelope and the returned body shape, because the client contract is to preserve server durability/topology/error semantics while also surfacing the underlying operation result unchanged. |
| **Suggested Action** | For new Rust client methods, include one success-path test that checks `ack()` fields and body contents together, plus one error-path test that checks the remote error envelope without depending on brittle message text. |
| **Applies To** | `crates/transit-client/src/client.rs` |
| **Linked Knowledge IDs** |  |
| **Observed At** | 2026-03-26T23:55:30+00:00 |
| **Score** | 0.76 |
| **Confidence** | 0.94 |
| **Applied** | yes |
