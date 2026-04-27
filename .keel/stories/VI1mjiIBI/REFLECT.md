---
created_at: 2026-04-27T15:18:16
---

# Reflection - Define Blockchain-Style Finality And Fork Proof Contract

## Knowledge

<!--
Link existing knowledge files when the insight already exists:
- [123abcDEF](../../knowledge/123abcDEF.md) Existing knowledge title

Capture only novel/actionable knowledge that is likely useful in future work as
an inline candidate block. Unique entries are promoted into `.keel/knowledge/<id>.md`
on submit/accept.

If there is no reusable insight for this story, leave the Knowledge section empty.
Format:
### VI24P5lNi: Title
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

The finality contract fit cleanly as a public overlay on existing integrity and
lineage primitives. The key boundary was keeping blockchain-style terms as a
mapping over records, branches, checkpoints, manifests, and explicit artifacts,
while stating that consensus, validation, signing, and fork choice remain
application-owned. The website docs build also caught that the new reference
contract needed a sidebar entry, not only a root Markdown file.
