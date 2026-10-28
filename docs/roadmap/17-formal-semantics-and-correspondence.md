# 17. Formal semantics and implementation correspondence

[Roadmap](README.md) · **Status:** In Progress

Make the delivered data, computation and policy guarantees easier to preserve
while changing their implementation. Extract small temporal models and algebraic
specifications from the qualified local system, connect them to production
behavior, and retain executable counterexamples as development tools. The outcome
is a reviewed set of semantic obligations with reproducible implementation
checks, clearer ownership and simpler recovery or transformation logic.

## Prerequisites and timing

Close phase II after [service and SDK coverage](16-service-and-sdk-coverage.md),
before [provider and concurrent-writer qualification](18-storage-providers-and-concurrency.md).
Consume the delivered [storage](02-storage-and-query-performance.md),
[live cutover](03-live-storage-and-sql-cutover.md),
[statement results](04-statement-results-and-consumption.md),
[transactions](05-transactions-and-atomic-composition.md),
[shared clients](07-client-foundation-and-language-apis.md),
[historical interpretation](08-standards-and-catalogs.md),
[indexes](09-indexing-and-access-paths.md),
[managed computations](10-sql-and-dataflows.md),
[selected structures and optimizations](11-data-structures-and-performance.md),
[foreign relations](14-multi-model-and-foreign-relations.md) and
[branches](15-branches-merges-and-restore.md).

Entry requires settled owning contracts, executable operations and focused
failure evidence for each selected family. In particular, let statement-result
and transaction work establish its shared semantics before modeling its reader
or coordinator. Proposed names, algorithms and formulas below are research
candidates; they do not freeze today's adapters or select future runtime APIs.
Shared protocols need one owning contract across SQL, SDKs and UI.

Earlier milestones retain their correctness, recovery, authorization and resource
gates. Preserve existing models through their cutovers and revise them with
intentional contract changes. This milestone adds systematic formal coverage;
its delivery position cannot justify postponing a known correctness defect.
Contract investigations for later providers may overlap once their prerequisites
exist; a new deployment profile must recheck the assumptions of any reused model.

## Discussion provenance and existing foundation

The user supplied a discussion with Google Gemini Argon in
`formal_models_transcript.txt`, reviewed alongside local source `0214f42d`.
Its SHA-256 is
`70427ab02f04444f4193c22bfc8e9c44fc2b2c30b13786d4f550128bcf8f1375`.
The local transcript is source material, not a required repository artifact or
capability contract. This plan preserves its seven temporal and six algebraic
candidate families, motivating schedules and intended development benefits, with
the corrections below. Its proposed 23-milestone numbering is superseded by the
current sequence. Candidate identifiers here provide traceability without
requiring the transcript to understand the work.

The planning baseline `b65546ff` contains the finite Authority, Delivery and Console models
and four Lean rewrite theorems. The reviewed local storage branch additionally
contains `Wal.tla`; that observation does not establish its merged availability
or passing qualification at a later revision. Reassess the actual merged
baseline when this milestone starts. Existing owners are the
[model guide](../../tests/verification/models/README.md),
[rewrite specification](../../contracts/sql/FuzeRewrite.lean),
[invariant inventory](../../tests/verification/invariants.json),
[verification reference](../handbook/reference/verification.md) and
[executed proof ledger](../history/qualification/README.md).

Retain the useful distinction among finite exploration, deductive theorems,
implementation correspondence and integration experiments. Console exports its
finite graph and replays every edge from a representative path against the Zig
reducer; Authority bridges selected removed-guard counterexamples. Delivery's
current task checks bounded safety without that replay bridge. The reviewed WAL
work separates visible and durable storage under stated filesystem assumptions.
The Lean theorems describe selected abstract transformations, not all Fuze Cells
or Zig executions. None of these alone proves arbitrary histories, cardinality,
hardware behavior or a complete implementation refinement.

## Temporal candidate families

Use TLA+/TLC where interleavings, ownership, durable decisions or uncertainty are
the difficult part. Prefer several composable small models to one product-sized
state graph. Abstract payloads deliberately while retaining the identities,
dependencies and evidence needed to falsify each claim. The filenames suggested
in the discussion are labels for candidates, not required files.

