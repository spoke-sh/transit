# Branch identity and publication contract v1

## Scope

[`Branch`](../packages/zig/transit-protocol/src/Branch.zig) defines immutable
branch/cut attribution, frozen merge and restore attempts, candidate validation
coverage and forward publication decisions. The `branch` group of the reflected
[data lifecycle schema](data-lifecycle-v1.schema.json) uses these public types.

These validators perform no I/O, authorization, retention, candidate computation
or publication. They do not enable writable branches, SQL commands, remote
transfer or transaction participation. The installed direct Table and transaction
profiles continue to require branch one. An alleged reference, validation result
or decision is not evidence that its owner accepted or verified it.

## Identities and retained interpretation

`Identity` contains the existing data `Scope` and a nonzero branch ID. IDs cannot
be reused after retirement. A name is separately resolved metadata, never identity.
`Reference` binds that identity, a nonzero branch-local version and the immutable
manifest byte length/SHA-256 commitment. Versions in different branches or WAL
partitions are not comparable scalar clocks. Zero commitments reject.

`Manifest` includes the exact current contract definition, identity, version,
kind, inclusion mode, catalog position, paged object-directory commitment,
retention owner and ancestry. `Directory.objects` is durable cardinality, not a
resident limit. Empty directories still have a nonempty authenticated encoding.
The closure contains application definitions/data and their dependencies, never
native grants, credentials, principal sequences, process retirement, accepted
operation receipts or executable effect-control evidence.

The owner must acquire an atomic catalog/data cut in a supported decision domain,
including accepted unflushed WAL rows, and durably retain every required root,
archive/tail, interpretation and artifact. The `retention_owner` is attribution,
not proof that a pin exists. Independently sampled roots cannot be presented as
one atomic snapshot. Missing dependencies or unsupported kinds require refusal;
they cannot be silently omitted from a full-data branch. Schema-only inclusion
omits data explicitly and cannot later be interpreted as deletion of source rows.

Ancestry has these rules:

| Kind | Required ancestry |
| --- | --- |
| `genesis` | Version one, no parents or restore reference |
| `fork` | Version one, parent from a different branch in the same scope |
| `commit` | Same-branch parent at exactly version minus one |
| `merge` | Same-branch immediate parent and a distinct source-branch parent |
| `restore` | Same-branch immediate parent and explicit `restored_from` reference |

All references use the same scope. A same-branch reference must precede the new
version; foreign-branch version numbers impose no ordering. The publishing owner
must verify parent existence, content and ancestry. Restore publishes a forward
successor and preserves the current authority and earlier accepted history.

`Head.generation` independently guards name, policy and retirement transitions as
well as data movement. `requireSame` compares the full head, including content and
generation. Matching a name or version alone does not establish an unchanged
destination. Retirement/name reuse cannot retarget retained readers or attempts.

## Frozen operations and candidate coverage

`Attempt` binds the exact current definition, original data operation, request
commitment, intent and explicit resident/staging/object/work limits. The request
commitment covers names, resolutions and options not embedded in the neutral
intent. Exact retry compares every field. Account/client-token deduplication
belongs to the existing database token owner; this contract adds no token journal.

Create names a distinct destination identity, exact source and inclusion mode.
Merge freezes base/source/expected target. Its owner must establish that the base
is an unambiguous ancestor of both heads; the descriptor cannot prove that fact.
Restore freezes the source and expected target. Drop freezes the complete head.
Source movement cannot silently expand accepted work. A stale target rejects;
replanning needs a new explicit attempt. No field grants read, write, merge,
restore, external activation or export rights.

`Validation` binds one attempt and immutable candidate to checked-object and
conflict counts plus a complete flag. Publication requires exactly the claimed
object coverage, a matching candidate and zero unresolved conflicts. A preview,
budget stop, transport EOF or failed dependency read cannot set complete. The
owner additionally validates complete membership, constraint/dependency closure,
schema conversion, current authorization and durable staged roots. Disjoint edits
can still violate uniqueness, checks, foreign keys or graph endpoints. Conflict
cells in a preview do not authorize unresolved ordinary Table mutations.

## Decisions and uncertainty

`Decision` binds the original attempt, accepted control-log position, nonzero
writer/policy epochs and outcome. Published creation starts version/generation
one. Merge/restore increments both the expected version and generation by one,
without wraparound. A drop result is valid only for a drop intent. Rejected and
cancelled results contain no manufactured successor.

The owner publishes the complete schema/data directory, head and recoverable
decision through one visibility boundary; participant finalization is not that
boundary. Current native policy is checked at admission, publication and each
protected disclosure, including receipts, conflicts and empty terminals. A stored
policy epoch does not authorize subsequent access. Publication must enforce
protected destinations across equivalent ordinary writes and restores too.

A missing response remains uncertain. Cancellation after acceptance cannot undo
the decision; retries recover the original attempt rather than recompiling it
against moved heads. Historical input leases, jobs and effects need explicit
owner-managed disposition; copying data cannot revive execution rights or dispatch
recorded effects. Cleanup requires complete retained reachability separately from
logical branch deletion or opt-in expiry.
