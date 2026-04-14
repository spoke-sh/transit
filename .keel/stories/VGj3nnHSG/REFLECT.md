---
created_at: 2026-04-13T19:29:05
---

# Reflection - Define Consumer Acknowledgement And Error Contract

## Knowledge

<!--
Link existing knowledge files when the insight already exists:
- [123abcDEF](../../knowledge/123abcDEF.md) Existing knowledge title

Capture only novel/actionable knowledge that is likely useful in future work as
an inline candidate block. Unique entries are promoted into `.keel/knowledge/<id>.md`
on submit/accept.

If there is no reusable insight for this story, leave the Knowledge section empty.
Format:
### VGjEBvkBu: Title
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

The important move here was to bind the acknowledgement and error contract to
the existing upstream types instead of inventing a new prose-only abstraction.
Publishing the literal `RemoteAcknowledged<T>` and `RemoteErrorResponse`
shapes keeps downstream replacement work anchored to one canonical boundary.

The main constraint was keeping runtime claims precise. The contract can name
all durability labels, but the current server runtime still only proves
`single_node` topology and `local` durability in the shipped path, so the docs
had to state those limits explicitly rather than implying broader deployed
coverage.
