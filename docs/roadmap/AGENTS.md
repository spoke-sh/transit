# Working on the roadmap

Follow the [shared documentation instructions](../AGENTS.md). This directory owns
delivery scope, dependencies, acceptance criteria and milestone status. Read the
[roadmap index](README.md) and the affected milestone before editing; consult
other milestones only for relevant prerequisites or scope boundaries.

## Define executable outcomes

Start from the data, computation or policy an application needs to declare and
the outcome it must inspect. Identify the owning operation, dependencies,
authorization, lifecycle and observable failure/recovery behavior. Keep current
behavior, delivered slices and remaining work explicit.

Specify contract work before dependent adapters or runtime changes. Link the
owning public reference and exact contract instead of duplicating them. Scope
acceptance through real caller operations, including denied access, uncertain
outcomes, recovery, bounded work and incomplete results where applicable.
Distinguish component checks, end-to-end proofs and deployment requirements.

Keep system reasoning with its topic and UI/UX review in
[Design](../design/README.md). Plans can cite that rationale and define delivery
gates, but must not become the only explanation of a current interface.

## Maintain the sequence

Follow the [sequencing rule](README.md#maintaining-the-sequence). Keep one stable,
numbered, descriptively named Markdown file per milestone and one ordered index.
Use `Planned`, `In Progress` or `Completed` consistently in the milestone header
and index row.

Record prerequisites explicitly. When inserting, splitting or reordering work,
update the index, filenames, dependency references and inbound links together.
Split only independently reviewable outcomes with clear prerequisites. Preserve
delivered scope and prior evidence; moving unfinished work does not complete its
original milestone. Update linked trackers when the authorized work includes
changes to their scope or status.

## Close or reopen with evidence

Mark a milestone `Completed` only when its acceptance criteria are met. Link
executed results in the [proof ledger](../../tests/README.md), promote supported
behavior and limits to the handbook/reference or component owner, and update
the milestone and index status together. Keep completed milestone files.

If an unmet criterion is found, reopen the milestone as `In Progress`, retain
delivered work and prior evidence, and name the remaining work. Merged code,
parser support, planned checks and component test passes do not substitute for
the milestone's required lifecycle and recovery evidence.

Before finishing, check numbering, statuses, dependency links and the distinction
between completed and proposed work, then run the shared documentation link check.
Keep milestone IDs and delivery sequencing in planning/history; current usage
documentation describes capabilities without requiring this roadmap.
