---
created_at: 2026-04-30T10:28:49
---

# Reflection - Materialize Json Payloads For SQL

## Knowledge

<!--
Link existing knowledge files when the insight already exists:
- [123abcDEF](../../knowledge/123abcDEF.md) Existing knowledge title

Capture only novel/actionable knowledge that is likely useful in future work as
an inline candidate block. Unique entries are promoted into `.keel/knowledge/<id>.md`
on submit/accept.

If there is no reusable insight for this story, leave the Knowledge section empty.
Format:
### VIIR6xAjc: Title
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

Hosted SQL needed a different default table shape than the Prolly key/value
adapter: the CLI now keeps the Prolly root as a replay-bound materialization
artifact, but registers an Arrow-backed event table for SQL so payload fields
are directly queryable.

DataFusion already provides the ordered aggregate needed for current-state
queries as `last_value(expr ORDER BY key)`. The CLI keeps the operator-facing
Transit shorthand `LAST(expr)` by rewriting it to order by `_offset` for hosted
stream tables.
