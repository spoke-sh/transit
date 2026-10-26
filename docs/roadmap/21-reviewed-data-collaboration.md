# 21. Versioned proposals and reviewed publication

[Roadmap](README.md) · **Status:** Planned

Let humans and agents compare alternatives on branches within one realm, share
their evidence and, where policy permits, publish an exact reviewed candidate.
Branching-only installations remain a complete useful profile: analysis and
sharing do not require merging.

## Prerequisites and scope

Use [branch and merge primitives](12-branches-merges-and-restore.md),
[actor/delegation policy](19-control-and-policy-plane.md) and
[published resources/investigation bases](20-published-resources-and-investigations.md).
Branching is the underlying data primitive. A higher-level project/application
fork relationship, independent export and cross-realm collaboration require
separate contracts and are excluded from this milestone.

## Delivery sequence

1. **Publish proposals as versioned resources.** Bind common base, exact source
   and destination versions, candidate digest, definition/data differences,
   typed conflicts, validations, business-impact computations, assumptions and
   evidence. Keep the proposal's own revisions distinct from branch heads and
   the authoritative destination. Reports, agents and Apps inspect the same
   candidate under current access.
2. **Implement explicit collaboration policies.** Qualify branching with merges
   disabled, human-approved publication and narrowly specified automatic
   publication as separate profiles. Creating a branch neither exports ownership
   nor copies grants. Destination protection also denies equivalent direct writes
   through SQL, native callers, SDKs or application commands.
3. **Bind approval to the reviewed intent.** Record authenticated approver,
   actor/delegation context, candidate, target expectation and policy conditions.
   Require current approval/publication authority, any selected stronger
   authentication and separation of duties. An App button or agent-authored
   claim of human approval supplies no independent proof. A changed candidate
   needs new approval; a changed destination requires replanning and review.
4. **Publish conditionally and preserve uncertainty.** Validate domain constraints
   even for disjoint edits, then publish against the expected destination head.
   Preserve original operation identity and exact outcomes across lost replies,
   withdrawal, duplicate submissions and replacement. A preview or approval is
   neither a reservation nor publication. Retain rejected and superseded
   proposals without rewriting their evidence. Reuse the
   [transaction decision/visibility contract](05-transactions-and-atomic-composition.md)
   for the selected merge domain; review approval does not establish serializability
   or a stronger cross-domain commit than the underlying operation supports.
5. **Separate publication from downstream effects.** Specify recomputation,
   backfill and notification behavior after merge or restore. External actions
   require independent authorization and recorded intent. Branches default to
   external effects disabled; captures are evidence, not permission to resend.
   Selecting historical application state never restores old security authority.
6. **Provide shared comparison and review operations.** Build bounded diff,
   evidence and impact operations usable without a browser. Qualify the proposal,
   approval and publication journeys through public callers here.
   [Board reimplementation](22-board-reimplementation.md) owns the complete
   browser comparison and review experience over these same operations. UI
   reviews belong in the registered Design sequence; Board inspection stays
   read-only and application review actions use separate authorized capabilities.

## Formal model follow-through

Own the [T6/A4/A6 reviewed-publication extensions](14-formal-semantics-and-correspondence.md#later-ownership-and-extensions)
after the proposal and approval contract settles. Model frozen candidate/target,
withdrawal, target movement, reviewer revocation and uncertain publication.
Connect selected checks to the real policy and publication owners, including
agent attempts to borrow human approval and equivalent direct-write bypasses.
Record explicit assumptions and deferrals. Local merge algebra alone proves
neither current approval authority nor external-effect eligibility.

## Completion evidence

Two agents create different proposals from one basis; a human compares their
reports and shares selected results. In the branching-only profile, every merge
and protected-destination bypass rejects. In the approval profile, the agent
cannot approve using its represented reviewer's powers. Move the destination,
change the candidate, revoke the reviewer and lose the publication reply at
independent boundaries; each outcome must preserve the original candidate and
operation identity.

Use an independent merge/domain oracle. Include non-overlapping edits that
jointly violate a business constraint, schema changes, Document conflicts where
supported, incomplete impact computations and cross-branch result confusion.
Verify that merging data never silently dispatches an external effect or copies
process progress, credentials or retired authority into executable work.
