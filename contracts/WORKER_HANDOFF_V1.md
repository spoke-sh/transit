# Manual worker handoff v1

`transit-client.WorkerHandoff` records physical replacement against one current
native authority using existing `suspend`, `resume` and `rotate_worker` operations.
It does not move write authority, restore backups or implement a provider controller.

The selected profile has one trusted manager, an unbound running PID, one
writer-owned application resource, a PID-scoped worker grant, no outstanding
finite turn permit and a distinct replacement public key. Other associated
resources are read dependencies. The manager verifies this profile and the
application/artifact binding before beginning. Provider-bound PIDs use their
runtime contract. Native permission, dependency, lifetime and retirement checks
remain mandatory; protocol validation does not prove honest host computation.

## Records and persistence

The manager saves `Record` as canonical JSON with all fields present, including
null fields, in declaration order. `definition` is the mandatory current native
definition. Missing/foreign definitions, unknown fields, noncanonical bytes and
records larger than 8,192 bytes reject. This bound covers the manager record,
not worker state cardinality. The host owns atomic replacement, private file
permissions, file/directory synchronization and rollback protection. An absent
record is a recovery error, never permission to initialize it again.

`plan` contains nonzero native-range `id`, `realm`, `pid`, `resource`, `worker`,
initial `generation`, finite `resume_before_ms`, expected/replacement 32-byte
public keys, exact expected permission mask, a 32-byte application binding and
distinct 32-byte old/new physical-instance identities. Generation must leave room
for three successors; permissions include inspect and execute. Private keys are
not stored. The application binding fixes code/configuration and, for a query
worker, its exact bound query/source vector; it grants no access rights.

Other fields are `phase`, nullable `checkpoint` and nullable `retired_instance`.
Phases are `planned`, `quiesced`, `checkpointed`, `fenced`, `restored`, `activated`,
`retired`. A checkpoint is mandatory from `checkpointed` onward. Retirement
evidence is present only at `retired` and names the original instance. Transitions
return new records; hosts persist them before advancing. Invalid transitions
preserve the old record.

Before a native mutation, separately save its exact signed request, handoff ID
and issuing phase. Retry those bytes through unknown outcomes and retain them
until the successor record is durable. Never replace an uncertain request with
a fresh sequence. Managers sharing a principal must serialize its sequence;
this profile supplies no distributed manager lock.

## Transition sequence

1. **Quiesce.** Submit `suspend` with the initial generation and recorded deadline.
   Record `quiesced` only after observing the same suspended PID at generation
   +1, exact deadline, no owner, no permit and no provider binding. The old worker
   need not cooperate. An outstanding finite permit rejects admission.
2. **Checkpoint.** Scan the complete application resource at one exact revision
   while its writer is suspended. Record the resource digest and native process
   revision, consumed/cancelled counts and observed admitted count. Do not run
   handlers, dispatch effects or copy a provider snapshot over authority state.
3. **Conditional fence.** Submit `resume` with the quiesced generation. It checks
   the deadline and current native dependencies and advances generation to +2,
   leaving ownership absent. An intervening manager transition rejects the
   condition. Record `fenced` only for a ready unowned PID with unchanged progress.
4. **Restore.** Recompute the complete resource digest and require equality with
   the checkpoint. Revalidate the exact application binding and all current
   dependencies under the scoped worker's grants, including optional query
   sources. This application-specific validation is a required trusted host
   operation. Restoration reads current native history; it never overwrites it.
5. **Activate.** Submit `rotate_worker` with generation +2, the expected scoped
   key/permissions and distinct replacement key. Observe generation +3,
   ownership and unchanged execution progress, then authenticate an identity
   query with the replacement key before recording `activated`. The old key
   cannot authenticate even with a newly learned generation. Source grants keep
   their existing epoch; rotation cannot restore revoked permissions.
6. **Retire.** After attributed shutdown/absence evidence, record the exact old
   instance as retired. Physical cleanup does not retire the logical PID or
   delete accepted work. New execution begins only after activation is durable
   and the intended replacement receives its credential/configuration.

Settle known pending worker requests before rotation. Authentication precedes
native duplicate lookup: an old-key request cannot recover a receipt afterward.
If the old worker is unreachable, quiescence fences unaccepted proposals and the
replacement recovers accepted state/progress from current authority. It does not
reconstruct or resubmit an unknown old proposal.

Mailbox admissions and output acknowledgements may continue while quiesced.
Restoration requires unchanged process revision and consumed/cancelled counts,
and an admitted count at least as large as the checkpoint observation. Native
history retains later admissions, destinations and deduplication. Operator roots,
exchange cursors, eligibility/acceptance records, pending notices and published
revisions remain in the hashed resource. Physical exchange epochs do not replace
native fencing or change previously eligible segments.

## Complete checkpoint digest

`State` contains resource ID, writer PID, resource revision, entry count, logical
key/value byte count and SHA-256 digest. `snapshot` uses native pages, constant
resident memory and an explicit maximum page count. No partial scan can yield a
checkpoint. The digest input is:

- UTF-8 `transit.worker-handoff.state.v1` and one zero byte;
- the current definition's 64 lowercase ASCII hexadecimal bytes;
- resource ID, writer PID, revision and entry count as little-endian uint64;
- each entry in strictly increasing key-byte order: revision, key length and
  value length as little-endian uint64, followed by exact key and value bytes.

Entry revisions cannot exceed the resource revision. Count must equal native
metadata. Bad ordering/cursors, missing entries, read failures and page-budget
exhaustion cannot complete. Logical bytes exclude encoding/provider amplification.
A budget failure retains state and permits an explicitly budgeted fresh scan of
the same still-valid quiesced basis.

## Failure behavior

`InvalidWorkerHandoff` rejects malformed records or phase misuse;
`InvalidWorkerCheckpoint` rejects incomplete/corrupt/incompatible restore
evidence; `WorkerHandoffConflict` rejects changed ownership, progress, resources
or grants. Native denial, expiry, unavailability and conditional conflicts retain
their original errors. None authorizes lifetime renewal, latest-state substitution,
automatic rollback or reset. Suspension expiry can permanently retire the PID.
Missing manager history requires operator recovery. The
[proof ledger](../docs/history/qualification/README.md) distinguishes pure checks, native fault
schedules, provider attribution and unsupported topologies.
