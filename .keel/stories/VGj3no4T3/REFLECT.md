---
created_at: 2026-04-13T19:34:41
---

# Reflection - Define Downstream Direct Cutover Proof Path

## Knowledge

<!--
Link existing knowledge files when the insight already exists:
- [123abcDEF](../../knowledge/123abcDEF.md) Existing knowledge title

Capture only novel/actionable knowledge that is likely useful in future work as
an inline candidate block. Unique entries are promoted into `.keel/knowledge/<id>.md`
on submit/accept.

If there is no reusable insight for this story, leave the Knowledge section empty.
Format:
### VGjFbKkKc: Title
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

The key move here was to bind the cutover story to live proof entrypoints
instead of prose alone. Using `transit proof hosted-authority` and the Rust
client example made the cutover path citeable without asking downstream repos
to reverse-engineer source files or stale CLI namespaces.

The only surprise was command drift from earlier source references. The current
CLI exposes these flows under `proof`, not the older `mission` namespace, so
the authored guide had to follow the live operator surface rather than the
historical wording.
