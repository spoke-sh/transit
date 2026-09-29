# UI/UX design items

This directory is for UI/UX design reviews: visual structure, interaction,
workflows and styling. Document system architecture in its owning topic documents
and implementation scope, decisions and qualification in the [roadmap milestones](../roadmap/README.md).

Each UI/UX design item has its own directory and one linear, D-numbered review
sequence. Its README owns the single review summary table, current review
and links to supporting material.

| Design item | Focus |
| --- | --- |
| [board-atlas](board-atlas/README.md) | Board browser, relief atlas and resource workspace |
| [board-console](board-console/README.md) | Declarative Board interface, monochrome structure, Workspace objects and exploration, operator authentication/secrets/trust and SQL mapping |
| [board-grammar](board-grammar/README.md) | Reactive Board composition, SQL-to-visual grammar, monochrome theme dimensions and application migration experience |
| [transit-cli](transit-cli/README.md) | Terminal errors, command help, a unified query console and conventional configuration |

## Maintaining the sequence

For a new UI/UX design item, create a named directory here, add its README and
register it in the table above. Start its review sequence at `D1.md`.

Use one `D<number>.md` file per review inside that item’s directory. Append
the next number within the item when a new design question or iteration needs
review. Keep existing IDs stable; do not create parallel files named after
follow-ups, alternatives or revisions. Clarifications and corrections to the
same review stay in its numbered file. Qualify references outside the item
with its name, for example **board-atlas D2**.

Keep the item’s review table, current-review link and previous/next navigation
in sync. Record acceptance only when a reviewer has selected that direction,
and state exactly what was accepted. Preserve earlier proposals and their
limits when a later review extends or supersedes them; link both outcomes.

The item’s README is the single summary of its sequence. Owning product
documents and PR descriptions link there for navigation and to numbered
reviews for details. Do not embed a review’s gallery in an index or maintain
another competing review table.

## Review document structure

Start from the [review template](TEMPLATE.md). Each review uses these sections
in this order; add topic-specific detail between the visuals and outcome when
needed.

| Section | Content |
| --- | --- |
| Title and navigation | Stable D number within the item, topic, item review index and real previous/next links |
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
Figure 1–13 labels in Board atlas so prior feedback remains meaningful; refer
to a visual as **board-atlas D2, Figure 7** outside that item. New reviews can
number their own figures, since the design item and review ID supply context.

Keep images, prompts, fixtures and technical appendices inside their design
item’s directory and link them from their owning reviews. Supporting material
does not introduce another review sequence.

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
