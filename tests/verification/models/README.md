# Finite authority model

Run `just test::model`; use `just test::model --tail 5` for the larger exploration.
TLC comes from the repository's locked nixpkgs (TLA+ 1.7.4, TLC 2.19). It runs
with one worker, fixed fingerprint/seed, a 512 MiB heap and a 60-second limit per
configuration. Tool errors, timeout, missing queue completion or unmapped traces
are inconclusive failures, never proof success.

## Meaning and bounds

[Authority.tla](Authority.tla) models two preparation slots sharing one principal,
two ordered inputs, replaceable activation generations, current permission,
conditional journal publication, lost acknowledgements and exact receipt retry.
Logical time has three values: before work cutoff, settlement only, and closed
settlement time. Process retirement and connector attempt closure are distinct.
An authorized external attempt may still run remotely after local closure.

Validation happens during preparation. Advancing time alone does not cancel a
prepared append; a competing durable closure invalidates its compared tail.
This matches Transit's validation-at-tail contract rather than promising an
atomic wall-clock check in Ursula. The effect submodel checks authorized result
acceptance and terminal closure; it omits transport and remote-system behavior.

The normal configuration bounds journal-changing actions at three. It exhausts
7,867 distinct states; four permits 30,140. These counts include observations and
preparation changes that do not advance the journal. Deadlock checking is disabled
because reaching the exploration bound is an intentional terminal condition.
No liveness theorem is claimed. Progress would require explicit fairness,
available storage/control capacity and connector assumptions.

## Negative controls and implementation correspondence

[model.py](model.py) also removes the tail, generation, permission and closure
guard independently. Every variant must produce an invariant violation, not a
parser/build error. The pinned TLC emits text counterexamples; the runner
extracts the explicit `last` action from each state, converts scheduler-slot
actions into the concrete trace format, and runs those schedules against the real
Zig engine. The normal implementation must reject the bad path and agree with
the independent state projection. Trace translation fails on unknown actions.

