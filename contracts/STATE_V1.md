# State resources v1

Status: M7 public contract defined; authority, service, client, and inspection
implementation is in progress. Until the state route is implemented, exported
types are not a capability advertisement. [STATE.md](../docs/STATE.md) owns the
design; [M7](../docs/roadmap/M7.md) owns completion and qualification.

## Compatibility and authority

The profile extends the experimental v2 realm with a `state` command family and
domain-separated state reads. Existing command encodings, signatures, inline
process state, and inspection v1 stay unchanged. Old authorities reject the new
command family. Once a realm contains state operations or a state checkpoint,
downgrading to an authority without this profile is unsupported.

The optional resource catalog is omitted from checkpoint encoding when absent,
preserving existing checkpoint hashes. New authorities must prove recovery of
old inline-only histories and checkpoints before release. No existing process
is silently converted to a state resource. Applications explicitly create and
associate resources; compatible workload upgrades retain those associations.

All operations use the existing realm journal and conditional append. A state
turn contains its bounded mutation batch and ordinary turn proposal in the same
record. Prepared copies are private until that append succeeds. There is no
separate resource-head write, durable upload/staging allocation, state database,
or multi-stream commit. Larger upload-backed resources require another profile.

## Bounds and storage

| Item | v1 bound |
| --- | --- |
| Resource identities | 8 per realm lifetime; retired identities are never reused |
| Live keys | 64 per resource |
| Key or association-name bytes | 1–32, opaque byte equality |
| Value bytes | 0–256, existing canonical lowercase-hex `Value` |
| Associations | 64 active records per realm |
| Active read views | 4 per realm |
| Read-view lifetime | At most 60 seconds, requiring trusted authority time |
| Mutations | At most 4 distinct keys in one resource per turn |
| Returned entries | At most 8 per page; no unbounded enumeration |

Current KV data is a bounded in-memory index rebuilt from the validated journal
or checkpoint. Historical view copies retain only explicitly opened bounded
snapshots. Resource cardinality refusal is backpressure, never eviction. A
checkpoint includes live data, active views, associations, grants, and retirement
evidence. Verify the maximum serialized checkpoint and record fit the existing
1 MiB and 8 KiB limits. The client can process a resource larger than its read
page; the authority does not claim a disk-sized, unbounded KV index in v1.

## Commands and rights

Commands are submitted through the existing signed `/v2/command` boundary as
`{"state": {"operation": ...}}`. They share the principal sequence and uncertain
receipt rules of all other commands. Exact fields/defaults are defined by
[the public Zig types](../packages/zig/transit-protocol/src/State.zig) and
[generated schema](transit-v2.schema.json).

| Operation | Meaning and authority |
| --- | --- |
| `create` | Administrator creates an empty initialized resource with one existing writer PID, PID or independent ownership, and effective lifetime/history policy |
| `grant` | Realm root assigns explicit resource permission bits to an existing principal; zero revokes them |
| `associate` | Administrator conditionally binds/removes a PID-local name against its association revision, checking the new recovery basis |
| `open` | Current executing owner captures an associated resource revision for the next input, under current resource read permission and a finite deadline |
| `close` | The view's current authorized caller or an administrator releases a view; housekeeping never requires application code |
| `turn` | Current executing owner commits ordinary turn progress/outputs plus one resource's mutations using declared view identities |
| `retire` | Administrator explicitly retires a resource when no live required association prevents it |
| `expire` | Administrator records opted-in deadline expiry and permanent retirement of dependent required PIDs |
| `reclaim` | Administrator clears retired data under opted-in history policy and safe dependency checks; identity/retirement evidence remains |

Resource permission bits are `inspect=1`, `read=2`, `write=4`; they are separate
from existing process permissions. Creation/association/lifecycle operations
require administrative rights; data mutation additionally requires current
execution ownership and resource write permission. Reads require resource
inspection plus value-read permission when returning data. A resource grant
does not grant process inspection or execution. The writer's ownership generation
is the write fence; lifetime ownership and association are not credentials.

