# Milestone 6 shared transaction reads implementation plan

[Milestone 6](06-streams-queues-and-durable-runtime.md) · **Status: Implemented; qualification in progress** · 2026-11-12

The next slice lets an application read its private Table and KV changes through
the same shared transaction API it uses to write and recover them. Station uses
that API for handler reads. Applications should not have to obtain a raw signed
client, construct private snapshot handles or reproduce schema and cursor
validation to read within a transaction.

Deliver this as **one implementation PR with four logical commits**, estimated
at **5–8 engineer-days of implementation and targeted checks, plus 2–3 days for
clean qualification and review fixes**. This is a planning range, not measured
velocity. It advances unit B of the [completion plan](streams-queues-runtime-completion.md#b-extract-the-shared-transaction-api-and-migrate-station-to-it)
and the [M9 transaction facet](09-client-foundation-and-language-apis.md#4-own-results-and-transactions-through-the-shared-context).
It does not complete either milestone or the remainder of unit B.

**Source basis:** merged [PR #451](https://github.com/spoke-sh/transit/pull/451),
`main` at `6291d54f7c9466c7f43eff168e130e84f9f306f3`. The current native
definition is `cca0376c55733fd553a43a187fee9e8c379ab1b14007009a06bfcab3a517fec2`.
The merge supplies implementation, not a combined qualification result; the
PR records unfinished validation separately from its completed checks.

## Implementation status

The shared read boundary is implemented in `DirectTransactionReader` and
`Transaction.Read`, exposed through `Context.readTransaction` and native
`Transaction.read`. Station's private KV/Table helpers consume it. The independent
transaction proof has its own executable and a transitive Station-import gate.
The [current caller guide](../../packages/zig/transit-data-client/docs/transaction-reads.md)
owns supported semantics; the design and acceptance matrix below retain the
reviewed scope. No wire or persisted definition changed.

Catalog and data-client package tests, runner ownership controls, the fast checks
and handbook check have executed successfully during implementation. Installed
transaction/Station schedules and committed clean lanes remain in progress; the
implementation alone does not establish their results. Final executed evidence
belongs in the transaction qualification account and PR.

## Delivered foundation and the remaining read boundary

| Owner | Implemented at this source | Work in this slice |
| --- | --- | --- |
| [DirectTransactionSession](../../packages/zig/transit-catalog/src/DirectTransactionSession.zig) | Shared statement sequencing, durable checkpoints, savepoints and bounded settlement | Share a guarded read binding and existing private reader operations without another transaction state machine |
| [Transaction](../../packages/zig/transit-data-client/src/Transaction.zig) and [Context](../../packages/zig/transit-data-client/src/Context.zig) | Owned transaction state, journal adapters and admitted writes/controls | Admit typed KV reads and owned Table reader operations; preserve per-call diagnostics and local ownership |
| [DirectTableReader](../../packages/zig/transit-catalog/src/DirectTableReader.zig) and [DirectKVClient](../../packages/zig/transit-catalog/src/DirectKVClient.zig) | Exact private workspace attribution, bounded Table traversal/point reads and owned decoded KV values | Compose these implementations through the data API, including typed primary-key encoding |
| [Station reader adapter](../../packages/zig/transit-station/src/transactional/Runner.zig) | Calls `privateClient`, performs KV reads, and builds Table lookup/pin/reader/key-encoding sequences | Keep actor binding checks and handler value conversion; move reusable read orchestration to the shared owner |
| [Ordinary transaction fixture](../../tests/catalog/tables/direct_state_transaction.zig) | Uses the shared lifecycle and local recovery journal, but still obtains a private native client for reads | Exercise the complete shared read/write/recovery journey without a Station dependency |

The database retains the selected objects, original common cut, private roots and
decision. A reader binds the original account/token, connection, object and
definition, workspace revision and complete `Transaction.ReadView`. Read
completion means complete coverage of that private observation. It never means
that provisional writes committed.

## Scope and dependency direction

The dependency direction remains application → shared data API → Catalog/database
owners, with Station above the same shared data API. No database package imports
Station, and no ordinary read requires an actor identity, handler or actor journal.

Include typed KV point reads, Table primary-key lookup and finite unfiltered
Table scans. Reuse the existing typed schema, row decoding, collation-aware key
encoding, page budgets and completion validation. Preserve missing values, logical
NULL and empty results distinctly. Both context callers and native embedding
hosts use one neutral read implementation; embedding hosts may supply their
existing signed client without exporting it through the ordinary facade.

Do not add general relational query execution, new projection/filter/range APIs,
Document participation, independent language bindings or a replacement SQL result
protocol. SQL and managed programs retain their existing readers and recovery
owners; only migrate a helper they already share if necessary for this slice.
Multi-statement batching, Queue claim payload release, common-path optimization
and durable calls/services remain subsequent slices.

## Contract decisions before implementation

The [private read contract](../../contracts/DIRECT_TABLE_V1.md#transaction-scoped-private-reads),
[KV read contract](../../contracts/DIRECT_TABLE_V1.md#direct-kv),
[caller semantics](../handbook/reference/callers.md) and
[context ownership](../../packages/zig/transit-data-client/docs/context.md)
remain authoritative. Extend the shared client guide with the following proposed
composition before implementing its adapters. API spellings below are illustrative.

| Proposed operation | Result and ownership |
| --- | --- |
| `Context.readTransactionKV` | One owned decoded value or absence, with the exact definition, public source frontier and private read evidence |
| `Context.openTransactionTable` | An owned reader bound to a selected object/definition and one active workspace revision; resolve names only through the frozen transaction catalog |
| Reader `readKey` | Typed primary-key cells encoded through the retained schema and collation; an owned row or absence, independent of scan progress |
| Reader `next` | One bounded owned batch with coverage/completion and the original read basis; no whole-result accumulation |
| Reader `deinit` | Joined local disposal only; no network call, decision, ACK or source-pin release |

### Read admission and revision changes

Hold the transaction's exclusive local call guard for the entire admitted read,
including response validation and copying. The current `privateClient` guard ends
when it returns a client value; the new facade must not allow another operation
on the same transaction to race that read locally. Different transactions retain
the context's existing concurrency rules.

Reader open obtains one verified active revision. Subsequent fetches use that
exact binding and the existing server checks; they do not inspect and silently
attach to a newer workspace. A successful statement or savepoint control can
invalidate the reader even when the original common cut is unchanged. Pending
statements/rollback, settlement and a remote revision change must refuse further
disclosure. The caller may explicitly open a new reader after resolving pending
work in an active transaction, but cannot splice its rows onto an earlier result.

Reads use data admission, including metadata, terminal checks and repeated
end-of-stream calls. They obey immediate refusal or the existing finite admission
wait. An idle reader holds no Catalog transport borrow or active-call permit.
Each operation validates the original context handle generation and full scope;
closing/reopening a slot cannot retarget a reader. Transaction inspection,
settlement and recovery retain their independent control reserve while readers
exist or context closure is in progress.

### Memory and disclosure

The reader owns its schema, immutable basis and cursor. It retains no borrowed
transport response or per-call scratch allocation. Returned rows, KV values and
batches own their data and survive the next fetch and local reader disposal.
Expose explicit destruction and the existing bounded row/byte limits; reuse
scratch between calls rather than adding a heap arena per row.

Context capacity bounds active I/O, not all application-retained results. Reader
construction uses an explicit caller allocator and bounded schema/buffer sizes;
the host bounds the number of idle readers and retained output batches through
its allocator/resource budget. Do not claim an aggregate process-memory or zero
steady-state-allocation guarantee from a per-reader bound. Broader managed
language handle accounting stays with M9.

Recheck current authority through the owning read operation before each API
disclosure, including metadata, absence, an empty terminal batch and repeated
completion. Avoid a cache-only terminal shortcut. Already returned copies are
values from an earlier observation, not continuing read permission or proof of
the current workspace. Preserve server policy-epoch checks after buffering.

### Failure, recovery and cleanup

A private Table snapshot handle is a descriptor over transaction-owned pins,
not an independently acquired durable pin. Its `release` does not release those
pins. Reader disposal must therefore be local even after revocation or revision
change. Only the existing transaction settlement/cleanup owner releases the
retained source pins; preserve `cleanup_complete` as a separate observation.

An invalid page, failed exchange or failed output allocation must not advance
the scan cursor or manufacture completion. Preserve the owning reader's exact
retry rules and error distinctions. Reject changed identity/basis; never restart
the scan automatically. A denied read does not erase saved transaction work or
establish abort. A cancelled local await does not roll back the transaction.

This slice adds no durable read cursor format. After caller loss, the existing
`TransactionRecovery` restores the original transaction and pending write/control
identities. The application may explicitly start a new read of the recovered
active workspace; it cannot call an earlier partial result complete or continue
it under a replacement cut. Database recovery remains independent of readers
and Station callbacks.

Keep the existing wire and persisted transaction/actor formats. If implementing
these semantics actually requires an incompatible format or ABI change, include
the current-v1 definition cutover and dependent fixture/consumer migration in the
same review unit, and revise the estimate before expanding scope.

## Implementation sequence and logical commits

1. **Shared read operations and contract.** Add neutral read binding/orchestration
   alongside `DirectTransactionSession`, delegating to `DirectTableReader` and
   `DirectKVClient`. Share typed primary-key encoding rather than copying the
   Station implementation. Define the result/basis ownership and error behavior
   in the data-client guide. Add component checks for exact identity, stale
   revisions, pending work and allocation failure.
2. **Owned data-client facade.** Extend `Transaction`, `Catalog`, `Context` and
   package exports with KV reads and an owned Table reader. Use existing admission,
   diagnostics and generation checks; serialize the complete operation. Verify
   output lifetime, busy handling, close races, bounded pages and reserved control
   progress. Keep native host and context entry points on the same implementation.
3. **Consumer migration and installed proof.** Replace Station's KV/Table read
   orchestration with this API, retaining expected actor definition checks and
   handler encoding. Migrate the ordinary transaction fixture's private reads to
   the context facade. Add a separately built public Zig SDK caller or fixture
   target importing only `transit_data_client` and its public dependencies; the
   existing broad direct-table proof binary alone does not prove Station absence.
4. **Qualification and public documentation.** Run the matrix below on the final
   revision. Update the data-client README/context guide, Catalog/Station guides,
   caller/SDK reference and scoped qualification account with supported limits and
   executed evidence. Update this plan, unit B and the M6 index without marking the
   wider runtime replacement complete.

## Acceptance matrix

| Case | Required evidence |
| --- | --- |
| Ordinary application | Standalone public Zig caller builds without Station imports/artifacts; selects Table/KV, reads, writes, reads its writes and settles through the shared API |
| Attribution | Returned definition/common cut/workspace revision match; public readers see only committed state; mixed Stream/Queue transaction participation remains intact |
| Typed values | Composite/collated primary keys, variable-width values, KV absence versus NULL, zero rows and more than one Table page have exact independent expected values |
| Reader ownership | Returned data survives another fetch and reader/context disposal; forced allocation failures leak nothing and leave cursor/completion unchanged |
| Invalidation | Writes, savepoint create/release/rollback, pending controls and settlement invalidate old readers appropriately; a second authenticated caller advancing the same transaction cannot cause rebinding |
| Authorization | Revocation after open and after buffering denies the next disclosure, including missing keys, metadata and repeated/empty terminal reads; reader disposal still works locally |
| Recovery | Lost write/decision replies and caller/node replacement retain original identities; explicit reads of recovered active work succeed only at its actual revision; prior prefixes are never resumed implicitly |
| Context lifecycle | Stale/wrong-scope handles, simultaneous read/write, cancelled admission and close races refuse or join safely; data saturation leaves transaction control capacity available |
| Station integration | Existing 18 installed Station schedules and independent state/input/output oracles still pass; reader paths share the data API while actor execution and Queue lease checks remain separate |
| Bounds and cost | A streamed result exceeds the configured client memory budget in total size while bounded batches fit; discarded batches do not accumulate. Record request counts and allocation/high-water observations for repeated reads at fixed workload size |

Use the cost observations to identify wrapper overhead and the next optimization
target. They do not establish a Station latency budget or explain the earlier
[private comparison](../history/qualification/performance.md#private-transactional-station-comparison--2026-11-12).
Do not add extra durable read checkpoints or one transaction inspection per row.
Preserve the existing workload and budgets when comparing the old and new read
paths; report unavailable counters explicitly.

## Validation for the implementation PR

Run package unit/build checks for Catalog and the shared data client, the public
Zig SDK/package dependency checks and Station's affected tests. Extend existing
installed tasks rather than adding a second transaction test harness:

```sh
nix develop --command just test direct-state-transaction
nix develop --command just test direct-mixed-transaction
nix develop --command just test station-transaction
```

If a new standalone caller task is needed, register it in the owning build,
`tasks/test.just`, runner inventory and affected clean lane. Its name and exact
command become concrete with that commit; it is not an existing passing check.

Before pushing the implementation, run the baseline gates and affected clean
lanes against committed HEAD:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
nix develop --command just ci clean --lane core
nix develop --command just ci clean --lane storage-query
nix develop --command just ci clean --lane interfaces-sql
```

The SQL lane preserves dependent private-read/savepoint behavior. If SQL execution,
server/gateway/startup code changes, also run `server-sql-types` and the console
latency gate in the pinned `ci-experience` shell, with the latency measurement
outside heavy build/test activity. An incompatible public contract change also
requires `just check contracts` and its dependent checks. Follow the root
[required gates](../../AGENTS.md#required-checks-before-opening-or-updating-a-pr)
for the final changed-file scope. Record all outcomes; an incomplete lane or a
dependency install is not a pass. This planning change needs documentation checks,
not these future runtime suites.

## What follows this slice

The next unit B work is matched shared-path cost attribution, then bounded
statement batching and measured optimization in the common owners. Retain exact
pre-dispatch requests and completion evidence before coalescing journal or
inspection work. Queue claim payload-read closure requires its own recoverable
release identity and Station replay-dependency decision; it must not be confused
with the local private reader disposal here.

Authenticated calls/replies, timers/scheduling/supervision, effects, public
consumer migration, M7 Document integration, Table commit/latency work and final
population/collection qualification remain in the completion plan. This slice
does not re-estimate the whole milestone by subtracting one merged PR; the
existing 19–32 engineer-week direct-work range remains provisional until the
cost and consumer audits support a new estimate.
