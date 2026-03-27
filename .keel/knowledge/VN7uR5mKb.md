---
source_type: Story
source: stories/VEz8YBlYR/REFLECT.md
scope: VEz2iOasp/VEz3VaL0a
source_story_id: VEz8YBlYR
created_at: 2026-03-26T23:59:03
---

### VN7uR5mKb: Native Client Proofs Should Boot The Server In Process

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | When delivering repo-local proof programs for thin client libraries. |
| **Insight** | An in-process server bootstrap via `ServerHandle::bind` keeps the proof self-contained, avoids shell orchestration, and still exercises the exact same network boundary the client uses. |
| **Suggested Action** | Prefer in-process local server startup for native client proof examples unless the story specifically requires the external CLI lifecycle. |
| **Applies To** | `crates/transit-client/examples/proof.rs`, proof binaries/examples |
| **Linked Knowledge IDs** | VL5mQ8pTs, VM6kT4nQe |
| **Observed At** | 2026-03-26T23:58:30+00:00 |
| **Score** | 0.80 |
| **Confidence** | 0.96 |
| **Applied** | yes |
