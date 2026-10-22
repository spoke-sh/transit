# 6. Branches, merges and restore

[Roadmap](README.md) · [Issue #31](https://github.com/spoke-sh/transit/issues/31)

Add isolated application-state experimentation after
[historical catalog binding](03-standards-and-catalogs.md). The
[state model](../handbook/internals/state-model.md) owns the authority/lifetime proposal.
Branches do not copy live process identities, grants or effect rights.

## Delivery sequence

1. Publish full-data and schema-only branches using bounded independent copies as
   the correctness oracle. Assign distinct identities/grants; define conditional
   head publication and source expiry races.
2. Add resource-local copy-on-write for eligible immutable pages with durable,
   bounded ownership, ancestry, roots and collection. Parent/child deletion and
   restart must preserve every reachable byte.
3. Implement paged typed diffs and reviewed three-way KV/Table merges. Freeze
   base/source/target, align schemas, validate complete constraints and reject
   stale heads. Schema-only promotion preserves rows unless explicitly migrated.
4. Extend merge to compatible Documents and qualified graph mappings. Preserve
   causal/tombstone semantics, fresh replica identities and valid endpoints;
   incompatible histories refuse and derived results rebuild or verify.
5. Restore as a new application-state successor. Define pending input, job and
   subscription disposition, explicit activation and external-outcome reconciliation.

## Completion evidence

Require copy/merge oracles, write/delete isolation, current export authority,
expiry, stale-head rejection, conflict resolution, lost-reply recovery and bounded
cleanup. Test data, branch and conflict counts beyond caches. Measure fork/merge
cost and shared/owned bytes before claiming cheap forks.

Never revive retirement, restore revoked rights or redispatch historical effects.
Cross-realm forks and live realm rollback require separate contracts.