### T1. Storage publication, retained readers and reclamation

Candidate: `StorageLifecycle.tla`. Follow accepted writes through WAL and active
memory, immutable `.tseg`/`.tdel` staging, conditional root publication, flush,
compaction, reader-pin acquisition/release, checkpointing, trimming and recovery.
Separate publication from the proof that reclamation is authorized.

- A retained reader sees the same logical data and interpretation across physical
  rewrites, including accepted unflushed rows. Staged bytes alone expose no change.
- Every published root and retained owner has complete durable supporting objects
  and required log ranges. Acknowledged changes and original outcomes survive
  recovery; a lost reply does not choose another identity or source basis.
- Collection preserves current and retained roots, branch heads, readers,
  unfinished publication, retry/retirement evidence and promised logical history.
  Incomplete marking or elapsed wall time without the required recorded fence
  cannot authorize deletion. Cleanup resumes without targeting replacement IDs.

Explore pin acquisition racing compaction, crashes before/after publication,
interrupted deletion, orphan staging and checkpoint replacement. Derive safe trim
from coverage and ownership. The transcript's minimum of flushed, pinned and
checkpoint LSNs is insufficient as a general rule: owners can require different
partitions, ranges, identity evidence or every-change history. A state checkpoint
of `A` cannot replace `A -> B -> A` for a complete-change consumer.
The [snapshot contract](../../contracts/DATA_LIFECYCLE_V1.md#snapshot-coverage-and-retention)
and [retention reference](../handbook/reference/retention.md) own those distinctions.
The benefit is one reviewable publication/reclamation argument across maintenance
implementations without assuming a shared transaction across independent owners.

### T2. Statement results, disclosure and uncertain settlement

The finite result-consumption slice is implemented ahead of the broader phase-II
closure: [StatementResult.tla](../../tests/verification/models/StatementResult.tla)
checks logical progress with complete finite-edge replay against Zig, and
[StatementResultSession.tla](../../tests/verification/models/StatementResultSession.tla)
checks established-reader delivery and disclosure as an abstract protocol.
The [model guide](../../tests/verification/models/README.md#finite-sql-result-models)
defines their bounds and exclusions. This does not complete T2 or the milestone.

Remaining work: model
durable operation state, the caller's knowledge of it, session attachment and
reader progress separately. Include submission, ordered/repeated fetches, final
data or empty terminal batches, early close, expiry, revocation, cancellation
racing commit and recovery of the original token.

Completion requires the selected contract's full ordered coverage and verified
terminal evidence. EOF, a display limit or a prefix cannot establish completion;
retry cannot splice in another snapshot. Recheck current rights at each protected
disclosure, including buffered repeats, metadata, empty batches and final counts.
Do not invent a requirement that an unchanged policy epoch span the whole query.
Statement completion inside an open transaction retains provisional attribution;
local cancellation cannot manufacture rollback of accepted work. Legitimate
owner-confirmed abort and unresolved observation remain distinct.

Connect the remaining protocol/settlement model to the shared implementation rather
than duplicating recovery in adapters. Replay the relevant client/server boundary
events and separately test scratch-buffer ownership, cancellation joins and real
transport. The [SQL session contract](../../contracts/SQL_SESSION_V1.md) is the
starting owner, not a frozen definition of the future result API.

### T3. Selected concurrent index algorithms

Candidate: `BBTreeOLC.tla`, only if the structure milestone selects the relevant
algorithm. Model a small root/leaf/split configuration with readers, writers,
versions, fences, separator installation, restart and reclamation. Check for
missed keys, invalid routing, publication of incomplete splits, lock cycles and
unsafe reuse. State point-read and range-read consistency separately.

Node-version validation alone proves neither a linearizable range snapshot nor
race freedom, safe reclamation or lock-freedom. Define the actual lock order,
memory-order assumptions and progress conditions of the selected Zig algorithm.
Use targeted implementation stress/memory evidence for behavior outside the
abstract model. Keep other tree, radix or immutable structures eligible; BBTree
and optimistic lock coupling are evaluation inputs. This work should expose a
small concurrency protocol that developers can change and check independently
of layout and SIMD optimizations.

### T4. Transaction decisions, isolation and atomic outbox publication

The executable [decision-journal](../../tests/verification/models/README.md#finite-transaction-decision-model)
and [local Table transaction](../../tests/verification/models/README.md#finite-local-table-transaction-model)
models cover separate finite safety boundaries. The latter adds interrupted
common-cut acquisition, whole-Table conflict validation, savepoint dependencies,
private reads and common-decision visibility. Production trace replay and complete
runtime correspondence remain open; these model checks do not establish installed
transaction support or a proof for arbitrary histories.

Candidate: the discussion's `TransactionSSI.tla`, renamed for the chosen protocol.
The initial planned local profile in [Milestone 5](05-transactions-and-atomic-composition.md)
selects whole-object optimistic validation, while [Milestone 9](09-indexing-and-access-paths.md)
and [Milestone 18](18-storage-providers-and-concurrency.md) escalate read-write
concurrency to fine-grained key-range and predicate-level Serializable Snapshot
Isolation (SSI / index-range `rw-antidependency` tracking). Model begin/read/private write,
absent-key, index-range or predicate dependencies, cross-table `FOREIGN KEY` and
`CHECK` constraints, savepoints, participant preparation, the common decision,
commit/abort races, lost replies and recovery under replacement ownership.

Check read-your-writes, atomic visibility within the declared domain, the selected
serializability/anomaly rules, constraint preservation and one original decision.
Savepoint rollback must retain conflict dependencies required by that isolation
contract. Include write skew, concurrent DDL, partial participant availability,
stale coordinators and revocation before publication. A timeout reports knowledge
of a decision; it is not an additional commit state or evidence of abort.

Data and supported outbox intents publish atomically. Aborted/uncommitted intents
cannot become eligible for dispatch; committed intent identity survives lost
replies. Dispatch authorization, attempts, capture, retry policy and remote
outcomes have their own owner. An intent ID or atomic outbox does not establish
at-most-once remote execution. Recovery never redispatches as a side effect of
replay. Keep native turns and direct transactions separate unless their owning
participant contracts explicitly compose them. See the
[transaction scope](05-transactions-and-atomic-composition.md).

### T5. Snapshot-to-history handoff and consumer checkpoints

Candidate: `SubscriptionHandoff.tla`. Model backfill at an exact accepted cut,
concurrent writes/flush/trim, handoff to retained changes, bounded delivery,
checkpoint publication, disconnect and resume. Start tail coverage from the
contract's accepted source cut, not merely a physical flushed watermark.

Prove gap-free complete-transaction coverage or an explicit history-unavailable
outcome. Preserve both transitions in `A -> B -> A` where every change is promised.
Separate transport duplicates from duplicate application: checkpoint and effects
must share a qualified commit boundary or expose their separate recovery protocol.
Do not promise duplicate-free network delivery from ordered LSNs alone. Define
backpressure, retained-history ownership and current disclosure authority.
Net relation changes, latest-result refresh and every-change consumption keep
their distinct contracts. The benefit is shared handoff and coverage reasoning
for indexes, maintained computations and client subscriptions.

### T6. Branch isolation, logical merge and reviewed publication

Candidate: `BranchMerge.tla`. The local slice covers complete branch creation
including pinned WAL tails, independent writes, physical compaction, frozen
base/source/target, candidate validation and conditional forward publication.
Check that compaction creates no logical conflict, retained parents/children keep
their data, changed targets reject, constraints hold and lost replies retain the
original merge identity. Copying history cannot copy execution rights or dispatch
historical effects.

The later reviewed-publication slice adds candidate-bound approval, target
movement, withdrawal, reviewer revocation and duplicate execution. Approval must
match the exact candidate and target expectation and satisfy the chosen current
policy at publication. It is not a reservation. Human-only approval and delegated
actor checks wait for the enterprise identity contract. Keep that extension with
[reviewed collaboration](24-reviewed-data-collaboration.md); local branch-model
completion does not depend on that later experience.

### T7. Provider fencing, replication and failover

Candidate: `LeaseFailover.tla`, owned by the later distributed milestones. Model
partition ownership and policy epochs, log/object publication, delayed requests,
partitions, replica catch-up, promotion and stale-writer attempts. Specify the
storage mechanism that enforces each fence and the ordering of revocation,
acceptance and promotion; a lease tuple or object CAS is insufficient alone.

Check complete decision/object coverage before promotion, preservation of
acknowledged history under the selected durability profile, and rejection of
stale publication at its authoritative boundary. A log watermark without its
referenced objects cannot establish a usable replica. State quorum, failure,
clock, I/O and fairness assumptions explicitly. Reuse the local publication model
only after establishing that the provider satisfies those assumptions. This
family supplies a protocol reference for provider and placement implementations;
it does not choose replication topology or qualify hardware by model checking.

## Algebraic and structural candidate families

Extend the pinned Lean foundation when universal laws over values, collections
or transformations are the question. Use narrow SMT/bit-vector checks or a
relational tool such as Alloy only where they materially improve a selected
obligation; adding a new tool requires deliberate pinning and CI-cost review.
Executable independent fixtures and differential tests connect formal functions
to the actual Zig implementation. No toolchain change is part of this plan.

### A1. Five-state Cells and query rewrites

Extend `FuzeRewrite.lean` toward the delivered `value`, `null`, `missing`,
`type_error` and `conflict` semantics. Use the actual conflict representation and
error rules rather than assuming a conflict always contains exactly two values.
Specify output schema, bag multiplicity, prescribed order and exact first-error
behavior for each theorem. Investigate predicate pushdown, projection pruning,
constant folding, boolean normalization, common-subexpression elimination and
index-only replacement with explicit premises.

For example, `x = x` cannot become unconditional true for all Cell states.
Evaluation order, fallibility and dropped expressions can invalidate familiar
relational rewrites. Existing total-predicate proofs do not settle these cases.
Tie each selected theorem to planner eligibility and independent execution
fixtures before enabling a rewrite; permissions, allocation and cancellation
remain separately checked obligations.

### A2. Collation keys, composite encodings and sound pruning

Candidate: `CollationOrder.lean`. Relate declared logical comparison to byte-key
comparison for valid values. Cover embedded-zero escaping, variable lengths,
composite keys, null/state ordering where admitted, DESC encoding and prefix
compression. Collation-equivalent strings may share a sort key: an order
isomorphism over raw strings would be too strong for case-insensitive equality.

Prove one-sided pruning soundness for selected zone maps and index routing:
discarded regions contain no qualifying values under the same comparison
semantics. For abbreviated/SIMD prefixes, equal prefixes require full-key or
otherwise proved resolution; prefixes alone do not establish strict order.
Keep format/codec, collation identity and query support separate. This provides
reusable laws for storage, indexes and optimizers as physical layouts evolve.

### A3. Incremental dataflow equivalence

Candidate: `FuzeDelta.lean`, informed by DBSP and integer-weighted multisets.
For a selected operator, define `Q(S + dS) = Q(S) + dQ(S, dS)` with explicit
domains, output/error meaning and complete input-transaction boundaries.
Distinguish linear operators from bilinear joins and nonlinear operators.
For a bilinear join, with `A` and `B` denoting the old inputs, include all three
terms `dA join B + A join dB + dA join dB`.

Left joins need match-count/zero-crossing reasoning, and grouping/deletion need
their own state and multiplicity laws. Ordered checked SUM is not automatically
a commutative-group aggregate: `[MAX_I64, 1, -1]` fails on an intermediate prefix
while a different order may succeed. Specify preservation of errors and source
contribution order or explicitly change the owning semantics before using an
alternative algebra. Compare incremental implementations with the qualified
finite recomputation oracle, including simultaneous changes on both sides.
Use the [DBSP paper](https://arxiv.org/abs/2203.16684) as a mathematical input,
not evidence that all of Transit's operators meet its premises.

### A4. Logical merge and safe segment skipping

Candidate: `BranchMergeAlgebra.lean`. Define merge over logical data and exact
schema/identity under the selected conflict and constraint rules. Investigate
identity `Merge(B, B, R) = R`, equal-side agreement and symmetry of conflict
detection where the contract supports them. A policy-sensitive relational merge
is not automatically a commutative semilattice; conflicts, invalid candidates
and authorization need explicit treatment. Document merges retain causal and
tombstone information rather than just materialized values.

Prove optimized segment skipping equivalent to the independent full logical
merge, including its conflict set. Shared segment IDs alone are insufficient if
deletion vectors, interpretation, visibility or retained WAL overlays differ.
Compaction must not introduce false conflicts. Establish semantic equivalence
separately from a sublinear complexity claim, which requires an explicit cost
model and workload assumptions.

### A5. Physical codecs and selected bitmap representations

Candidate: `CodecProofs.lean` with bounded bit-vector checks where useful. Prove
`decode(encode(x)) = x` over each admitted, representable value domain, preserving
required bit distinctions such as signed zero. Cover selected COMP-3 packed
decimal nibbles, ZONED signs, COMP integers, IBM HFP exact conversions and the
CP037 repertoire. HFP-to-IEEE conversion needs explicit exactness/range premises;
CP037 is not a bijection with arbitrary Unicode. Invalid encodings must take the
specified rejection/type-error path with bounded work, rather than panic or
silently manufacture a value. Distinguish value-domain and byte-format validity.

If Roaring-style containers are selected, relate array/bitmap/run representations
to sets and prove conversions and union/intersection/difference laws across
container combinations, including the nine pairings for three representations.
Keep algorithm selection with the structure owner. Use independent byte fixtures,
allocation bounds and fuzzing to cover implementation behavior outside the
formal encoding functions.

### A6. Authorization, delegation and protected publication

Candidate: `PolicyLattice.lean`, after the enterprise policy contract settles.
Model authenticated actor, represented subject, scope/audience, delegation chain,
current membership/grants, declarative Row-Level Security (RLS) security-barrier
predicates, Column-Level Security (CLS) / dynamic masking rules and target policy
distinctly. Establish attenuation:
delegated permissions are contained in the currently permitted subject actions
and every applicable delegation restriction, with any actor checks required by
the contract. Prove **security-barrier non-interference** for RLS and masking in
conjunction with A1 (`FuzeRewrite.lean`): query rewrites, filter pushdown,
zone-map/index statistics and eager 5-state `type_error` or checked-arithmetic
failures must never evaluate untrusted user predicates or leak error side-channels
from rows or columns excluded by the caller's policy at `policy_epoch`. Define
monotonicity only for specified inputs/orderings; revocation and explicit
restrictions do not make the whole policy evaluator monotone.

Prove that delegated agents cannot borrow human-only approval authority and that
protected destinations cannot be changed through an equivalent direct-write
adapter. Do not invent deny precedence or a new grant authority. A relational
model may help find graph counterexamples; temporal revocation and approval races
still need temporal checks. This family belongs to the later identity and review
owners, with shared evaluation across SQL, SDK, MCP and browser callers.

## Delivery and implementation correspondence

1. **Select a bounded tranche from the delivered contracts.** Review all T1–T7
   and A1–A6 against the actual merged system. Record the owner, stable claim,
   motivating failure, technique, abstraction, implementation projection and
   dependencies for each selection or justified deferral. Require executable
   work on both temporal and algebraic families; copying an inventory does not
   complete the milestone. Later distributed/governance candidates keep their
   explicit owners below. Do not require thirteen predetermined model files.
2. **Expose deterministic decisions where it simplifies the implementation.**
   Keep storage, time and external effects behind explicit inputs/outcomes.
   Reuse production reducers and operations, with a named projection from their
   state to the model. A second implementation that repeats expected answers
   cannot establish correspondence. Preserve public ownership and commit domains;
   do not force all subsystems into one universal lifecycle or rewrite code solely
   to resemble a model.
3. **Check claims and challenge their premises.** Exhaust the stated finite
   domain; distinguish state bounds from depth cutoffs. Add removed-guard or
   alternative-formula controls that fail the intended property. Parser errors,
   timeouts, incomplete queues and unsupported cases are inconclusive failures.
   Record fairness/storage assumptions for progress; a safe terminal refusal is
   not availability. Deductive proofs identify their domain, premises and axioms
   and contain no unproved placeholders for claimed results.
4. **Connect evidence to production behavior.** Use complete finite graph-edge
   replay where tractable, selected trace replay and differential/metamorphic
   fixtures elsewhere. Compare observable identity, outcome, basis, progress and
   effects, not only success codes. Preserve counterexample schedules and their
   safe implementation behavior. Abstract-edge replay does not prove all concrete
   histories, weak-memory correctness, arena ownership or hardware durability;
   retain focused integration, allocator, disk and provider checks.
5. **Make the suite useful during development.** Integrate selected checks with
   the existing task/invariant inventory. Pin tools, retain source/tool/binary
   provenance and complete reports, and measure ordinary versus extended
   exploration costs before assigning CI lanes. Do not promise a fixed runtime
   from a small example. Publish consolidated reasoning, assumptions and limits
   in the owning Internals topics under their scientific standard; keep interface
   semantics in public contracts/references and execution results in the ledger.

## Later ownership and extensions

Local completion does not wait for every future deployment or governance model.
As later contracts settle, their owners reassess these candidates, extend the
selected formal suite and requalify implementation correspondence. Record an
explicit scope decision for an inapplicable/deferred candidate; do not silently
inherit a proof whose assumptions the new profile violates.

| Owner | Candidate extension and boundary |
| --- | --- |
| [Providers and concurrent writers](18-storage-providers-and-concurrency.md) | T1/T7: actual permission/epoch enforcement, conditional publication and complete object/log coverage for each provider |
| [Replication and failover](19-replication-and-failover.md) | T4/T7: replicated decisions, object availability, catch-up, promotion and stale-writer fencing under selected failures |
| [Operations and recovery](20-operations-and-recovery.md) | T1/T4/T7: retained backup/PITR roots, consistent decisions and authority-safe restore/upgrade boundaries |
| [Clustered execution](21-clustered-execution.md) | T3/T5/T7 and A3 where applicable: placement ownership, distributed coverage and preserved query/error semantics |
| [Enterprise identity](22-control-and-policy-plane.md) | A6 and temporal checks: actor/subject binding, delegation attenuation, membership freshness and revocation |
| [Reviewed publication](24-reviewed-data-collaboration.md) | T6/A4/A6: exact candidate/target approval, current reviewer authority and protected-destination enforcement |
| [Reactive activation](27-reactive-context-and-agent-activation.md) | T5: durable interests, meaningful change conditions, checkpoint recovery and explicit coverage |
| [Recorded integrations](28-recorded-mcp-integrations.md) | T4's effect boundary: authorized attempts, uncertain remote outcomes, capture and network-free replay |
| [Complete qualification](30-qualification-and-benchmarks.md) | Execute the selected local and later suites at one revision alongside installed workloads and physical failure evidence |

## Completion evidence

Deliver at least one new lifecycle model and one new algebraic proof family from
the selected local scope, each connected to an actual implementation and its
owning contract. Review all candidate families and retain explicit scope decisions
and later ownership. Require meaningful forbidden-outcome controls, reproducible
counterexamples/fixtures, completed runs and a maintained CI task for each selected
claim. Report bounded model coverage, universal theorem premises and unproved
implementation assumptions separately.

Document the concrete development benefit: an ambiguity resolved, ownership or
recovery logic simplified, duplicated reasoning removed, or an optimization
justified under exact semantics. A theorem over an unrelated abstraction or a
passing model without implementation correspondence is insufficient. The
[common-revision qualification](30-qualification-and-benchmarks.md) repeats this
evidence with later extensions; it does not replace this milestone's execution.
No new runtime guarantee, model pass, SQL interface or algorithm selection is
established by this planning change.
