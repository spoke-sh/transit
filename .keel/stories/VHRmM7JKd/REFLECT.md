---
created_at: 2026-04-21T10:32:27
---

# Reflection - Add Configurable Hosted I/O Timeouts To Server And Client Surfaces

## Knowledge

<!--
Link existing knowledge files when the insight already exists:
- [123abcDEF](../../knowledge/123abcDEF.md) Existing knowledge title

Capture only novel/actionable knowledge that is likely useful in future work as
an inline candidate block. Unique entries are promoted into `.keel/knowledge/<id>.md`
on submit/accept.

If there is no reusable insight for this story, leave the Knowledge section empty.
Format:
### VHRpIM1Vq: Title
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

Builder-style timeout configuration fit the existing hosted transport shape
cleanly because both `ServerConfig` and `RemoteClient` already carried the
effective timeout internally behind a fixed 1000ms default.

The stable contract worth preserving on the client side is the response
envelope shape rather than exact remote error prose. The targeted proof showed
that timeout configuration can be added without changing ack topology,
durability fields, request correlation, or remote error categorization.
