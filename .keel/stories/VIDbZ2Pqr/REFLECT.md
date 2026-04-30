---
created_at: 2026-04-29T18:11:08
---

# Reflection - Implement Transit SQL CLI Surface

## Knowledge

<!--
Link existing knowledge files when the insight already exists:
- [123abcDEF](../../knowledge/123abcDEF.md) Existing knowledge title

Capture only novel/actionable knowledge that is likely useful in future work as
an inline candidate block. Unique entries are promoted into `.keel/knowledge/<id>.md`
on submit/accept.

If there is no reusable insight for this story, leave the Knowledge section empty.
Format:
### VIESyUa0r: Title
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

The CLI surface is intentionally thin: it builds a local Prolly table, registers
it under `transit.public`, runs the user query through DataFusion, and prints the
DataFusion pretty-table output directly. Keeping optional `--row KEY=VALUE`
seeding on the command gives operators a quick local inspection path while the
materialization proof remains responsible for branch and replay semantics.
