# Working on UI/UX design

Follow the [shared documentation instructions](../AGENTS.md). This directory owns
interface structure, interaction, workflows and visual styling. System architecture
belongs with its public topic; delivery scope and qualification belong in the
[roadmap](../roadmap/README.md).

## Start or extend a review

1. Read the [design index](README.md), the item's README and its latest review.
   Check the affected public interface and contracts before proposing behavior.
2. For a new item, create `docs/design/<item>/`, register it in the index and
   start with `D1.md`. Use the [review template](TEMPLATE.md).
3. Keep one linear `D<number>.md` sequence per item. Add a review for a new design
   question; clarify the existing review when the question has not changed.
4. Keep the item's single summary table, status, current-review link and real
   previous/next links synchronized. Preserve existing review and figure IDs.

## Make the decision reviewable

State the question, recommendation, alternatives, assumptions and evidence.
Apply the [scientific standard](../handbook/internals/standard.md) at the depth
appropriate to the review; distinguish observations from judgment and proposals.

Use black-and-white wireframes for structure and interaction. Introduce color
only for an explicit visual-styling review. Keep meaning in labels, geometry and
line styles. Give figures stable labels, alt text, captions and observations;
keep assets and supporting prompts/fixtures inside the item's directory.
Link figures from the index instead of copying a gallery there.

Map objects and actions to the shared public operations and typed contracts.
Distinguish definitions, proposed edits and observed state. Label executable,
grammar-only and missing behavior; a mockup must not imply new authority,
automatic effects or a delivered runtime capability.

## Record outcomes

Use the [defined review statuses](README.md#review-statuses). Record acceptance
only when reviewer feedback selects a direction, including which parts remain
open. Keep implementation and evidence status separate from review acceptance.

Preserve prior outcomes and source links when a later review changes direction.
Qualify cross-item references with the item and review number, such as
`board-console D4`. Promote delivered behavior into its public documentation;
keep implementation work and remaining acceptance gates in the roadmap.

Before finishing, check the item/index links, sequence, figure references and
asset paths, and run the shared documentation link check. Visual studies remain
repository records outside the handbook catalog and search.
