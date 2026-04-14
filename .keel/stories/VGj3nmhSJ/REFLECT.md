---
created_at: 2026-04-13T19:26:05
---

# Reflection - Define Hosted Endpoint Grammar And Auth Posture

## Knowledge

<!--
Link existing knowledge files when the insight already exists:
- [123abcDEF](../../knowledge/123abcDEF.md) Existing knowledge title

Capture only novel/actionable knowledge that is likely useful in future work as
an inline candidate block. Unique entries are promoted into `.keel/knowledge/<id>.md`
on submit/accept.

If there is no reusable insight for this story, leave the Knowledge section empty.
Format:
### VGjDQyN2p: Title
| Field | Value |
|-------|-------|
| **Category** | code/testing/process/architecture |
| **Context** | describe when this applies |
| **Insight** | the fundamental discovery |
| **Suggested Action** | what to do next time |
| **Applies To** | file patterns or components |
| **Linked Knowledge IDs** | optional canonical IDs this insight builds on |
| **Observed At** | RFC3339 timestamp (e.g. 2026-02-22T12:00:00Z) |
| **Score** | 0.0-1.0 (impact significance) |
| **Confidence** | 0.0-1.0 (insight quality) |
| **Applied** | |
-->

## Observations

The useful move here was to publish one Transit-owned hosted consumer contract
at the repo root instead of trying to encode the boundary indirectly across
README and configuration notes. That gave downstream consumers one canonical
place to read endpoint grammar, address roles, and auth posture.

The main difficulty was staying honest about auth. The configuration contract
already exposed `auth_mode`, but the runtime does not yet enforce `token` or
`mtls` on the wire, so the docs needed to carry explicit non-claims instead of
implying stronger guarantees than the implementation currently provides.