The bridge currently covers those four authority counterexamples. It does not
claim a refinement proof, conformance for every effect/time path, view expiry,
authenticated network traffic, WAL durability, checkpoints, paged materialization,
host-language ownership or arbitrary cluster size. Those remain separately owned
proofs in the [inventory](../invariants.json). State hashes have TLC's documented
collision limits. See the [TLC documentation](https://docs.tlapl.us/using:tlc:start)
for model-checking scope and [the pinned release](https://github.com/tlaplus/tlaplus/releases/tag/v1.7.4).

Logs, completion evidence and concrete counterexamples are retained under
`.cache/verification/model/`. The ordinary formal lane runs the small model;
weekly discovery expands it and runs targeted mutations of the actual Zig guards.

## Finite object publication model

Run `nix develop -c just test::object-publication-model` for
[ObjectPublication.tla](ObjectPublication.tla). The question is whether payload
and checksum names, including a bounded group of objects, can share a directory
barrier before descriptor publication. The runner exhausts one-key and two-key
profiles, one candidate and exact retries under ordered per-key locks. Three
files per key have absent/partial/complete bytes, with independent
visible/durable bytes and names. The initial state has no candidate artifacts;
an older conditional descriptor is abstracted as absence of the new descriptor.
The transition sequence writes/syncs/links all content files, syncs their shared
directory, then writes/syncs/replaces each descriptor, syncs their directory and
acknowledges. Independent writeback, process death, power loss, I/O errors and
recovery can interleave. Exact retries repeat the required barriers; a visible
name alone supplies no durability evidence.

The invariants require durable content before new-descriptor visibility, a
synced descriptor before replacement, and all dependencies durable on success.
Five controls per profile independently remove those synchronization obligations and must
produce their named invariant violation. The runner requires queue exhaustion
for the safe model and complete known-action traces for controls; syntax errors,
timeouts or missing evidence fail. Source hashes, tool banner, configurations,
logs and traces are written to `.cache/verification/object-publication-model/`.
The pinned TLC uses one worker, fixed seed/fingerprint, 512 MiB and 120 seconds
per configuration.

Successful sync and atomic descriptor replacement are assumptions. This is
safety exploration without fairness or a liveness claim. It abstracts bytes and
hash verification, excludes concurrent reclamation and does not establish
inventory-before-creation, WAL acceptance, arbitrary batch sizes or gateway
recovery. The independent real-disk error/process schedules exercise production
ordering; they do not automatically replay model traces, prove refinement or
simulate power loss. The composition and delivery obligations remain in
[#211](https://github.com/spoke-sh/transit/issues/211) and the
[gateway plan](../../../docs/roadmap/08-gateway-architecture-and-protocol-ingress.md).

## Finite console interaction model

Run `nix develop --command just test::console-model`. The ordinary formal lane
owns this check, using the same pinned TLC as the authority model. Each TLC run
has one worker, fingerprint/seed `0`/`1`, a 512 MiB heap and a 60-second timeout.
The [specification](Console.tla) and [configuration](Console.cfg) model the
production [editor owner](../../../apps/transit-cli/EditorState.zig).

The model separates editing/history/completion from idle/fetching/validating/
obsolete/cancelling/executing client ownership. It represents three draft text
classes (empty, draft, history match), four filter classes, start/end cursor
positions, and one request. Ready complete uniqueness and equality of the
validated metadata basis are abstract inputs. Native units exercise their actual
field comparisons; the model does not implement a second SQL grammar.

Safety invariants require restored draft/cursor on history cancellation, inert
stale or interrupted successful replies, complete uniqueness for automatic
insertion, matching validation evidence, exclusive client ownership, explicit
submission, and cleared private projections after protected failure. Logical
request obsolescence is independent of the wrapping draft generation counter.
The counter itself is outside the finite model.

The [runner](console_model.py) checks all reachable states, exports the complete
TLC graph and rejects incomplete state/edge counts. It finds a shortest path to
every state and replays every outgoing edge against the actual Zig reducer via
[the private trace adapter](console_state.zig). It compares projected text,
cursors, filter, history match/failure, modes and emitted effects. Unknown fields,
actions and incomplete replay fail. The adapter supplies synthetic edits and
history results; it neither interprets the requested I/O effects nor executes SQL.

Six independent model variants remove freshness/interruption, uniqueness,
metadata equality, draft restoration, ownership and protected-failure guards.
Each must produce its named invariant violation and an explicit counterexample;
parser errors and timeouts are inconclusive failures. The concrete reducer must
follow the safe graph for that schedule and differ from the violating model
state. These are mutations of the model, not mutations of production Zig.

A separate `FairSpec` run checks eventual borrower release under weak fairness
of request failure/timeout, cancellation join and foreground completion. This is
an environment assumption: indefinitely stalled network cancellation or foreground
execution is outside that progress result. It establishes no wall-clock bound.

The graph check and edge replay do not prove all Zig histories, arbitrary text,
undo journals, allocation/arena lifetimes, terminal decoding/rendering, network
behavior or a refinement theorem. The
[terminal suite](../../interfaces/cli/console_editing.py) covers the actual effect interpreter
and display. The [mechanism account](../../../docs/handbook/internals/service-interfaces.md#console-interaction-transitions)
explains ownership and integration assumptions. Executed counts and commands
belong to the [proof ledger](../../../docs/history/qualification/README.md).

Logs, the graph, removed-guard traces, source/binary hashes and completion status
are retained under `.cache/verification/console-model/`. `--seconds N` changes
the per-process timeout; exhausting it never counts as a pass. There is no depth
cutoff: the stated finite abstraction must be exhausted.

## Finite local WAL model

Run `nix develop --command just test::wal-model`; `--lsns 3` expands the LSN bound
and `--seconds N` changes the per-configuration timeout. The ordinary formal
lane owns this check. [Wal.tla](Wal.tla) and [Wal.cfg](Wal.cfg) use the same locked
TLC as the other models: one worker, fingerprint/seed `0`/`1`, 512 MiB heap and a
60-second default timeout. Completion requires an exhausted queue; timeout,
parser/tool errors and missing counterexample states are inconclusive failures.

The model starts with a compatible initialized directory and partition metadata.
It includes one exclusive serialized owner, one partition, two LSNs, two writer
epochs and two independent policy epochs. Each segment contains one frame. A
frame's finite value encodes its epochs; LSN identity is its position. Empty,
torn and complete frames abstract bytes, payload checksums and codec validation.
Definitions, payload equality, directory enumeration, caches, OS locks and caller
expected-LSN conflicts remain implementation tests, not properties of this model.

Visible contents and names differ from their durable images. Metadata replacement
is atomic and its temporary file must be synced before rename; successful file
and directory syncs truthfully establish durability. Background persistence can
retain unsynced data, individual names or metadata independently. Process death
keeps the visible image; power loss restores only the durable image. This is a
filesystem assumption, not an experiment on storage hardware. The model includes
partial writes, uncertain I/O failure, reopening, tail repair and complete
unacknowledged frames. Recovery barriers precede a usable owner. Crashes can
repeat without a depth or operation-count cutoff within the finite LSN bound.

Safety invariants require:

- acknowledged frame identities and every published retained frontier to have
  durable supporting frames and names;
- append admission to honor both cached epochs, and acknowledged fences to survive;
- acknowledged floors and successor LSNs to survive, including after full trim;
- deletion to follow a durable authorized floor, and completed trim to have no
  removable prefix left;
- every usable recovered frontier to expose contiguous complete retained frames.

The trim caller supplies authority; checkpoint, receipt, pin and logical-history
coverage are outside the model. No eventual recovery or trim completion is
claimed under indefinitely repeated faults. Deadlock checking is disabled at
intentional finite terminal states; there is no liveness theorem or fairness
assumption. Fail-closed rejected recovery is not evidence of availability.

[wal_model.py](wal_model.py) removes six obligations independently: append
file sync, epoch admission, trim-floor publication, equal-floor cleanup retry,
recovered-frame sync and recovered-directory sync. Each must violate its named
invariant and yield a complete explicit action trace. These are model mutations,
not production Zig mutations. Source hashes, configurations, logs, counterexamples
and completion evidence live under `.cache/verification/wal-model/`.

The correspondence is reviewed at operation boundaries in
[DiskWal](../../../packages/zig/transit-storage/src/DiskWal.zig): `append`, `fence`,
`trim`, `recover` and the final `open` barrier. `MetaWrite`/`MetaSync`/`Rename`/
`MetaDirSync` describe `atomic`; `Delete`/`DeleteSync` describe prefix removal.
Independent [disk regressions](../../../packages/zig/transit-storage/src/disk_wal_test.zig)
check failures at the recovered-frame and observed-directory barriers, and
[process-death schedules](../../storage/local/local_storage_faults.py) cover interrupted trim.
These tests are not automatic replay of every TLC transition or a refinement
proof. The model does not cover object descriptors, multiple owners, replication,
retention policy, arbitrary corruption or arbitrary-size executions. Executed
results belong to the [proof ledger](../../../docs/history/qualification/README.md).

## Finite transaction decision model

Run `nix develop --command just test::transaction-decision-model`. The ordinary
formal lane owns this check and retains its evidence directory. The locked TLC
uses one worker, seed `1`, fingerprint `0`, a 512 MiB heap and a 60-second limit
per configuration. `--seconds N` changes that limit; every safe run must exhaust
its queue, and every negative control must report its named invariant and a
complete recognized action trace. Timeouts and malformed/tool output fail.

[TransactionDecision.tla](TransactionDecision.tla) asks whether one original
attempt can retain one truthful decision through preparation, authority changes,
coordinator replacement and lost replies. It starts unfrozen, with no prepared
participants or decision, an authorized first-epoch coordinator and unknown
caller knowledge. Its finite domains contain two written participants, two
epochs, commit/abort outcomes and Boolean availability, conflict and permission.
Preparation is monotone. Recovery adopts the current epoch without changing the
original attempt or decision. Losing a reply changes knowledge only.

Invariants require freezing before a decision, complete preparation before
commit, one immutable original decision, current publication/disclosure authority,
fenced publication and truthful terminal observations. Six independent controls
remove freezing, preparation completeness, epoch fencing, publication authority,
decision stability and disclosure checks. Each must produce its named invariant
violation. No fairness or liveness assumption is made. Repeated failures,
revocation and unavailable participants may prevent progress indefinitely.

The journal's operation boundaries provide a reviewed correspondence and
automated negative-control replay through
[transaction_decision_state.zig](transaction_decision_state.zig):
`TransactionDecisionLog.freeze` checks the frozen binding and participant
directory; `commit` verifies complete membership and calls current owner checks
under the supplied guard; `append` uses the conditional, epoch-fenced log;
terminal `commit`/`abort` retries return the original decision; `observe` checks
current authority; `recover` reconstructs history without dispatch. All six
negative-control counterexample traces are replayed against the real Zig
`TransactionDecisionLog` and must be rejected or preserve the safe projection.
The [component tests](../../../packages/zig/transit-storage/src/transaction_decision_test.zig)
further exercise these operations with disk reopen, lost replies, pre/post-append failure,
stale epochs, missing preparations and denied callbacks.

Atomic conditional append and truthful verification while all participant/name/
policy guards remain held are model assumptions. The model abstracts identities,
payloads, descriptor integrity and memory. It establishes no consistent-cut
acquisition, Table predecessor barrier, common Table visibility, serializability,
SQL transaction, retention integration, distributed decision or filesystem proof.
The [integration contract](../../../packages/zig/transit-storage/docs/transaction-decisions.md)
states the missing production owners. Source/configuration hashes, revision/dirty
state, exact commands, TLC logs, completion counts and counterexamples remain
under `.cache/verification/transaction-decision-model/` and CI artifacts.

## Finite local Table transaction model

Run `nix develop --command just test::table-transaction-model`. The formal lane
runs [TableTransaction.tla](TableTransaction.tla) through five finite programs:
write skew, a two-Table write with a read-only observer, savepoint rollback,
read-your-writes and competing two-Table preparations. Each configuration has two
original transactions and two Tables; it exhausts every enabled interleaving of
the selected programs, rather than sampling a particular transaction schedule.
Each Table holds a symbolic value identifying its last committed writer. That
identity also represents its logical change version; this finite abstraction
does not model arbitrary payloads or version reuse.

Initially both Tables contain zero, no transaction has begun, and no participant
barrier or decision exists. Begin takes a publication-excluding acquisition fence;
individual pin steps capture data and definition versions. A crash can drop the
fence between any pin steps. Resume must revalidate all already-pinned sources
before continuing. Acquisition completion checks the resulting pair against an
independent history of actual data/definition cuts. A changed partial acquisition
can be aborted; this model does not silently replace its original pins.

Statements read the retained cut with private writes overlaid. Savepoint rollback
restores private data while preserving read dependencies and statement sequence.
Freeze prevents further statements. Each written Table installs an exclusive
predecessor barrier. Commit validates whole-Table logical read/write versions and
definitions and changes one common decision; read-only transactions can finish
against older data. Finalization copies the committed successor into each physical
Table root independently. Effective reads resolve the common decision while
finalization is incomplete. Abort publishes no private data.

An independent serial-history predicate requires all committed external reads to
fit at least one of the two possible serial orders, including reads performed
before savepoint rollback. Other invariants check common-cut acquisition,
read-your-writes, retained dependencies, current definitions, exclusive barriers
and equality between effective Table visibility and the atomic publication oracle.
Seven independent negative controls remove one corresponding obligation. Each
must produce its named violation and a complete recognized action trace. The
acquisition control permits resuming stale partial pins; the resulting mixed cut
must fail even though each individual pin was valid when acquired.

The pinned TLC configuration uses one worker, seed `1`, fingerprint `0`, a
512 MiB heap and a 60-second budget per configuration. Terminal or blocked states
are allowed: there is no fairness or liveness claim. Timeout, parser errors and
incomplete exploration fail. Sources, exact configurations, command lines, logs,
state counts and counterexamples live under `.cache/verification/table-transaction-model/`
and are retained by CI. The [proof ledger](../../../docs/history/qualification/verification.md)
records executed revisions and results separately.

This is an algorithm model, not a production refinement. The separate decision
model owns fencing, authority, original outcome and lost-reply behavior; the Table
model assumes those journal obligations. Logical accepted state is durable between
steps, while the modeled crash only releases the acquisition fence. Objects,
retention, allocation, physical I/O, SQL evaluation, constraints, credentials,
arbitrary programs and arbitrary-size histories require separate checks. There is
no automatic production replay yet. The
[component integration contract](../../../packages/zig/transit-storage/docs/transaction-decisions.md)
identifies the runtime owners that must implement these transitions before
installed transaction support is claimed.

## Finite SQL result models

Run `nix develop --command just test::statement-result-model`. The ordinary
formal lane runs the default two-row bound. `--rows 3` or `--rows 4` expands
exploration; `--seconds N` changes the per-process timeout, not the state space.
The locked TLC uses one worker, seed `1`, fingerprint `0` and a 512 MiB heap.
Both models exhaust their reachable finite graphs without a depth cutoff. They
check safety only, with no fairness assumption or eventual-completion claim.

The question is whether a finite statement result can preserve its original
attribution, row occurrences and completion evidence while consumption, session
lifetime and disclosure permission change independently. The owning contracts
are [logical results](../../../contracts/SQL_RESULTS_V1.md) and
[native sessions](../../../contracts/SQL_SESSION_V1.md). The
[query-engine account](../../../docs/handbook/internals/query-engine.md#finite-result-transition-models)
explains the argument and exclusions; the
[qualification ledger](../../../docs/history/qualification/verification.md#sql-result-progress-and-session-models--2026-10-27)
records executed bounds and outcomes.

### Logical progress and implementation correspondence

[StatementResult.tla](StatementResult.tla) and
[StatementResult.cfg](StatementResult.cfg) start with an open, reading,
unreleased result and zero received/delivered counts. The original result,
schema and observation identities are fixed; three foreign classes change one
component each. Events receive or deliver rows, finish with a terminal count,
fail, cancel or release. Zero counts, foreign identities, incorrect counts and
operations after stopped consumption remain explicit rejected attempts. The
finite bound disables a receive that would exceed the explored cardinality; it
is not a modeled production quota or a truncation rule. Actual unsigned-64-bit
overflow remains covered by the result library's unit tests.

Invariants check received/delivered bounds and monotonicity, immutable
attribution, terminal-count agreement, verified evidence, full delivery on
exhaustion, stopped/released consumption and preservation of known completion.
Completion and consumption have separate states: a complete result may still
have undisplayed rows, and releasing it preserves that evidence. Releasing an
open result cannot establish completion. Failure after completion can stop
consumption without erasing the previously received terminal.

[statement_result_model.py](statement_result_model.py) exports the entire TLC
graph, checks its node/edge totals against TLC completion, and finds a shortest
representative path to each state. It replays every outgoing edge through
[statement_result_state.zig](statement_result_state.zig), which calls the actual
[Progress](../../../packages/zig/transit-sql-results/src/Progress.zig) operations.
It compares every projected counter, outcome, consumption/release state, terminal
and error. It does not implement another progress reducer. Unknown fields/actions,
incomplete replay or any disagreement fail the check.

Five independent model variants remove identity validation, count agreement,
consumption-lifetime admission, the prohibition on completion during release,
and completion preservation. Each must produce its named invariant violation
with an explicit counterexample. The same event sequence is replayed against
Zig and must match the safe model, differing from the violating state. These
are model mutations, not mutations of production Zig. Finite edge replay from
representative paths does not prove arbitrary implementation histories or an
unbounded refinement relation.

### Established-session delivery abstraction

[StatementResultSession.tla](StatementResultSession.tla) and its
[configuration](StatementResultSession.cfg) reuse the logical transition
functions. Initial states range over zero through the selected row bound and
all valid initial chunk sizes and terminal shapes. The initial execute response
has already arrived; missing that response is outside this model. It does not
assume that an unknown initial cursor can be recovered by fetching.

One reader has one retained server batch and one response slot. A successor
fetch acknowledges the previous drained batch; materialization, server disclosure
and client receipt are distinct steps. Replies can be dropped and retried or
repeated without another logical receipt. The model includes final data batches,
empty terminal batches, local row/batch consumption, early close, EOF,
cancellation, revocation/restoration, session expiry, renewal and remote cleanup.
Renewal cannot revive an expired session. Cleanup and local release are separate;
no fairness rule forces either network delivery or remote cleanup to finish.

An independent finite sequence tracks **occurrence identities**, rather than
inferring correctness from matching counters. Distinct occurrences may have
identical SQL values. Every received/delivered sequence must be the corresponding
prefix of the original result, and completion requires the full original
sequence and count. Result ordering here is iterator order, not an added SQL
ordering guarantee.

Current authorization is an atomic predicate at server disclosure. Revocation
can occur after materialization or between a successful send and receipt. An
already disclosed response may arrive after revocation, and local consumption
of received rows does not ask the server for new authority. Every subsequent
server disclosure, including a cached repeat or an empty terminal, checks the
current predicate. Restoration can allow later disclosure; an unchanged policy
epoch throughout a query is not required. Rights for concrete metadata subjects,
credentials and source objects are abstracted into that predicate.

Two additional model variants admit duplicate logical receipt or omit the
current disclosure check. Each must produce its intended invariant failure.
Their counterexamples are retained but **are not replayed against the native
adapter or server**. This session model establishes abstract protocol safety,
not implementation correspondence for ordinals, authorization or cleanup. The
existing `just test::sql-wire-contracts` and `just test::sql-sessions` own concrete
adapter and service schedules; the model does not replace them.

### Evidence and limits

Each invocation retains source/configuration hashes, the locked tool path,
binary hash, revision/dirty status, exact commands, TLC logs, the progress graph,
replay divergence and counterexamples under a unique directory in
`.cache/verification/statement-result-model/`. CI retains that directory.
Tool/compiler errors, timeouts, incomplete exploration, malformed traces and
unexpected invariant failures are inconclusive failures, never detected mutants
or proof success. The shared [TLC support](tlc_support.py) also serves the Console
runner; changing it selects both formal checks.

The models abstract logical payloads, physical batches and live authorization.
They do not prove SQL computation, logical cell validation, codecs, scratch-buffer
ownership, allocator bounds, actual networking, pin recovery or storage durability.
Durable statement acceptance, uncertain write settlement, cancellation racing
publication, lost initial execution responses and future transaction decisions
remain separate temporal-model work. The session abstraction omits malformed
wire framing and arbitrary reordered/skipped ordinals; concrete adapter tests
own those cases. No liveness, latency or arbitrary-cardinality claim follows
from the finite safety results.

## Finite SQL write lifecycle models

Run `nix develop --command just test::write-lifecycle-model`. The locked TLC
uses one worker, seed `1`, fingerprint `0`, a 512 MiB heap and a 60-second
per-process limit (`--seconds N` changes time, never coverage). The runner
requires exhausted queues and complete recognized negative-control traces.
Evidence, exact generated configurations, source/tool/binary identities, logs
and replay projections live under `.cache/verification/write-lifecycle-model/`.

[WriteLifecycle.tla](WriteLifecycle.tla) separates frozen intent, durable
acceptance, terminal decision, visible rows, retained history, owner epoch,
execution/inspection rights and caller knowledge. Three row slots contain absent,
old or new values. One independent INSERT can occur before freezing, between
freezing and completion, or after completion. Owner replacement has two epochs;
crash/recovery, rights changes, observations and lost replies may repeat without
a trace-depth cutoff. UPDATE uses constant assignments, matching the executable
compiler. No-op, empty and invalid-work profiles distinguish matched from changed
counts and complete rejection from partial publication.

Twenty safety profiles cover INSERT/UPDATE/DELETE/TRUNCATE under separate
acceptance and candidate combined acceptance. TRUNCATE is a **proposed** atomic
empty successor that preserves object/definition identity and advances the data
frontier even when empty. It has no runtime adapter. Combined acceptance is also
a proposal: this model does not claim a shared Catalog/Table commit is installed.
Neither profile changes an executable contract or authorizes removing a sync.

[WriteTokens.tla](WriteTokens.tla) independently explores two concurrent callers
with identical versus conflicting requests, separate accounts/tokens, different
Tables, name replacement and recovery. Five profiles preserve the original
account/token operation and frozen object. They abstract Catalog storage and
bound requests, not production cardinality. Separating the token and row models
controls exploration size; their composition is an unproved obligation.

Fifteen controls remove original-operation, frozen-basis, atomic-publication,
count, epoch, execution-right, disclosure, terminal-stability, retention,
durability, token-scope, fingerprint, frozen-object, token-recovery and account
isolation guards. Each must violate its named invariant. The durability control
breaks the abstract publication assumption; it does not establish physical sync
ordering. [Wal.tla](Wal.tla), immutable-object durability and retained dependency
closure remain separate requirements before changing publication barriers.

A separate `FairSpec` run checks eventual settlement of accepted work and eventual
learning of a terminal outcome. It assumes eventually continuous availability
and sufficient current authority/ownership for the respective operation, plus
weak fairness of commit and observation. Indefinite revocation, crashes or lost
service are outside these conditional results. There is no wall-clock bound.

[The private Zig adapter](write_lifecycle_state.zig) replays all ten lifecycle
negative-control schedules against a two-row UPDATE in `TablePartition` using real intents, WAL,
indexes and retained snapshot APIs, and replays all five [WriteTokens.tla](WriteTokens.tla)
negative-control schedules against `DirectCatalog.admitClientToken`. Independent fixed fixture oracles check rows,
counts, terminal identity, token bindings and expected refusals. The first commit reply is lost;
uncertain append errors require reconstruction before oracle inspection.
`Cleanup` checkpoints without granting history expiry. The adapter uses the
memory providers and a separate authorized inspector for its oracle: that
inspector is not caller disclosure. Disk reopen and post-commit later INSERTs
are independently exercised in `table_statement_test.zig`.

This is selected counterexample replay, not every-edge correspondence, production
guard mutation or a refinement proof. Physical bytes, quota reservation, schema changes, key swaps, arbitrary
predicates/cardinality, network/session recovery and combined acceptance remain
outside this abstraction. The owner mapping and durability obligations are
explained in [storage runtime](../../../docs/handbook/internals/storage-runtime.md#write-lifecycle-model-boundary).

## Finite transaction workspace model

Run `nix develop --command just test::transaction-workspace-model`. The ordinary
formal lane owns this check. [TransactionWorkspace.tla](TransactionWorkspace.tla)
and [TransactionWorkspace.cfg](TransactionWorkspace.cfg) compose the catalog-side
transaction lifecycle across `TRANSACTION-02` (transaction registration and login
role attribution), `TRANSACTION-03` (epoch-fenced coordinator leases and renewal),
`TRANSACTION-05` (consistent-cut pin acquisition, crash resume revalidation and
cut publication), and `TRANSACTION-06` (private statement admission, autocommit
namespace isolation, aggregate 6-dimension account quota reservation and public
Table isolation).

The safe configuration exhausts 304 distinct states. Eight independent negative
controls remove registration token conflict detection, stale lease renewal,
partial pin resume revalidation, mixed-cut publication refusal, autocommit
statement token isolation, private-write public isolation, aggregate quota ceiling
admission, and current disclosure authorization. Each negative control trace is
replayed against `DirectCatalog` and `TablePartition` through
[transaction_workspace_state.zig](transaction_workspace_state.zig) and
[transaction_workspace_model.py](transaction_workspace_model.py).

## Finite storage lifecycle and retention closure model

Run `nix develop --command just test::storage-lifecycle-model`. The ordinary
formal lane owns this check. [StorageLifecycle.tla](StorageLifecycle.tla) and
[StorageLifecycle.cfg](StorageLifecycle.cfg) model the composition of
`TableMaintenanceState` (`STORAGE-04`), `TableRetention` (`STORAGE-05`),
`TableStorageRoots` and `TableGarbageCollection` (`STORAGE-06`), and
`TransactionSuccessorState` (`TRANSACTION-04`).

The safe configuration exhausts 1,200 distinct states. Six independent negative
controls remove maintenance phase gating, pinned segment retention, active
snapshot WAL trim floor protection, uncheckpointed WAL retention, transaction
successor staging protection, and expired checkpoint descriptor preservation.
Each negative control trace is replayed against `TablePartition`,
`TableMaintenanceState`, `TableStorageRoots`, and `TableGarbageCollection`
through [storage_lifecycle_state.zig](storage_lifecycle_state.zig) and
[storage_lifecycle_model.py](storage_lifecycle_model.py).

## Finite resident Table owner and ReadCache model

Run `nix develop --command just test::resident-owner-cache-model`. The ordinary
formal lane owns this check. [ResidentOwnerCache.tla](ResidentOwnerCache.tla)
and [ResidentOwnerCache.cfg](ResidentOwnerCache.cfg) model resident `CachedTable`
owners in `LocalTableService`, incremental `TablePartition.recoverSince` WAL
catch-up, `recovery_required` poisoning after uncertain WAL appends, temporary
transaction statement owner isolation, and `ReadCache` snapshot pin lifecycles
(`SQL-READ-01`).

The safe configuration exhausts 149 distinct states. Five independent negative
controls remove `recoverSince` chain-hint validation, `recovery_required` warm
owner eviction after uncertain appends, temporary transaction owner isolation,
`ReadCache` closing-pin unadvertised eviction ordering, and ambiguous `Conflict`
pin preservation. Each negative control trace is replayed against
`TablePartition` and `DirectCatalog` through
[resident_owner_cache_state.zig](resident_owner_cache_state.zig) and
[resident_owner_cache_model.py](resident_owner_cache_model.py).

## Finite QueuePartition lease and turn-commit model

Run `nix develop --command just test::queue-lease-transaction-model`. The
ordinary formal lane owns this forward-design check for Milestone 6
(`QUEUE-01`). [QueueLeaseTransaction.tla](QueueLeaseTransaction.tla) and
[QueueLeaseTransaction.cfg](QueueLeaseTransaction.cfg) model `QueuePartition`
logical state sets (`available`, `acquired`, `acked`, `dlq`), per-key acquisition,
lease epochs and authoritative expiry, current-policy commit checks, prepared
turns, one commit/abort decision and retained-payload collection guards.

The finite domain contains three offsets (two for one key and one for another),
two claim generations, time in `0..2`, one prepared turn and one decision. A
restart drops derived residency while accepted records remain. This abstracts
atomic durable state; it does not model WAL writes, a timing wheel, bitmap bytes,
receipt authentication, complete implementation correspondence or power loss.
The invariants are safety-only, with no fairness or starvation-free scheduling
claim. The other key remains eligible while the first key is blocked.

[queue_lease_transaction_model.py](queue_lease_transaction_model.py) requires
complete exploration and nine intended invariant failures: overlapping states,
FIFO bypass, stale epoch, partial turn visibility, premature terminal collection,
expired-but-unreassigned commit, revoked commit, collection while history remains
held, and source DLQ terminalization without durable destination payload.
It records source/configuration/driver hashes, TLC identity, completed state
counts and each negative trace under the repository's ignored evidence directory.
Earlier 21-state/five-control results apply to the earlier model revision.

The pure [Stream/Queue bindings](../../../packages/zig/transit-protocol/src/StreamQueue.zig)
independently check supplied lease/time guards and original accepted receipts;
those unit checks are not replay of this model. `QueuePartition` remains an
unimplemented runtime owner. The [Queue contract](../../../contracts/QUEUE_V1.md)
defines that boundary and the obligations before execution.
