---
created_at: 2026-04-29T17:56:16
---

# Reflection - Add Unit Tests For DataFusion Querying On Prolly Trees

## Knowledge

<!--
Link existing knowledge files when the insight already exists:
- [123abcDEF](../../knowledge/123abcDEF.md) Existing knowledge title

Capture only novel/actionable knowledge that is likely useful in future work as
an inline candidate block. Unique entries are promoted into `.keel/knowledge/<id>.md`
on submit/accept.

If there is no reusable insight for this story, leave the Knowledge section empty.
Format:
### VIEPEWBBN: Title
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

The Prolly DataFusion adapter can be exercised through normal SQL planning by
registering a `ProllyTable` in a `SessionContext`, which gives stronger coverage
than direct `TableProvider` scans alone. The Arrow mapping proof is most useful
when it asserts both the declared `Binary` field types and the collected byte
values, since either side can regress independently.
