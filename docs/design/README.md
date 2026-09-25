# Design reviews

Design reviews form one numbered sequence, read from top to bottom. Each review
owns one question, its proposal, visual evidence and recorded outcome.

**Current review:** [D6 — Canvas emphasis and zoom](D6.md).
**Selected visual direction:** [D2, Figure 7 — Queue-count fabric](D2.md#figure-7-queue-counts-with-age-on-the-well-walls).

| Review | Focus | Status | Outcome or next decision |
| --- | --- | --- | --- |
| [D1](D1.md) | Board browser and relief atlas | Reviewed | Two coordinated views; D2 extends the initial inbox-only relief |
| [D2](D2.md) | Board inbox, outbox and age | Accepted in part | Figure 7 selected; age-driven depth remains an alternative |
| [D3](D3.md) | Board fabric at 100–100,000 processes | Reviewed | Scale visuals favored; grouping remains open; D4 extends scale and simplifies the UI |
| [D4](D4.md) | Board fabric at 1 million–1 billion processes | Reviewed | Visual direction endorsed; exact metrics and grouping remain open; D5 adds resources |
| [D5](D5.md) | Table, KV and Document resource cityscapes | Reviewed | Direction welcomed; mappings documented; exact metrics remain open; D6 explores the transition |
| [D6](D6.md) | Process/resource emphasis and semantic zoom | In review | Compare an explicit canvas switch with zoom; review the shared-location transition and flat resource detail |

Review status records the design discussion. All six reviews contain proposed
interfaces and synthetic imagery; none is an implemented UI or capacity claim.
Delivery scope and qualification belong in the [roadmap](../roadmap/README.md).
[Board](../BOARD.md) owns the product boundary and current inspection contracts.

## Maintaining the sequence

Use one `D<number>.md` file per review in this directory. Append the next number
when a new design question or iteration needs review. Keep existing IDs stable;
do not create parallel files named after follow-ups, alternatives or revisions.
Clarifications and corrections to the same review stay in its numbered file.

Keep this table, the current-review link and previous/next navigation in sync.
Record acceptance only when a reviewer has selected that direction, and state
exactly what was accepted. Preserve earlier proposals and their limits when a
later review extends or supersedes them; link both outcomes.

The index is the single summary of the sequence. Owning product documents and
PR descriptions link here for navigation and to numbered reviews for details.
Do not embed a review's gallery in the index or maintain another competing
review table.

## Review document structure

Start from the [review template](TEMPLATE.md). Each review uses these sections
in this order; add topic-specific detail between the visuals and outcome when
needed.

| Section | Content |
| --- | --- |
| Title and navigation | Stable D number, topic, index and real previous/next links |
| Status | Review state and a separate implementation/evidence statement |
| Question | The decision this review asks the reader to make |
| Proposal | A short recommendation and the prior direction it builds on |
| Visual studies | Images with captions, figure IDs and observations |
| Design details, when needed | Explanations that would overwhelm the proposal or captions |
| Review outcome | Recorded choices, their scope and links to later changes |
| Open questions | The remaining decisions to discuss |
| Evidence and limits | Synthetic data, unsupported behavior, contracts and milestone relationship |
| Supporting material | Exact prompts, fixtures, technical appendices and asset links |

A figure number identifies an image, not a review. Preserve the existing
Figure 1–13 labels so prior feedback remains meaningful; refer to a visual as
**D2, Figure 7**, for example. New reviews can number their own figures, since
the review ID supplies context.

Keep images, prompts, fixtures and technical appendices in a named supporting
directory and link them from their owning reviews. The
[Board materials](board-atlas/README.md) support D1–D6. Supporting directories
do not introduce another review sequence.

## Review statuses

| Status | Meaning |
| --- | --- |
| Draft | The proposal is being prepared |
| In review | A proposal is available and decisions remain open |
| Reviewed | Discussion is recorded; this does not imply full acceptance |
| Accepted in part | A specific part is selected; identify it and the remaining alternatives |
| Accepted | The stated design direction is selected within its recorded limits |
| Superseded | A later numbered review replaces the direction; link the replacement |

Acceptance does not establish implementation, authorization, performance or
milestone completion. Update the owning product document when a design choice
changes its intent, and scope implementation through the roadmap's
[sequencing rule](../roadmap/README.md#maintaining-the-sequence).
