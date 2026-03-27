---
source_type: Story
source: stories/VEz8XrwHS/REFLECT.md
scope: VEz2iOasp/VEz3VaL0a
source_story_id: VEz8XrwHS
created_at: 2026-03-26T23:53:00
---

### VL5mQ8pTs: Rust Tail Grant Credit Is A Poll Alias

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | When exposing logical tail sessions through the Rust client. |
| **Insight** | The server protocol has no separate grant-credit operation; additional credit is supplied on `poll_tail_session(session_id, credit)`, so a Rust `grant_credit()` method should be a thin alias over poll rather than a new client-side protocol layer. |
| **Suggested Action** | Keep Rust tail APIs explicit about the underlying credit-on-poll protocol and avoid inventing extra local session machinery unless the server contract changes. |
| **Applies To** | `crates/transit-client/src/client.rs`, `crates/transit-core/src/server.rs` |
| **Linked Knowledge IDs** |  |
| **Observed At** | 2026-03-26T23:52:30+00:00 |
| **Score** | 0.82 |
| **Confidence** | 0.97 |
| **Applied** | yes |