Inspection permission explicitly discloses that resource's metadata, including
writer/owner IDs; it does not authorize reading those processes. Association
discovery requires both PID inspection and resource inspection. Do not return
hidden associations, counts, or target IDs to a PID-only reader. Replacing or
revoking a principal must not preserve unintended resource grants.

## Read bases and commits

`open` captures the exact resource revision and binds its view to principal,
PID, activation generation, next input, and process revision. The view deadline
fits resource availability and the caller's execution window. It cannot be
renewed implicitly. Other writers may advance shared state; a captured read is
an observation, not a latest-at-commit assertion.

A state turn lists its views and optionally chooses one as `write_view`. All
listed views must still be authorized, unexpired, and bound to this turn. The
writable resource must still have the captured revision and writer PID. Mutation
keys are distinct; null deletes, including an already missing key. A successful
mutation advances the resource revision to the committing journal position.
The resource revision fences stale writes and delete/recreate races. Clearing
a key from the current index does not discard the journal's deletion evidence.

Turn failure cannot publish mutations or outputs. Successful or recorded failed
turns release their views. Rejected proposals publish nothing. Ownership changes
fence old views; bounded background release cannot make an old view ID valid
again. An uncertain commit keeps exactly the same proposal and operation ID,
including its view references, until reconciliation; expired views do not undo
historical acceptance. No historical receipt grants new access.

## Reads and inspection

`POST /v2/state` takes a `SignedStateQuery`, signed as
`Ed25519(SHA256("rey.transit.state.v1\0" || canonical-query-json))`. Modes are
capability discovery, resource metadata, PID associations, current entries, and
entries from a caller-owned read view. Every page carries the observed authority
cut, policy revision, retained floor, and principal sequence.

Read-only observers can enumerate current entries without opening a durable
view. Continuations expire on any authority change, as in inspection v1; no
reader silently pins history. Exact-view reads use the captured snapshot but
still reauthorize each page. Current time is checked for finite resource/view
access. A final tail check fences concurrent grant changes before disclosure.
Missing keys return no entry; denial, unavailable time/storage, expired data,
stale views, and pagination conflicts have distinct protocol failures.

## Lifetime, compaction, and recovery

Unlimited resource lifetime and history are defaults. `deadline_ms` is a hard
availability deadline; pins cannot extend it. PID-owned resources survive worker
replacement and retire when the logical owner retires. Independent resources
keep their policy after writer retirement, with no automatic writer transfer.

Required associations constrain activation, new work, commits, and effect
authorization even before the background expiry record is appended. Expiry
permanently retires dependent PIDs and fences their work, while previously
authorized connector attempts retain their separate settlement contract. Optional
expiry returns a resource error. Administrative association changes cannot evade
an already expired recovery dependency. Temporary outages are never expiry.

`history_ms=null` pins history indefinitely. Zero permits explicit safe
checkpoint/trim; positive values declare a minimum history age. The initial
whole-realm trim is conservative: all process/resource policies must permit it,
queues must be quiescent, and the most recent relevant resource change must be
old enough. Cleanup may exceed its target; this does not promise rolling
per-resource segment deletion. Current values survive regardless of write age.

Snapshots preserve active read views and current data before trim. Reclaimed
historical read evidence yields explicit replay limits; recovery applies
committed mutations without rerunning handlers or external effects. The durable
history floor, resource revisions, principal retry floors, and retirement IDs
prevent old writes or snapshots from resurrecting deleted data. Ordinary v1
does not provide historical point queries beyond retained views/history.

The finite-admission profile must include resource retirement/view release in
its reserved control budget. Opening views, creating resources, changing grants,
and associations cannot consume that reserve. Quota pressure cannot expire
resources, drop live keys, or complete unfinished inputs.
