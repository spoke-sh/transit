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

The journal's operation boundaries provide a reviewed correspondence:
`TransactionDecisionLog.freeze` checks the frozen binding and participant
directory; `commit` verifies complete membership and calls current owner checks
under the supplied guard; `append` uses the conditional, epoch-fenced log;
terminal `commit`/`abort` retries return the original decision; `observe` checks
current authority; `recover` reconstructs history without dispatch. The
[component tests](../../../packages/zig/transit-storage/src/transaction_decision_test.zig)
exercise these operations with disk reopen, lost replies, pre/post-append failure,
stale epochs, missing preparations and denied callbacks. They do not automatically
replay model counterexamples or establish complete edge correspondence.

Atomic conditional append and truthful verification while all participant/name/
policy guards remain held are model assumptions. The model abstracts identities,
payloads, descriptor integrity and memory. It establishes no consistent-cut
acquisition, Table predecessor barrier, common Table visibility, serializability,
SQL transaction, retention integration, distributed decision or filesystem proof.
The [integration contract](../../../packages/zig/transit-storage/docs/transaction-decisions.md)
states the missing production owners. Source/configuration hashes, revision/dirty
state, exact commands, TLC logs, completion counts and counterexamples remain
under `.cache/verification/transaction-decision-model/` and CI artifacts.

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
indexes and retained snapshot APIs. Independent fixed fixture oracles check rows,
counts, terminal identity and expected refusals. The first commit reply is lost;
uncertain append errors require reconstruction before oracle inspection.
`Cleanup` checkpoints without granting history expiry. The adapter uses the
memory providers and a separate authorized inspector for its oracle: that
inspector is not caller disclosure. Disk reopen and post-commit later INSERTs
are independently exercised in `table_statement_test.zig`.

This is selected counterexample replay, not every-edge correspondence, production
guard mutation or a refinement proof. The token model has no automated Catalog
replay. Physical bytes, quota reservation, schema changes, key swaps, arbitrary
predicates/cardinality, network/session recovery and combined acceptance remain
outside this abstraction. The owner mapping and durability obligations are
explained in [storage runtime](../../../docs/handbook/internals/storage-runtime.md#write-lifecycle-model-boundary).
