---
created_at: 2026-04-29T18:01:20
---

# Reflection - Implement SqlMaterializer Using DataFusion And Prolly Trees

## Knowledge

<!--
Link existing knowledge files when the insight already exists:
- [123abcDEF](../../knowledge/123abcDEF.md) Existing knowledge title

Capture only novel/actionable knowledge that is likely useful in future work as
an inline candidate block. Unique entries are promoted into `.keel/knowledge/<id>.md`
on submit/accept.

If there is no reusable insight for this story, leave the Knowledge section empty.
Format:
### VIEQVSnEP: Title
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

The reducer boundary is synchronous while Prolly storage and DataFusion querying
are asynchronous. Keeping the reducer state to table root digests and running
the Prolly update on a dedicated short-lived Tokio runtime lets the reducer
implement the existing trait without changing the materialization engine. The
query path stays asynchronous through `SessionContext`, which is the right
surface for proof and CLI work.
