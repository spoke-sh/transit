# Maintained Table relations

`RelationalMaintenance` maintains the selected int64 relational plan through
complete Table transaction history. It uses the same Fuze join, grouping and
ordered aggregate semantics as finite execution. The
[relational contract](../../../../contracts/RELATIONAL_V1.md#maintained-table-owner-operations)
owns exact records, authority, revision granularity and limits.

## Configure and activate

Build a `RelationalBundle` with lifetime `maintained`, exact Table declarations
and explicit resident, state, result, work and source-resource budgets. Publish
its immutable bytes under a query-request Publication. The coordinator is the
first Table's existing owner PID and resource. Provision native inspect/read
grants for the request and every source; register foreign resources with the
Station host. Associations do not supply these grants.

The authorized configuration handler installs `RelationalCapture.setPolicy` with
an `RQA1` mapping: calling peer, exact bundle fingerprint, request resource,
catalog principal, policy revision and allow flag. Every required catalog must
currently permit that principal to inspect/read. The host handles an authenticated
Station call by invoking `RelationalMaintenance.start` with the Publication
reference and a caller-owned workspace. Save pending native proposals before
sending them; settle their original receipts before preparing replacements.

Activation records the initial basis, retains the original request, and replies
with its original `RMH1` admission record. The call is settled independently of
later result publication. A
peer/correlation identifies one permanent admission; resubmitting different work
at that identity rejects. SQL parsing, plan publication and editing do not
activate it. This interface is a typed Zig owner operation; the existing generic
single-source SDK/Flight transports do not acquire this profile implicitly.

## Schedule bounded work

Route exact `RelationalMaintenanceRecords.Continuation` self-casts to `advance`.
Each call reconstructs its state from immutable publications and committed work
records. Accepted continuations stage bounded pages or advance a checkpoint.
The owner preserves canonical contributor/error order by recomputing each exact
basis through the finite executor. It then merges old/new results into paired
deltas. It does not currently reuse unaffected groups.

The workspace length plus `RelationalMaintenance.resident_base` must fit the
resident budget. The workspace holds decoded declarations, a bounded source
adapter and a bounded immutable-index candidate. Each executor step reads at
most one source row; every operation and active staging record stays bounded
independently of total history, groups or results. Retained logical state includes
older checkpoints, group nodes, outputs, deltas and manifests. It is cumulative
and subject to `spill_bytes`; physical provider quotas remain separate.

A completed revision becomes idle. An authenticated host calls `wake` to admit
the next eligible source transaction; a bounded host scheduler or explicit
operation supplies these wakeups. Coalesced notifications may prompt a wake but
do not supply transaction contents or prove catch-up. The owner does not run its
own background poller. A wake with no relevant Table-head change publishes
nothing. One transaction at a time advances the recorded vector, including
no-op transactions. Same-resource Tables advance together; separate resources
have a recorded processing order without a global consistency claim.

While backfill or a successor is staged, the previous complete revision remains
current. Later source transactions remain in Table history. Source rights are
freshly checked, and native resource-revision guards apply at acceptance. Heavy
concurrent writes can cause proposal conflicts; this does not relax authority
or justify skipping source transactions.

## Read and resume

`RelationalRevision.open` takes a public `ResourceReader`, frozen bundle, owner,
resource, peer/correlation, optional exact revision, mode, request budget,
cancellation flag and fresh snapshot nonce. Omitting the revision selects the
latest complete revision observed at opening. `result` mode reads full rows;
`delta` mode requires the exact previous manifest reference, absent only for the
first revision.

Each `next` returns an owned scalar row or paired delta. Retain a private consumer
candidate until terminal null proves complete coverage. Only then does
`checkpoint` return a resumable position. Save that position atomically with
installing the new consumer relation. An incomplete prefix must not replace the
last complete relation, even if the host disconnects after its final row.

`openNext` validates the saved version, shared definition, query identity and
bundle, then requests exactly the following revision. It replays an interrupted
transaction from the prior complete position. `MaintainedRevisionPending` means
that successor is not visible. `MaintainedResetRequired` rejects an incompatible
predecessor or retired query; explicitly acquire a complete snapshot or activate
a new query before resetting. It never substitutes the latest revision.

Newer publications do not invalidate an open older revision. Failure or
cancellation preserves its complete results. Every disclosure still rechecks
current query policy and native/catalog rights to every source, including empty
or noncontributing sources. Close the reader on success or failure to release its
lease. Closing a reader does not stop maintenance.

## Failure, cancellation and retirement

A semantic failure stops at its recorded successor and retains the original
cause and checkpoint witness. The previous complete result stays intact. Ordered
SUM overflow cannot be healed by skipping to a later basis. History gaps and
schema incompatibility also stop advancement; rebuild requires an explicitly
activated new query identity. Infrastructure failures without a declared domain
classification remain failed attempts.

The authenticated handler invokes `close` for cancellation, classified failure
or retirement. Closure reads only the query's own resource. A native read error
poisons its proposal; first settle pending work, then prepare a fresh proposal
without denied foreign read dependencies. Cancellation/failure retains the exact
request dependency needed by earlier complete revisions. Retirement makes those
revisions unavailable and releases that request version. Query-page physical
collection is not exposed by this owner; retirement does not delete accepted
Table history.

The [proof ledger](../../../../tests/README.md) distinguishes reference-store
checks from executed native/disk recovery evidence. These operations do not grant
automatic placement, distributed write authority or external-effect delivery.
