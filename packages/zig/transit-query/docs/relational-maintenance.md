# Maintained Table relations

`RelationalMaintenance` maintains the selected int64 relational plan through
complete Table transaction history. It uses the same Fuze join, grouping and
ordered aggregate semantics as finite execution. The
[relational contract](../../../../contracts/RELATIONAL_V1.md#maintained-table-owner-operations)
owns exact records, authority, revision granularity and limits.

## Configure and activate

Build a `RelationalBundle` with lifetime `maintained`, exact Table declarations
and explicit resident, state, result, work and source-pin budgets. Use
`authorizeCapture` with explicit direct Table clients, executor principal,
operation identities and expected source frontiers. The maintained lifetime
selects history retention. Same-Table aliases repeat one capture; distinct Tables
use independent acquisitions even within one catalog. Publish the immutable
bundle under a query-request Publication.

The coordinator owns a native progress resource independently of its source
Tables. Provision native access to that resource and the request publication.
The original caller's scoped delegation supplies direct Table reads; the executor
does not acquire general Table privileges. Associations do not grant access.

The authorized configuration handler installs `RelationalCapture.setPolicy` with
an `RQA1` mapping: calling peer, exact bundle fingerprint, request resource,
catalog principal, policy revision and allow flag. Every required catalog must
currently permit that principal to inspect/read. The host handles an authenticated
Station call by invoking `RelationalMaintenance.start` with the Publication
reference, configured direct clients and a caller-owned workspace. Save pending native proposals before
sending them; settle their original receipts before preparing replacements.

Activation retains the original request and replies with its original `RMH1`
admission record. Later continuations commit each pin's acquisition eligibility,
recover its exact remote history lease and commit the complete initial basis. The call is settled independently of
later result publication. A
peer/correlation identifies one permanent admission; resubmitting different work
at that identity rejects. SQL parsing, plan publication and editing do not
activate it. This interface is a typed Zig owner operation; the existing generic
single-source SDK/Flight transports do not acquire this profile implicitly.

## Schedule bounded work

Route exact `RelationalMaintenanceRecords.Continuation` self-casts to `advance`,
passing the same direct routes and workspace. Each call reconstructs its state from immutable publications and committed work
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
own background poller. A wake captures a fixed upper bound for each Table and
persists bounded physical traversal separately from the selected result basis.
Empty pages advance this cursor across replacement; admission, cancellation and
flush records publish no result revision. One logical acceptance at a time
advances the recorded vector, including accepted no-ops. Same-Table aliases
advance together; distinct Tables retain independent cuts and a recorded
processing order. A wake with no logical acceptance publishes nothing.

While backfill or a successor is staged, the previous complete revision remains
current. Later source transactions remain in Table history. Source rights are
freshly checked through direct reads and native authorization guards at progress
publication. Concurrent policy changes can reject a proposal; this does not
relax authority or justify skipping source transactions.

## Read and resume

`RelationalRevision.open` takes a public `ResourceReader`, frozen bundle, owner,
resource, peer/correlation, optional exact revision, mode, request budget,
cancellation flag, fresh disclosure subject and snapshot nonce. Obtain the subject
with `ResultDisclosure.prepare(authorization_client, options.selection(bundle))`.
It binds the complete selection and the current caller credential/selected role;
the immutable execution bundle keeps its original subject and fingerprint.
The resource reader independently needs native access to query progress/results.
Source disclosure checks the exact retained authority references with the caller's
current rights; it does not reopen released Table leases or read catalog storage. This low-level reader is an explicitly privileged infrastructure
profile; the disclosure proof grants no raw-resource access.
Omitting the revision selects the
latest complete revision observed at opening. `result` mode reads full rows;
`delta` mode requires the exact previous manifest reference, absent only for the
first revision.

Each `next` returns an owned scalar row or paired delta. Retain a private consumer
candidate until terminal null proves complete coverage. Only then does
`checkpoint` return a resumable position. Save that position atomically with
installing the new consumer relation. An incomplete prefix must not replace the
last complete relation, even if the host disconnects after its final row.

`openNext` validates the saved version, shared definition, query identity and
bundle, then requests exactly the following revision. Prepare its fresh disclosure
subject from `position.nextOptions(requests, cancellation).selection(bundle)`.
It replays an interrupted
transaction from the prior complete position. `MaintainedRevisionPending` means
that successor is not visible. `MaintainedResetRequired` rejects an incompatible
predecessor or retired query; explicitly acquire a complete snapshot or activate
a new query before resetting. It never substitutes the latest revision.

Newer publications do not invalidate an open older revision. Failure or
cancellation preserves its complete results. Every disclosure still rechecks
current query policy and the reading caller's rights to every source, including
empty or noncontributing sources. Close the reader on success or failure to release its
lease. Closing a reader does not stop maintenance.

Before exhaustion, `freshness` compares this exact revision's source vector with
authorized current Table observations. A later logical row change makes the
entry stale even when its schema is unchanged. Physical bookkeeping and accepted
no-ops do not require a different result. Changed/retired interpretations are
reported separately; denied and unavailable reads propagate without a partial
vector. Observations of different Tables remain independent. This read neither
wakes maintenance nor advances its input or consumer checkpoint. Output and
delta coverage still require terminal `next`.

An authorized recovery caller can read an already complete revision after the
original caller loses permission or rotates its key. This does not authorize
another maintenance step: execution continues to use the accepted original
subject, and cannot acquire authority from the recovery reader.

## Failure, cancellation and retirement

A semantic failure stops at its recorded successor and retains the original
cause and checkpoint witness. The previous complete result stays intact. Ordered
SUM overflow cannot be healed by skipping to a later basis. History gaps and
schema incompatibility also stop advancement; rebuild requires an explicitly
activated new query identity. Infrastructure failures without a declared domain
classification remain failed attempts.
The direct service's `HistoryReclaimed` rejection records `TableHistoryGap`;
restoring the service or exact history does not resume that failed identity.
Transport unavailability does not create this terminal gap evidence.

The authenticated handler invokes `close` for cancellation, classified failure
or retirement. Closure reads only the query's own resource. A native read error
poisons its proposal; first settle pending work, then prepare a fresh proposal
without denied foreign read dependencies. Cancellation/failure retains the exact
request dependency needed by earlier complete revisions. Retirement makes those
revisions unavailable and releases that request version.

Terminal states also schedule bounded closure of their original direct history
leases. Inspect `cleanup_cursor` and the retained pin records separately from
result completion. A denied or unavailable closure stays pending. An authenticated
host can call `retryCleanup`; after credential rotation it can install an explicit
current original-caller closure grant with `authorizeCleanup`. This permission
cannot alter the original execution proof, selected sources or completed results.
Completed revisions remain readable under current rights after lease closure.
Query-page physical collection is not exposed by this owner.

The [proof ledger](../../../../tests/README.md) distinguishes reference-store
checks from executed native/disk recovery evidence. These operations do not grant
automatic placement, distributed write authority or external-effect delivery.
