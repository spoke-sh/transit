# 1. Data identities, declarations and commit contracts

[Roadmap](README.md) · [Current data model](../handbook/reference/data-model.md) · [Tracker #108](https://github.com/spoke-sh/transit/issues/108) · **Status:** Completed

Define how an application describes data, schemas, computations and policies,
and how public operations bind that declaration to identities, dependencies,
authority, accepted changes and observable outcomes. Establish neutral contracts
before storage formats and runtime integration depend on them.

The 2026-10-24 sequencing review separates this contract/metadata foundation from
the installed lifecycle implementation in [milestone 3](03-live-storage-and-sql-cutover.md).
The original direct Table, named KV/Document and computation-lifecycle acceptance
obligations transfer explicitly to that owner. The final review below accepts
the foundation and the delivered original caller outcomes tracked by #108.
It preserves the unfinished storage, maintenance and broader cutover obligations
under their existing owners; the sequencing split alone established no completion.

## Final lifecycle acceptance review — 2026-10-26

The contract foundation and delivered original lifecycle scope are accepted on
the evidence below. This closes the milestone's implementation review and #108's
delivered caller obligations; it does not close the remaining storage/cutover
milestones or shared tracking issues wholesale.

The acceptance boundary is data-first: Table ingestion, row acceptance and
scans use the direct WAL-backed owner. Station coordinates application work;
its mailbox and turn bounds do not define the storage engine. The shared local
backend correction releases the journal mutex during private immutable-object
I/O while preserving quota reservation, per-key publication and final authority
checks. Its component tests include a paused-sync progress schedule and a
negative control restoring the earlier lock extent.

| Acceptance area | Delivered scope and executed evidence | Remaining owner |
| --- | --- | --- |
| Stable identities and direct acceptance | [Public CRUD/DDL](../history/qualification/catalog.md#direct-table-crudddl-recovery--2026-10-23), [shared preparation](../history/qualification/catalog.md#shared-direct-table-ddl-preparation--2026-10-24), [preview](../history/qualification/catalog.md#shared-direct-preview--2026-10-24) and [139-Table growth](../history/qualification/catalog.md#direct-catalog-growth-and-retained-rows--2026-10-24) establish the direct owning path, exact lost-reply recovery, current policy, stale-content/definition rejection and name replacement. | Broader client/statement APIs remain milestones 4 and 6. |
| Durable snapshot interpretation | [Retained SQL cuts](../history/qualification/sql.md#direct-sql-ledger-recovery-and-pin-authority--2026-10-24) include accepted unflushed rows; original pin acquisition/release and metadata survive replacement. [Competing checkpoints](../history/qualification/storage.md#snapshot-pins-against-competing-checkpoints--2026-10-24) preserve pinned history. Multi-source reads expose independent vectors explicitly. | Multi-Table consistent cuts and transaction histories remain milestone 5; destructive collection and branch/provider qualification retain their storage owners. |
| Named usable KV/Document resources | [Allocation and initialization](../history/qualification/catalog.md#named-native-resource-allocation-and-initialization--2026-10-24), [lifetime/dependency recovery](../history/qualification/catalog.md#named-resource-dependency-authority-and-retirement--2026-10-24) and [shared caller recovery](../history/qualification/sdk.md#direct-host-named-resource-recovery--2026-10-24) use real native resources. [139-resource](../history/qualification/catalog.md#public-named-resource-growth-and-restart--2026-10-25) and [139-edge](../history/qualification/catalog.md#public-dependency-graph-growth-and-restart--2026-10-24) schedules exceed resident caches and recover after restart. | Service-managed reconciliation remains a later lifecycle extension; associations still confer neither authority nor ownership. |
| Computation results and freshness | [Result/source attribution](../history/qualification/query.md#result-source-freshness-and-named-attribution--2026-10-23) and [named query publication](../history/qualification/query.md#named-query-dependency-publication-and-retirement--2026-10-24) bind actual captured/maintained results and exact data/definition revisions. Activation, source-change detection, denial and recovery are exercised. Inspection starts no work. | Automatic WAL-driven scheduling and managed computation remain milestone 9. |
| Admitted representations and comparison limits | [Independent physical-column checks](../history/qualification/sql.md#lossless-physical-column-admission-and-public-sql--2026-10-23) establish lossless values across WAL/segment reads, definition rejection and the then-explicit non-binary SQL refusal at their recorded sources. [Neutral schema checks](../history/qualification/sdk.md#neutral-physical-schemas-across-language-callers--2026-10-23) preserve codec/collation descriptors. The recorded repository and hosted core runs exercise the fixtures at those sources. | Broader codec/storage qualification remains #118 in milestone 2. Later SQL collation support in PR #172 has separate evidence; ICU remains unsupported. |
| Neutral index foundation | [Neutral index checks](../history/qualification/catalog.md#neutral-index-contracts--2026-10-25) cover immutable source/key/constraint identities, build generations and exact snapshot coverage through owning types, generated contracts and independent positive/negative fixtures. | Installed index operations, secondary access paths and online maintenance remain milestone 8. |
| Cutover and caller agreement | [The actor Table owner is retired](../history/qualification/catalog.md#direct-catalog-hard-cutover-and-retired-owner--2026-10-24). [SDK selected-role checks](../history/qualification/sdk.md#direct-catalog-sdk-selected-roles--2026-10-24), shared native/port and installed SDK lanes pass with exact outcomes, current-definition rejection and current authorization. | Additional language/platform profiles retain their SDK owner; a v1 label never implies compatibility between builds. |
| Documentation and evidence | Current capabilities and limits are in the public data-model, architecture, Table/state/caller, storage and verification references. The proof ledger retains exact sources, failures, raw artifacts and the scope of each pass. | #123/#124 retain broader storage/provider/performance obligations. |

The 2026-10-26 close-out decision replaces the earlier requirement to finish
every combined suite before this milestone closes with the scoped lifecycle
acceptance above. The user explicitly requested separate launcher tracking and
documentation close-out. Full combined qualification remains open under #124;
the failures below retain their assertions, evidence and owners. This decision
does not relabel the failed suite or waive the delivered lifecycle's caller,
authorization, growth and recovery requirements.

The [final qualification record](../history/qualification/verification.md#final-lifecycle-qualification-and-remaining-checks--2026-10-26)
binds full `just check` (2,070.32 seconds) and seven passing focused installed
tasks, followed by a failed Station launcher bootstrap (1,335.31 seconds total),
to `a048b154f`, whose tree equals merged
PR #170 (`443404722`). The original clean experience lane remains **failed**:
four tasks pass, then the no-argument node logging assertion observes a dropped
terminal event before storage opens. Its later eight tasks do not run in that
lane. Seven pass separately from the same isolated checkout, with unchanged
fixtures and deadlines; the final Station bootstrap task fails. [#171](https://github.com/spoke-sh/transit/issues/171)
owns the logging failure. [#173](https://github.com/spoke-sh/transit/issues/173)
owns the Station launcher's missing bootstrap-owner replacement after a required
WAL reopen. A diagnostic recovers its original sequence-10 receipt after reopening
the same directory, with accepted position unchanged. No new work or subsequent
provisioning is submitted. This confirms the original native acceptance/recovery
boundary while leaving the launcher task failed. These distinctions are part of
the acceptance review; there is no claim of a complete combined-suite pass.

Earlier source-attributed core, SDK, launcher and growth qualification remains
valid for those recorded runs. The merged PR #169 tree separately passes all
13 hosted experience tasks, including SQL lifetimes, direct Table faults and
installed SQL recovery. Later passes do not identify historical SQL failure
causes or replace their original incomplete outcomes.

The physical reactive and hosted Board browser failures remain open in #124;
the startup logging failure remains open in #171.
The first is an end-to-end application serving workflow: a diagnostic observes
the same original operation completing after 17.917 seconds, beyond the test's
ten-second assertion. The second fails a five-second visibility assertion during
resuming an existing captured query, with the UI still checking current evidence.
Neither result is reported as a passed browser suite or used as an isolated
Table latency measurement. Further application-runtime performance work is not
added to the lifecycle foundation; installed cutover and broader performance
retain milestones 3 and 10 and their existing proof requirements.

No actor performance change, deadline increase or fallback data authority is
part of this close-out. No failed or incomplete proof is labelled as passed.
The accepted scope combines independent contract, direct caller, recovery and
current-policy evidence; contract checks alone are not its installed proof.

Linked component issues #111/#112/#119/#120 are already closed. This review
reconciles #108's delivered lifecycle scope while preserving unfinished
work in #118/#122/#123/#124/#125/#126. Remaining storage/maintenance integration,
transactions, online indexes, WAL-driven managed computation and provider
expansion keep their explicit later owners.

Only the main worktree is registered. The merged feature branch is removed;
the current documentation branch, user notes, original unpublished branch and
the separate storage checkout are preserved.
Compiler caches are removable only as rebuildable outputs; original uncertain
fixtures and source-attributed evidence remain preserved.

PR #172 subsequently merges as `ceb109a03`, including the shared backend mutex
correction, native allocation/collection guards and synchronized disk-facade
confirmation counters. It extends bounded Table execution and retained storage
maintenance and changes the current-v1 definition. The acceptance records above
retain their earlier source/definition attribution; they do not qualify that new
definition or establish compatibility with it. The storage work retains its own
integration and qualification obligations. Current supported collation behavior
is in the [Table reference](../handbook/reference/tables.md#schemas-and-identities),
including SQL `UTF8_BINARY`, `ASCII_CI` and `EBCDIC_CP037` comparisons added by
that later change.

The dated sections below preserve earlier checkpoints and their then-open work.
Use the final acceptance review above for the current disposition.

## Reopened assessment — 2026-10-22

Source review of local snapshot `a0a8a3ed`
found that [PR #105](https://github.com/spoke-sh/transit/pull/105) delivered
column encoding/collation descriptors, Table preview/lifecycle observations,
dependency/policy inspection, a `TableClient.apply` convenience API and named
KV/Document/computation metadata transitions. Retain that work and its scoped
[component evidence](../history/qualification/storage.md#declarative-data-lifecycle-codecs-and-collations).
Existing Table CRUD and native authorization/recovery predate this milestone.

At that snapshot, the executable acceptance path was incomplete.
`TableClient.apply` drove actor sends, uploads and continuations. Named
KV/Document publication recorded a supplied resource ID without establishing
provisioning or initialization. Computation completion was not bound to verified
result evidence, and schema revision comparisons did not establish freshness
after row changes. Metadata transitions alone did not fulfill a data declaration.

| Remaining work                                                             | Tracking issue                                         |
| -------------------------------------------------------------------------- | ------------------------------------------------------ |
| Direct Table operations and one acceptance/visibility/recovery protocol    | [#111](https://github.com/spoke-sh/transit/issues/111) |
| Catalog/branch identities, transaction domains and durable snapshot roots  | [#125](https://github.com/spoke-sh/transit/issues/125) |
| Real named KV/Document provisioning, initialization and lifecycle recovery | [#119](https://github.com/spoke-sh/transit/issues/119) |
| Computation results, dependencies and data-source freshness evidence       | [#120](https://github.com/spoke-sh/transit/issues/120) |
| Executable codec/collation semantics behind declared descriptors           | [#118](https://github.com/spoke-sh/transit/issues/118) |
| Coordinated current-v1 definition and artifact cutover                     | [#112](https://github.com/spoke-sh/transit/issues/112) |
| Accurate current documentation and scoped proof claims                     | [#123](https://github.com/spoke-sh/transit/issues/123) |
| Public caller, failure, growth and recovery qualification                  | [#124](https://github.com/spoke-sh/transit/issues/124) |

The issues retain their original work and proof obligations. #125 and the
neutral contract portions of #111/#119/#120 belong here; executable direct Table,
named resource and computation integration belongs to
[milestone 3](03-live-storage-and-sql-cutover.md#installed-lifecycle-integration).
Native codec execution stays with [storage](02-storage-and-query-performance.md).
Automatic scheduling remains later scope.
The transcript review is complete and this planning revision is authorized.
The [shared contract gates](README.md#firm-scope-and-contract-gates) identify
engineering decisions that must precede dependent implementation.

## Current implementation review — 2026-10-24

The original executable scope remains part of this branch's acceptance review
despite the sequencing split. The following is the current checkpoint; the
implementation record below preserves earlier, narrower checkpoints and their
then-open work.

| Obligation | Implemented outcome and executed evidence | Open qualification |
| --- | --- | --- |
| Direct Table lifecycle (#111) | One direct owner accepts point/batch CRUD and DDL, with current policy, exact retry bindings and retained reads. [Public CRUD/DDL](../history/qualification/catalog.md#direct-table-crudddl-recovery--2026-10-23), [selected-role/default-grant checks](../history/qualification/catalog.md#direct-table-selected-role-boundary--2026-10-24), [SQL recovery](../history/qualification/sql.md#direct-sql-ledger-recovery-and-pin-authority--2026-10-24) and [139-Table growth](../history/qualification/catalog.md#direct-catalog-growth-and-retained-rows--2026-10-24) pass. | Final combined clean-checkout suite. Provider/concurrent-writer expansion stays with milestone 15. |
| Named usable KV/Document resources (#119) | [Allocation and initialization](../history/qualification/catalog.md#named-native-resource-allocation-and-initialization--2026-10-24), [dependency/lifetime recovery](../history/qualification/catalog.md#named-resource-dependency-authority-and-retirement--2026-10-24) and [shared host recovery](../history/qualification/sdk.md#direct-host-named-resource-recovery--2026-10-24) use real native resources and current rights. The [public 139-edge dependency schedule](../history/qualification/catalog.md#public-dependency-graph-growth-and-restart--2026-10-24) and [139 initialized resource growth/restart schedule](../history/qualification/catalog.md#public-named-resource-growth-and-restart--2026-10-25) pass. | Final combined clean-checkout suite and linked issue review. |
| Actual computation evidence (#120) | [Result/source attribution](../history/qualification/query.md#result-source-freshness-and-named-attribution--2026-10-23), [named publication](../history/qualification/query.md#named-query-dependency-publication-and-retirement--2026-10-24), captured and maintained recovery, and current disclosure denial pass. [Reference Follow](../history/qualification/query.md#direct-follow-reference-recovery-and-disclosure--2026-10-25) passes with an explicit six-minute correctness wait. Inspection does not activate execution. | Final combined clean-checkout suite. Earlier reference latency failures remain recorded. Automatic scheduling remains milestone 9. |
| Coordinated current-v1 cutover (#112) | The [superseded actor Table owner is removed](../history/qualification/catalog.md#direct-catalog-hard-cutover-and-retired-owner--2026-10-24); current consumers, bindings and fixtures use the shared definition. [Installed SDK selected-role checks](../history/qualification/sdk.md#direct-catalog-sdk-selected-roles--2026-10-24) and [nine compiling mutation probes](../history/qualification/catalog.md#direct-catalog-mutation-checks--2026-10-24) pass. | Final combined clean-checkout suite. Existing data still requires its matching build; there is no fallback decoder or automatic reset. |
| Identity, atomicity and snapshots (#125) | The executable domain is one Table statement/batch with retained WAL-inclusive cuts and explicit independent source vectors. [Competing checkpoint/pin evidence](../history/qualification/storage.md#snapshot-pins-against-competing-checkpoints--2026-10-24) passes. The [selected transaction extension](#selected-transaction-session-extension) specifies the later consistent-cut and multi-Table decision protocol. | Transaction-session implementation and anomaly/failure histories belong to milestone 5; this design decision does not qualify them. |
| Neutral index contract foundation (#108) | [Index declarations and coverage](../../contracts/INDEX_LIFECYCLE_V1.md) bind immutable source/key/constraint semantics, build generations and exact snapshots. [Independent commitments and protocol checks](../history/qualification/catalog.md#neutral-index-contracts--2026-10-25) pass, including WAL-only coverage and stale-cut refusal. | Final repository and committed-checkout qualification. Installed index operations, secondary structures and online lifecycle remain milestone 8. |

The earlier combined repository check passes with the client fix for opaque upstream
503 responses and ordinary native-contention recovery in application workers,
including contracts, diagnostics, units, frontend and handbook build.
[Work Items, Station and the native browser](../history/qualification/runtime.md#native-worker-contention-and-exact-recovery--2026-10-25)
pass with the worker fixes. Native Follow reload/credential rotation and
root/prefixed handbook browser checks also pass. Named-resource growth/restart and
reference Follow now pass. Final acceptance still requires the latest combined
repository check, committed-HEAD `just ci-clean`, and a linked
issue review. #123/#124 retain their broader storage/provider/performance scope;
this lifecycle review does not close those obligations wholesale.

## Close-out checkpoint — 2026-10-26

The lifecycle implementations and subsequent fixes through
[PR #159](https://github.com/spoke-sh/transit/pull/159) and
[PR #161](https://github.com/spoke-sh/transit/pull/161) are merged. The latter
removes the reproduced Debug decimal-rescaling crash; the
[focused regression evidence](../history/qualification/runtime.md#debug-decimal-argument-alignment--2026-10-26)
preserves the failing case and unchanged arithmetic/result assertions.
The clean growth run at `a756f2cf4` has passed file queries, logical Arrow,
logical codecs, immutable pages and growing-authority recovery; the containing
lane is incomplete.

The active qualification follow-up addresses three observed fixture/profile
problems without expanding lifecycle scope:

- [CLI configuration discovery](../history/qualification/interfaces.md#cli-discovery-fixture-environment--2026-10-26)
  filters ambient XDG state while preserving explicit precedence tests.
- [Installed Station SDK queries](../history/qualification/sdk.md#sdk-query-node-build-profile--2026-10-26)
  use a ReleaseSafe node with Debug bindings/hosts. The Python control passes
  the unchanged workload and deadline; complete clean SDK lanes remain pending.
- Installed SQL observes account discovery within the existing readiness
  deadline and permits both database clients to repeat only the fixed finite
  COUNT observations after an explicit capacity refusal with no disclosed rows.
  Writes, reloads, partial results and generic failures are not retried by that
  helper. The installed rerun and the separate hosted generic SHOW failure
  remain open qualification work.

Stale owned checkout cleanup is complete: six inactive worktrees and 26
superseded branches were removed after archiving their history and 442 proof/
package artifacts. The current worktree, original unpublished implementation
branch, user notes and separate storage checkout remain intact. Recovery paths
and archive hashes are recorded in [#124](https://github.com/spoke-sh/transit/issues/124).

Completion still requires the combined repository check, complete committed
clean-checkout qualification, and the acceptance/linked-issue review. Component
issues #111/#112/#119/#120 are closed; #108 stays open until those final gates
are met. #123/#124 retain their broader obligations, and later transaction,
index, scheduling and provider work keeps its existing delivery owner.

The subsequent close-out branch includes merged PR #162 and the shared-definition
cutover in PR #163. [SQL settings observation recovery](../history/qualification/sql.md#sql-settings-observation-recovery--2026-10-26)
now passes forced preparation/page failures through both database protocols,
with unchanged cursors, current denial, snapshot-change rejection and original
reload identity. Full installed SQL remains a separate gate. The clean SDK run
at `dd3687e01` passes Python's Station, HTTP and gRPC schedules; its catalog and
remaining language schedules are not yet complete. The clean growth run at
`a756f2cf4` passes local catalog and direct Table restart recovery, then exceeds
the 180-second lifecycle phase budget. The experience run at `0a7fcbb83` reports
an unknown console outcome during ALTER TABLE RENAME; original-outcome diagnosis
remains open. None of those partial lanes is a full pass.

The acceptance review of #125 now distinguishes delivered identity/statement
contracts and the selected transaction design from its remaining concrete
transaction fixtures, later implementation histories and final qualification.
It remains open. Older proof runs retain their source definitions; qualification
after PR #163 requires a matching runtime/fixture set throughout.

After merged PR #164, the follow-up closes two focused observation gaps:
[control preparation and console status](../history/qualification/sql.md#sql-observation-budgets--2026-10-26)
retain the original deadline through temporary authority failures. The full
[direct Table lifecycle proof](../history/qualification/catalog.md#paged-table-history-observation--2026-10-26)
now passes both history replays and closure within the unchanged 180-second
phase budget, using bounded history pages and the original one-page native
cache. Charged requests decrease from 300 to 210 per replay; this is not a
matched latency benchmark.

The clean core run at `e3cbe9cca` fails only the independent work-item fixture
checks in its root unit stage; it does not complete the core lane or queued
repository check. The [regenerated current-definition fixture](../history/qualification/catalog.md#work-item-command-definition-cutover--2026-10-26)
passes its generator and focused application unit suite. Contract tasks now
include that fixture. Clean bindings-1 at `dd3687e01` passes the complete Python
task and Node's client/Station/HTTP/gRPC schedules, then fails relational setup
on an unknown direct-operation outcome. The fixture follow-up inspects that
original saved operation and includes a deterministic lost-reply case. The
[installed Node relational rerun](../history/qualification/query.md#relational-setup-outcome-recovery--2026-10-26)
passes with matching packages, native/port callers, retained cuts, current denial
and replacement. The containing SDK lane still needs a complete rerun.
Broader C/C++ and Java progress remains
source-specific until their containing lane finishes.

Installed SQL is still an open gate. Later public observation recovers original
INSERT 216 and RENAME 348 as applied without SQL resubmission. Original CREATE
155 remains uploading and execution-ineligible after restart. Two subsequent
installed native controls fail during startup on authority timeouts, before
the test SQL runs. These failures remain recorded; focused observation fixes
do not establish their historical causes or close combined qualification.

The later clean core check at `9ab5fb64a` passes in 1,877.37 seconds; its
containing lane and queued full repository check remain incomplete. Hosted
qualification of merge revision `7afcbcc7f` passes the complete launcher lane
and eight experience tasks, including installed direct SQL, fault recovery and
session lifetimes. The experience lane then fails on an explicit capacity
refusal during its Unicode read check. The fixture now gives its four fixed
finite data observations the same bounded, empty-result capacity handling;
writes and partial results are excluded. Current-source reruns remain required.

Local node diagnostics identify a cancelled native append followed by
`WalRecoveryRequired` and supervisor replacement. A separate
[deterministic regression](../history/qualification/storage.md#wal-append-inspection-cancellation--2026-10-26)
proves and fixes premature owner poisoning when existing-segment inspection is
cancelled before any write. It preserves all uncertain-write recovery gates;
the installed trace does not locate its cancelled syscall. The supervisor now
retains native attempt diagnostics, and the installed fixture preserves the
original failure and allows the existing 270-second settlement budget to finish.
These corrections are not a completed installed or combined qualification.

PR #167 is merged as `dc2838b6c`. The subsequent full `just check` at
`9ab5fb64a` passes, and clean bindings-2 at `90b0fc45e` completes Go, C/C++,
Java, .NET, Erlang and Elixir. Their
[source-specific records](../history/qualification/verification.md#installed-lifecycle-qualification-checkpoint--2026-10-26)
preserve the distinction between those earlier revisions and qualification of
the final merged implementation. The remaining core run fails Station's
captured-query deadline after 18 passing tasks. A
[controlled node-profile substitution](../history/qualification/query.md#station-node-build-profile--2026-10-26)
passes with the same Debug callers and unchanged deadlines; the owning task now
uses the explicit ReleaseSafe node profile already used for SDK queries.

Current-source installed SQL reaches name reuse after deletion and restart,
then reports an unknown CREATE outcome during native failure and supervisor
restart-budget exhaustion. The original SQL is not resubmitted. The hosted
launcher lane passes at `e4b4955cb`, whose Git tree is identical to merged
`dc2838b6c`; other hosted lanes remain in progress. Final installed recovery,
combined qualification and acceptance reconciliation remain open. #108 and
this milestone remain In Progress.

PR #168 is merged as `310a3f25e`. The full repository check and committed-HEAD
clean launcher lane now pass; the [qualification record](../history/qualification/verification.md#installed-lifecycle-qualification-checkpoint--2026-10-26)
retains their exact sources. Original CREATE 751 remains incomplete publication
after public inspection; it is not resubmitted or reported as applied. A fresh
full direct Table diagnostic passes with the same binaries. The normal hosted
task also passes at the identical source tree.

Hosted experience then passes all nine tasks through standalone SQL authentication,
but its installed source-bundle SQL task fails because the runner-selected MySQL
client rejects an isolation option before connection. The
[pinned-client correction](../history/qualification/interfaces.md#installed-sql-client-selection--2026-10-26)
adds the existing locked PostgreSQL/MySQL packages to that CI shell. Doctor,
client selection and the complete installed authentication/recovery task pass;
versions, assertions and deadlines are unchanged. Remaining combined lanes and
final acceptance reconciliation still gate closure.

PR #169's hosted run passes twelve experience tasks, including installed SQL
authentication/recovery and Board query recovery, before the final Station
launcher import exposes a second missing CI dependency, PyArrow. Supplying the
existing pinned package makes the complete Station launcher task pass in that
shell. Two hosted bindings-2 runs also pass with the current shared definition.
The [follow-up record](../history/qualification/verification.md#installed-lifecycle-follow-up-and-station-ci-dependency--2026-10-26)
retains these passes alongside a separate failed clean SQL run: original UPDATE
194 remains incomplete publication after inspection, with no SQL resubmission.
Combined qualification and acceptance reconciliation remain open.

The earlier hosted growth lane then fails its unchanged 139-resource writer's
90-minute deadline after nineteen passing tasks. Replaying the complete catalog
history for every direct request produces growing validation work. The follow-up
retains one validated root/chain value within the live local owner; initial
recovery, new-history validation and current authorization remain required.
The [catalog recovery record](../history/qualification/catalog.md#catalog-prefix-reuse--2026-10-26)
records 75 passing component tests, signed native/concurrency checks and the
complete unchanged 139-resource growth/restart schedule. This fixes an
implementation gap, not another CI dependency.

The corrected CI shell completes all thirteen hosted experience tasks, including
SQL and Station recovery. Its subsequent browser proof rejects a query asset
above the existing size limit. The
[current qualification record](../history/qualification/verification.md#installed-lifecycle-qualification-after-ci-prerequisites--2026-10-26)
also retains completed core and both SDK lanes at their exact earlier sources,
and the separate failed local lifetime run. Final candidate qualification and
acceptance reconciliation remain open.

Removing unused generated-validator error prose brings that query asset below
the unchanged bound. The complete
[embedded browser schedule](../history/qualification/interfaces.md#compact-standalone-validator-output--2026-10-26)
passes inspection and the direct worksheet, including replacement, original-pin
recovery and current denial. Public validation and Transit diagnostics retain
their existing semantics.

Committed-HEAD clean experience at `e550f4ed5` then passes five tasks and times
out on the installed Table proof's post-restart DELETE/DROP batch. Signed
inspection of the original installation confirms DELETE 647 applied one change;
subsequent operation 695 remains incomplete publication and is not resubmitted.
Two fresh full-workload diagnostics pass with unchanged assertions and deadlines,
including one with temporary WAL error labels. Neither reproduces the poisoned
WAL owner or establishes the historical failure's exact cause. The
[original outcomes and diagnostic evidence](../history/qualification/catalog.md#installed-table-qualification-and-original-outcomes--2026-10-26)
preserve that distinction. Final combined qualification and acceptance remain
open; no WAL recovery gate is relaxed to obtain a pass.

The current hosted candidate completes core, launchers, all thirteen experience
tasks and both SDK groups. Its browser inventory stops before HTTP execution
on a missing CI dependency. Supplying the existing pinned MinIO and gRPC peer
packages qualifies HTTP and gRPC locally. The independent reactive fixture now
reopens native local persistence, explicitly restores source rights after private
role replacement, and signs current subject proofs. Protocol/browser, live views
and shared-tab lifecycle tasks pass, including current denial with preserved
accepted-control uncertainty. The [qualification record](../history/qualification/runtime.md#browser-prerequisites-and-native-reactive-cutover--2026-10-26)
retains the preceding failures, exact sources and unchanged authority/deadline
limits. Full repository checks and hosted growth now pass. A clean browser run
then exposes a test assumption that only one upload step can require explicit
unknown-outcome recovery. The [corrected complete focused schedule](../history/qualification/query.md#explicit-recovery-of-each-query-upload-step--2026-10-26)
passes two distinct accepted-reply losses with exact recovery, unchanged runtime
semantics and existing deadlines. Committed-HEAD clean browser qualification and
final acceptance reconciliation remain open.

PR #169 is merged as `17b73b4f2`. The next clean browser run at `717f55793`
passes embedded Board, query-browser, HTTP and gRPC, then fails reactive-browser:
the original serving operation remains admitted at its ten-second completion
deadline. The final two tasks do not run. A source-matched physical-disk control
reproduces the failure; a tmpfs control passes without establishing physical
durability. The [physical qualification record](../history/qualification/verification.md#physical-reactive-qualification--2026-10-26)
preserves that distinction and the failed frozen-read experiment. Work continues
on `fix/lifecycle-final-qualification`; combined qualification remains open.
The separate hosted SQL lifetime failure now has bounded stderr diagnostics,
but its historical cause is not yet established.

### Close-out scope reconciliation — 2026-10-26

The data plane accepts Table operations through its own WAL-backed owner;
Station actors belong to application execution. Row storage, ingestion and
scans must not acquire actor-turn or mailbox dependencies. The existing
[foundation completion criteria](#completion-evidence) and the
[installed integration owner](03-live-storage-and-sql-cutover.md#installed-lifecycle-integration)
remain distinct. Broad repository checks reveal regressions, but do not make
every application-runtime latency target a new lifecycle-foundation obligation.
Their failed results must remain visible with an explicit owner and disposition.

The shared local backend's private-object mutex correction supports both direct
Table storage and native control persistence. It preserves the intended owner
boundary and is not an optimization of the retired actor Table implementation.
The reactive timeout, however, measures a serving application coordinating a
direct Table mutation through its own durable application turns. A diagnostic
with that correction observes the original accepted operation completing after
17.917 seconds, beyond the fixture's ten-second assertion. It establishes neither
a passing browser suite nor a direct Table latency measurement. Further serving
workflow/lease timing work stays in the broader #124 qualification; milestone 3
retains installed cutover obligations and milestone 10 owns broader runtime
performance. No runtime deadline or assertion is weakened by this classification.

Close-out must reconcile the delivered lifecycle/contract evidence, current
data-plane safety and recovery, and transferred installed obligations. Unknown
SQL failures still require classification before they can be assigned or
resolved; they cannot be dismissed as application latency without evidence.

## Implementation record

These paragraphs record intermediate implementation states. References to
remaining consumers or unrun checks describe their checkpoint; use the current
review above and the linked proof ledger to assess what remains open now.

The [direct SQL ledger schedule](../history/qualification/sql.md#direct-sql-ledger-recovery-and-pin-authority--2026-10-24)
passes independent Table acceptance and native control recovery, exact lost-reply
handling, fencing, parameterized reads and shared self-join pins. Configured Table
sources now use independent data/progress identities, journaled interactive pins
and explicitly authorized captured cuts. The full session/placement schedules
and superseded actor-Table removal remain open.

The [unified recovery schedule](../history/qualification/catalog.md#unified-direct-table-recovery-and-closure--2026-10-24)
now uses independent direct Table storage and native query progress. Native ABI
and port checks pass exact upload/result recovery, unflushed point data,
released-pin refusal, partial COUNT recovery, cancellation and retained failure
diagnostics through node/worker replacement. The shared KV regression passes.
Older catalog/SQL fixture migration and the final repository gates remain open.

Flight and the public captured-query fixtures now use the direct Table owner
with independent native progress storage. Their
[native consumer evidence](../history/qualification/query.md#direct-flight-and-captured-query-consumers--2026-10-24)
covers exact capture retry across row changes, failure/restart recovery, current
denial and stored-schema validation. Board's captured-query API uses explicit
capture; its browser now qualifies navigation, lost submission, current denial
and restored access with independent data/progress identities. Flight's Compose
and reference placements also pass physical recovery with PyArrow and both ADBC
consumers. Removal of the remaining actor-Table consumers remains open; this does not close the
coordinated cutover gate.

The serving counter now uses an installer-published direct Table and retains an
exact intent before dispatch. Its separate data receipt and native progress/reply
commit have [component, HTTP and TLS refresh recovery evidence](../history/qualification/runtime.md#direct-serving-counter-acceptance--2026-10-24).
The refresh proof uses separately prepared direct captures, retains the original
request through worker replacement and enforces current Table SELECT. TLS,
capacity, lifetime and retained growth qualification also pass. The native browser
now verifies direct Follow results and denial between verification and disclosure.
The [multi-tab browser schedule](../history/qualification/query.md#direct-follow-browser-lifecycle--2026-10-24)
also passes stream-loss recovery with the original basis, independent sessions,
watch-generation reset, explicit resnapshot and denial after catalog lifetime
retirement. A recorded watch-change rejection stops renewal instead of being
retried as a temporary disconnect.
Reload/credential-rotation and placement qualification remain open; this does not close the
coordinated consumer cutover gate.

The feature branch supplies the neutral data operation/snapshot contract, local
native persistence and a default local launcher backed by the native local
owner. Its direct Table storage component has atomic point/bulk acceptance,
paged row/receipt/pin indexes, bounded flushes, durable read pins and
CREATE/ALTER/RENAME/DROP definition transitions under the existing native
authorization fence. The scoped [executed evidence](../history/qualification/catalog.md#table-definition-acceptance-and-retained-interpretation--2026-10-22)
distinguishes these component and native-adapter checks from public integration.

The direct catalog component now reserves names and records durable DDL
admission/rejection/cancellation, with name visibility governed by the Table
acceptance record. Its [component evidence](../history/qualification/catalog.md#direct-catalog-reservations-and-table-publication--2026-10-22)
covers lost replies, restart, replacement and growth beyond the resident cache.
The Table owner also retains frozen row work, durable admission/rejection/
cancellation, matched/changed counts and atomic primary-key replacement. Its
[component and native policy evidence](../history/qualification/catalog.md#durable-table-row-admission-and-outcomes--2026-10-22)
covers restart, lost replies, quota pressure and current rights. A configured
local node now serves signed typed requests directly over HTTP and resumes native
registration under the original caller's fence. The [public HTTP proof](../history/qualification/catalog.md#direct-table-http-owner-and-typed-caller--2026-10-22)
covers a 64 KiB point row, bulk `.tseg` publication, exact lost-reply recovery,
restart, an unflushed retained pin and current revocation. Its subsequent
[CRUD/DDL recovery run](../history/qualification/catalog.md#direct-table-crudddl-recovery--2026-10-23)
also covers UPDATE, DELETE, ADD COLUMN, RENAME, DROP and name reuse with retained
schemas and exact outcomes across a second restart. [Read-only DDL preview](../history/qualification/catalog.md#direct-table-preview--2026-10-23)
checks current policy, expectations and schema work without claims or admission.
The [typed finite SQL owner](../history/qualification/sql.md#finite-sql-over-retained-direct-tables--2026-10-23)
now executes Fuze filtering/aggregation over retained direct sources with current
disclosure checks. The direct Table owner also accepts frozen typed SQL
UPDATE/DELETE plans with bounded private selection and one atomic outcome.
Read-only exact-definition and action checks support prepared bindings without
raw-storage inspection credentials. Parameterized DML templates produce complete
saved direct intents with explicit admission and recovery.

The [shared DDL preparation proof](../history/qualification/catalog.md#shared-direct-table-ddl-preparation--2026-10-24)
now puts SQL and typed CREATE/ALTER/RENAME/DROP binding in one direct caller
owner. Independent operation/object identities, saved work after template
disposal, stale-definition rejection and original receipts after retirement pass
through the public service. The general Table ABI and existing language catalog
adapters now use this owner; the remaining application consumers are listed below.
Its [lossless caller reference contract](../history/qualification/sdk.md#lossless-direct-caller-references--2026-10-24)
now defines exact prepared bindings and saved-work references with independent
full-width identity fixtures. The [shared direct caller session](../history/qualification/sdk.md#shared-direct-caller-session--2026-10-24)
also passes public lookup, SQL compilation, saved-work restoration and explicit
staging/admission/recovery, including receipt inspection after DROP and local
forgetting. [Typed declaration/batch preparation](../history/qualification/sdk.md#typed-direct-caller-preparation--2026-10-24)
now shares that path and passes a nine-row bulk request larger than an actor
mailbox frame, exact prepared-definition rejection and conditional DROP.
[Shared preview](../history/qualification/catalog.md#shared-direct-preview--2026-10-24) now
reports current DDL, row and conditional-name checks without staging, claims or
acceptance, including stale data/definitions and native revocation.
[Host catalog inspection](../history/qualification/sdk.md#direct-host-catalog-inspection--2026-10-24)
also supplies capabilities, descriptions and bounded namespace/Table pages with
exact connection/selection cursors and changed-directory rejection.
[Host namespace and policy preparation](../history/qualification/sdk.md#direct-host-namespace-and-policy-preparation--2026-10-24)
now preserves saved namespace bindings through explicit execution and returns
the native authorization owner's signed policy record without submission.
[Host dependency recovery](../history/qualification/sdk.md#direct-host-dependency-recovery--2026-10-24)
now preserves original saved bindings across corrupted replies and restart,
distinguishes current graph membership from old receipts, and shares the native
bounded inspection and current-rights checks.
[Host named resource recovery](../history/qualification/sdk.md#direct-host-named-resource-recovery--2026-10-24)
now reuses the same allocation/initialization/publication owner and preserves
saved host bindings through eight resource reply faults and eleven restarts,
including current data denial, actual writes and metadata retirement.
The [direct catalog ABI and port proof](../history/qualification/sdk.md#direct-catalog-abi-and-port-recovery--2026-10-24)
now uses the same owner for wide typed work and original receipt recovery. Its
extended run passes exact snapshot acquisition/status/metadata/release through
lost replies, caller loss and four abrupt node replacements. Retained metadata
keeps the accepted schema and interpretation after DROP/name reuse. The shared
definition and generated artifacts are being cut over together. The C ABI and
port now also pass explicit retained relational reads and current cached/terminal
revocation in 233 public requests. The [installed Python proof](../history/qualification/sdk.md#installed-python-direct-lifecycle-and-retained-sql--2026-10-24)
passes 393 public requests through both synchronous and asynchronous clients,
including six caller/node replacements and unchanged original recovery bindings.
The [installed TypeScript proof](../history/qualification/sdk.md#installed-typescript-direct-lifecycle-and-retained-sql--2026-10-24)
passes the same schedule through its packaged native port in 197 public requests
and three caller/node replacements. The [installed Ruby proof](../history/qualification/sdk.md#installed-ruby-direct-lifecycle-and-retained-metadata--2026-10-24)
passes 78 public requests, three caller/node replacements, original receipt and
retained-metadata recovery, exact mutation counts and current revocation. Ruby's
proof does not establish interactive relational reads. The [installed Java proof](../history/qualification/sdk.md#installed-java-direct-lifecycle-and-retained-metadata--2026-10-24)
also passes 78 public requests and three replacements, with explicit original
retention and joined future/child ownership. Its scope is retained metadata.
The [installed .NET proof](../history/qualification/sdk.md#installed-net-direct-lifecycle-and-retained-metadata--2026-10-24)
also passes 78 public requests and three replacements, with original recovery
values, retained metadata and joined native worker disposal.
The [installed Rust proof](../history/qualification/sdk.md#installed-rust-direct-lifecycle-and-retained-metadata--2026-10-24)
passes 78 public requests and three replacements, with 14 library tests and
compile-time ownership rejection. It also checks retained metadata; the
wide-intent run exposed and corrected a raw-client bound reused by the decoder.
The [installed Erlang/Elixir proof](../history/qualification/sdk.md#installed-erlang-and-elixir-direct-lifecycle--2026-10-24)
passes 155 public requests and six replacements across both APIs, including
current retained-metadata authorization and joined cleanup after waiting-process
loss. The [installed C/C++ proof](../history/qualification/sdk.md#installed-c-and-c-direct-lifecycle--2026-10-24)
passes 152 public requests and six replacements through independently installed
C11 and C++17 consumers, plus 77 native-boundary cases for complete bindings,
unknown outcomes and joined POSIX cancellation. It also checks retained metadata.
The [direct Board recovery proof](../history/qualification/interfaces.md#direct-board-relational-recovery--2026-10-24)
now passes 504 public requests and the embedded Chromium worksheet. Original pin
requests survive lost replies, node/Board replacements and credential rotation;
stale explanation, browser reload, cached/terminal denial and explicit cleanup
are qualified. Remaining actor consumers, Follow/placement schedules and the
final combined SDK and repository gates are unfinished. The milestone remains
In Progress.

The [retained relational caller conformance run](../history/qualification/query.md#retained-relational-caller-conformance--2026-10-24)
replaces the older actor-backed relational caller fixture. It passes native ABI,
native port and installed Python sync/async joins in 1,390 public requests, and
installed TypeScript in a separate 1,087-request run. Shared self-join retention,
current denial, explicit reopening after caller loss, node replacement, output
budgets and ordered overflow pass. This is independent Table-cut evidence; it
does not promise a cross-Table atomic snapshot.

SQL's control ledger now publishes exact intent references and commits dispatch
eligibility before direct admission, replacing its actor row-upload/saved-step
path. Its current session adapters use direct prepared reads and mutations.
A durable local pin journal preserves interrupted acquisitions and closure;
relational reads use stable row-identity traversal and explicit independent Table
cuts. [Recovery and binding evidence](../history/qualification/sql.md#direct-sql-references-and-read-recovery--2026-10-23)
covers those component and HTTP paths, including lost pin replies, replacement,
current denial and definition changes that preserve column schemas.

Conditional name-only DDL now has a distinct catalog assertion path and SQL
ledger representation; it carries a catalog acceptance position without
fabricating a Table commit. Its [component and HTTP evidence](../history/qualification/sql.md#conditional-sql-catalog-outcomes--2026-10-23)
covers the SQL compiler, lost replies, restart, cancellation and name reuse.

The default launcher now provisions the direct catalog with a dedicated native
registrar and retains the exact initial Table intent. The
[installed proof](../history/qualification/catalog.md#installed-direct-table-bootstrap--2026-10-23)
passes CRUD/DDL while the query worker is stopped, abrupt restart and deliberate
default-Table deletion/name reuse. A separate
[execution fault proof](../history/qualification/runtime.md#installed-direct-execution-recovery--2026-10-23)
keeps new-console inspection, reads and cancellation available while direct
execution is refused, preserving the original write across caller/manager loss.
The [broader installed lifecycle and capacity proofs](../history/qualification/catalog.md#installed-direct-lifecycle-rollback-and-capacity--2026-10-23)
also pass against the direct boundary, including revocation, native-history
rollback refusal and original-write recovery after physical exhaustion.
The [physical representation proof](../history/qualification/sql.md#lossless-physical-column-admission-and-public-sql--2026-10-23)
now checks supported codec ranges, complete CP037 conversion, signed floating
zero, unsupported-profile rejection and SQL equivalence over retained WAL/segment
cuts. Incompatible physical schemas/pages use replaced current-v1 definitions.
The [neutral-schema caller proof](../history/qualification/sdk.md#neutral-physical-schemas-across-language-callers--2026-10-23)
now preserves explicit encoding/collation fields across ten language bindings,
with independent bytes/fingerprints and strict missing-field rejection. Non-binary
SQL collation remains unsupported.
The [administration and database-client proof](../history/qualification/interfaces.md#direct-catalog-administration-and-installed-database-clients--2026-10-23)
also resolves policy plans through the direct catalog and qualifies explicit
grants/revocation and retained recovery through real PostgreSQL/MySQL clients.
The [scoped read-delegation proof](../history/qualification/catalog.md#scoped-direct-table-read-delegation--2026-10-23)
now qualifies original-caller grants for one executor, exact Table cut and pin
owner, including uncertain acquisition/closure and retained reads after restart.
The [captured-query recovery proof](../history/qualification/query.md#direct-captured-table-queries-and-separate-cleanup-authority--2026-10-23)
now covers single-source admission, independent progress storage, original-cut
traversal, verified results and cleanup across lost replies and replacement.
Fresh cleanup authorization remains separate from the original execution proof
after credential rotation. The [current-capture cleanup proof](../history/qualification/query.md#current-capture-cleanup-after-definition-changes--2026-10-23)
also distinguishes permanent absence after ALTER from an older accepted pin that
still needs release, including current denial and delayed retries after restart.
All ten installed SDKs now resolve direct definitions,
seal the same captured bundle and read its verified result through that fault
schedule. The captured relational owner now uses the same direct pin protocol
with independent native progress. Its scoped self-join and two-Table proofs pass
replacement, shared alias retention, independent Table partitions, cleanup and
current-source revocation/restoration at result disclosure. Retained source pages
also preserve nested/wide values through Fuze/Arrow after ALTER, DROP and name
reuse, including direct composite-key hit/absence under current rights.
The direct storage/service boundary now has explicit history leases, fixed-bound
logical acceptance pages and exact historical reads. Its
[storage and native-policy evidence](../history/qualification/catalog.md#direct-table-history-retention--2026-10-23)
covers restart, no-ops, retention-kind separation and current revocation.
The public `TableChangeReader` now uses the same direct history owner. Its
[checkpoint and replay proof](../history/qualification/catalog.md#direct-table-change-reader-checkpoints--2026-10-24)
covers paused backfill, saved original leases across restart, complete no-op and
schema transactions, partial-delivery replay, insert/delete scan cursors and
current denial. Local reader closure remains separate from durable release.
The maintained-query adapter now uses those direct history leases and stores a
separate bounded physical scan cursor. Its [public recovery evidence](../history/qualification/query.md#maintained-direct-table-queries--2026-10-23)
covers original acquisition recovery, restart inside a physical-only prefix,
initial backfill, independent Table cuts, accepted no-op revisions, paired deltas,
terminal lease cleanup and current result-disclosure rights. The
[direct failure schedule](../history/qualification/query.md#direct-relational-failure-boundaries--2026-10-23)
also covers work/spill limits, ordered overflow witnesses, prior-result
preservation, explicit history-coverage rejection and bounded captured cleanup.
The [direct exchange proof](../history/qualification/deployment.md#direct-table-exchange-placement-and-borrowed-reads--2026-10-23)
now places the receiver independently of Table ownership and uses exact-cut
borrowed reads for a separate producer credential. Initial and successor
attachments with one/seven partitions, receiver generation replacement, retained
request retirement, verified output and lease cleanup pass. A separately accepted
rebuild also succeeds after a failed history gap while preserving the original
failure and result. Multiple workers, broader exchange recovery and maintained
credential-rotation cleanup schedules, older relational
caller fixtures and broader qualification remain unfinished. The
[query fixture migration](../history/qualification/query.md#direct-maintained-successors-and-query-fixture-migration--2026-10-23)
passes all 143 query package tests; this does not establish full repository or
installed caller qualification.
The [finite capture boundary checks](../history/qualification/query.md#finite-direct-capture-memory-and-retirement--2026-10-23)
now replace the old Table memory/retirement fixtures. They cover empty retained
sources after DROP, adapter/Arrow exhaustion, preserved large stored rows,
retryable separate-client allocation failures and explicit result retirement.
Native KV/Document capture checks remain in place. A local allocating writer's
failure now requires evidence of adapter exhaustion before closing the query.
The [current-observation proof](../history/qualification/catalog.md#read-only-current-table-observations--2026-10-23)
adds an authorized, bounded direct read of current Table metadata and rows without
creating a retention pin or publishing storage state. Its component and HTTP
checks cover byte limits, exact interpretation, restart, revocation and rejection
after DROP/name reuse. Reactive watch and freshness consumers still require
migration to this operation.
Verified finite results also expose their exact original direct Table basis after
pin closure, and a read-only source-authority operation protects retained
diagnostics after DROP/name reuse. The scoped
[result-evidence proof](../history/qualification/query.md#retained-table-evidence-and-current-disclosure-rights--2026-10-23)
checks current denial and existing capture recovery. These primitives do not yet
complete named computation freshness or reactive consumer migration.
The reactive migration also needs a new finite capture for each explicit Follow
refresh. Copying a completed Table bundle preserves its exact retention grant,
original cut and pin owner; it cannot authorize a later cut or another pin.
Do not close the freshness gate by changing watermark representations alone.
The replacement must bind each selected capture to the original accepted caller,
exact template/interpretation, distinct durable operation identity, current rights
and recovery evidence. The selected approach gives each bounded refresh its own
caller-signed, single-use current-capture grant and prepared immutable query.
The scheduler must admit those prepared identities, rather than renew signatures
or reuse completed query grants. The direct capture primitive freezes once and
retains its selected frontier. Requester preparation, scheduler selection/activation
and the browser's exact-token recovery now have
[scoped transition tests](../history/qualification/query.md#prepared-finite-refresh-and-direct-watch-transitions--2026-10-23).
The shared current-v1 definition also changes for these stored semantics. Native
Follow now passes the real native selection/restart/worker-replacement and
verified fresh-output path in that evidence record. Broader Follow fault schedules
and installed caller migration remain under qualification; source observations
and injected scheduler results alone do not close those execution gates.
Board now saves preparation, session and Follow intent together before dispatch,
restores them paused, and offers explicit recovery of the original pool/budget.
Native owners identify receipts from the exact saved tokens; saved input positions
cannot substitute for that evidence. The [recovery evidence](../history/qualification/query.md#saved-follow-control-and-preparation-recovery--2026-10-23)
separates native owner checks from injected browser transitions. Installed browser
reload against the composed private host, credential-rotation fault schedules,
Compose and reference caller qualification remain open.

Explicit Workspace capture now supplies the caller-signed grant for fresh manual
and Draft Table queries, while compilation remains inert. The
[separate caller proof](../history/qualification/query.md#explicit-workspace-capture-and-separate-caller-recovery--2026-10-23)
executes the real state-query example, preserves its saved capture across an
OS-process restart and verifies the result. TypeScript recovery tests retain that
grant after an uncertain upload. Installed browser, Compose and reference caller
qualification remains separate.

Named captured definitions now have a
[direct-service execution proof](../history/qualification/query.md#named-captured-definitions-over-the-direct-service--2026-10-23)
for self-joins and independent Tables. Publication, authorization and activation
remain separate; original named attribution survives worker replacement and a
later definition publication. The
[result freshness and attribution proof](../history/qualification/query.md#result-source-freshness-and-named-attribution--2026-10-23)
now binds named captured inspection to an actual retained result and compares
captured/maintained cuts with logical source progress. It distinguishes no-ops,
row changes, definition drift and observation errors without starting execution
or certifying unread output. The generic catalog's unverified completion path is
removed through a [current-v1 cutover](../history/qualification/query.md#query-owned-computation-evidence--2026-10-23);
retired record tags and its removed caller action reject. The
[named maintained revision proof](../history/qualification/query.md#named-maintained-revision-inspection-and-recovery--2026-10-23)
now covers publication/activation separation, original acquisition and history
progress across node restarts, and actual result/delta attribution after later
definition publication. The [naming recovery proof](../history/qualification/catalog.md#named-publication-recovery-with-current-credentials--2026-10-24)
now covers lost publication/policy replies, abrupt node replacement and worker
key/generation rotation for both captured and maintained definitions. Current
credentials recover the exact original receipt; retired signatures and altered
requests reject. Dependency registration and retirement are qualified below;
migration of the older actor fixtures and broader activation/failure fault
schedules remain open.

Direct mutation bindings now retain an optional native authorization prerequisite
for the original accepted application input, independently of the worker's
current Table rights. The [scoped native/storage evidence](../history/qualification/catalog.md#direct-mutation-authorization-prerequisites--2026-10-23)
covers current revocation at acceptance, fresh worker credentials, unchanged
saved bindings and inspection/cancellation after the original condition fails.
This supplies an authorization boundary needed by application callers. Native
progress and Table acceptance remain separate operations.

The [direct namespace evidence](../history/qualification/catalog.md#direct-namespace-lifecycle--2026-10-23)
now covers typed CREATE/RENAME/DROP, separate native registration, permanent
identity claims, bounded RESTRICT progress and retained authority after logical
retirement. The [native SQL namespace path](../history/qualification/sql.md#native-sql-namespace-lifecycle--2026-10-24)
now prepares and dispatches the same frozen typed binding through the existing
SQL ledger. Recovery/cancellation across caller and server loss and the full
installed namespace schedule pass. Work items also uses
explicit direct catalog setup. Namespace membership checks cover live/pending
Tables; broader registered dependency kinds remain part of the shared lifecycle
work. Role and grant publication retains its explicit native administration path.

The [optimistic current-read evidence](../history/qualification/catalog.md#optimistic-current-table-reads--2026-10-23)
adds conditional point reads and bounded ordered suffixes under the original
logical basis. These reads avoid transient retention work for application
read/modify/write preparation and migrations that require an unchanged source.
They reject logical drift and recheck disclosure rights, including empty output.
The [Work items consumer proof](../history/qualification/runtime.md#work-items-over-the-direct-data-owner--2026-10-24)
now uses an explicit direct catalog binding and durable dispatch/progress flow.
Real native and browser schedules pass exact recovery, worker replacement,
bounded row migration, verified activation, fresh queries and current denial.
The [Compose placement proof](../history/qualification/deployment.md#work-items-direct-storage-in-compose--2026-10-24)
also passes persistent native/Table recovery and the real browser schedule with
separate workers. [Installed local application qualification](../history/qualification/catalog.md#installed-work-items-direct-lifecycle--2026-10-24)
also passes separately built consumers, 19-row migration and exact receipt
recovery through node/worker replacement. The
[reference placement proof](../history/qualification/deployment.md#work-items-direct-storage-on-the-reference-runtime--2026-10-24)
also passes physical replacement with fresh Substrate owner keys, the original
uncertain upload, schema migration and current denial. This does not make native progress and direct Table acceptance
atomic or retire the remaining actor-Table consumers.

The [Station ledger migration](../history/qualification/catalog.md#station-ledger-over-the-direct-table-owner--2026-10-24)
now freezes direct creation/mutation intents and commits native dispatch
eligibility before admission. Original Table receipts precede separate audit and
reply publication. Its real native caller schedule passes lost replies,
node/worker replacement, captured-query authorization, incompatible bindings,
supervision and expiry. Its local launcher also passes three-worker upgrades,
credential rotation, Board inspection, courier loss and stop/start recovery.
Compose and the Kubernetes/Substrate reference pass the same persistent workflow;
the reference also replaces a real ledger pod and preserves its logical identity.
The full repository check passes after the coordinated fixture regeneration.
These checks do not make Table changes atomic with application progress or
complete the remaining shared lifecycle gates.

The [direct dependency evidence](../history/qualification/catalog.md#direct-definition-dependencies-and-restricted-retirement--2026-10-24)
now covers explicit exact-definition registration/removal, Table DROP RESTRICT,
both paged graph directions, redacted blockers and current metadata rights.
Lost replies and abrupt node replacement recover original terminal receipts;
replaying an old registration cannot restore a removed edge. Native checks cover
denial after buffering and explicit orphan cleanup. The format uses mandatory
graph indices through the coordinated current-v1 cutover. Named resource and
computation publication still require integration; registration alone does not
establish publication, usability, activation or data retention.

The [named native resource evidence](../history/qualification/catalog.md#named-native-resource-allocation-and-initialization--2026-10-24)
now covers real KV/Document allocation and initialization through the public
catalog and Station owners. Saved original declarations survive withheld replies
and abrupt node replacement at every catalog phase and between Document
initialization turns. Typed KV writes/deletes, actual Document change acceptance,
native data revocation, metadata rename/DROP and permanent original receipts pass.
One prepared native allocation per caller is durably serialized within the
catalog. This closes the metadata-only provisioning gap for that explicit typed
profile; broader physical placement qualification remains open. The
[obsolete metadata owner removal](../history/qualification/catalog.md#obsolete-named-metadata-owner-removal--2026-10-24)
also deletes the supplied-resource-ID publication path and its Table fallbacks,
with a coordinated current-v1 cutover. Named resource publication now has one
owner. Remaining actor Table caller migration is a separate unfinished gate.

The [named dependency proof](../history/qualification/catalog.md#named-resource-dependency-authority-and-retirement--2026-10-24)
extends the graph to actual KV/Document source and dependent definitions. Explicit
registration can precede publication after allocation fixes the interpretation;
metadata ownership remains separate from native data rights. Public lost-reply
and restart checks cover both graph directions, read denial, DROP RESTRICT and
original-edge removal. Component checks preserve old edges through rename and
consumer retirement. These registrations do not make independent owners atomic
or imply automatic cleanup.

The [named query publication work](../history/qualification/query.md#named-query-dependency-publication-and-retirement--2026-10-24)
adds a saved original-caller plan with exact source registrations and a logical
definition reference prepared before native publication. Current graph membership
is checked separately from immutable operation receipts. Exact definition
retirement preserves old attribution and permits fresh-object name reuse;
registration removal remains explicit. Component and contract checks pass.
The public captured schedule also passes twelve withheld acceptance replies and
node replacements, current disclosure rights, DROP RESTRICT, explicit retirement
and edge removal, with complete retained results after source DROP. The maintained
schedule now passes the same twelve acceptance faults across both query shapes,
original history progress, explicit lease/definition/edge cleanup and retained
revision disclosure after source DROP. These are local native-disk proofs;
broader installed caller qualification remains separate.

The [CLI helper retirement](../history/qualification/interfaces.md#cli-actor-table-helper-retirement--2026-10-24)
removes unused actor Table execution/recovery code and corrects DROP guidance;
it does not complete named consumer integration with the dependency registry.
Relational and remaining caller migration and broader installed
resource/computation qualification also remain unfinished. Automatic point
flushing belongs to the following storage milestone. None of the
completion matrix rows below is closed by this partial caller path.

## Catalog, transaction and snapshot scope

[#125](https://github.com/spoke-sh/transit/issues/125) defines the
database/catalog/branch, schema, object and definition hierarchy, its relationship
to partition heads, and supported atomic domains/isolation. A catalog-wide root
must not recreate a global realm CAS for every independent data/process write.
Deliver the complete single-owner Table statement/batch slice first. Specify
the catalog-scoped transaction extension now; its interactive sessions belong
to [transactions and atomic composition](05-transactions-and-atomic-composition.md).
Arbitrary distributed cross-owner transactions are not implied, and native turns
retain their current one-KV-resource atomicity limit.

Snapshots must distinguish a consistent catalog cut from independently captured
source versions and bind exact interpretation, manifests and committed WAL
frontiers. Include accepted unflushed rows and durable pin/recovery ownership
from [#127](https://github.com/spoke-sh/transit/issues/127). Define permitted
isolation anomalies, read/predicate conflicts, rollback and uncertain outcomes
before changing persistent formats or admitting transaction syntax.

Named KV/Document provisioning consumes the actual native persistence cutover in
[#126](https://github.com/spoke-sh/transit/issues/126); a resource metadata record
does not establish storage migration or usability. Computation evidence consumes
the snapshot and logical-change contracts, while automatic activation remains
milestone 9.

### Selected transaction-session extension

The following is the foundation decision for #125 and milestone 5, **not an
implemented transaction API or wire format**. The current executable domain
remains one Table statement/batch. A shared v1 definition replacement and neutral
operation/record fixtures precede admitting the extension. Milestone 5 owns its
implementation and executable isolation/failure histories.

**First domain and isolation algorithm.** Start with Tables in one catalog and
branch served by one fenced local authority. Use retained consistent source
cuts, private workspaces and optimistic whole-object validation under ordered
participant commit guards. Validate every Table read, including predicates,
absent keys, constraints and schema interpretation, as well as every written
Table. Any logical change to a read Table conflicts, even when the other write
touches a disjoint key. This deliberately conservative rule covers phantom and
write-skew dependencies without claiming that key-level OCC is serializable.
Physical flush/relocation and retention bookkeeping do not constitute logical
changes. Finer conflict tracking requires a new qualification of the same
serializable contract; snapshot isolation is not a silent fallback. Real-time
ordering needs its own histories before it is advertised.

Native KV/Document resources, native input progress, other catalogs/branches and
remote providers are excluded from this first participant profile. Reject such
combinations before admission. Milestone 5 retains its multi-model composition
target: each additional owner needs a participant contract and qualification
before joining a transaction. Native turns continue to mutate at most one KV
resource. The presence of a native resource in the same realm is insufficient.

**Consistent basis without a global write root.** Acquire a cut over an explicit
participant set, or enumerate the catalog's live Tables for a catalog-wide cut.
Keep that directory/definition basis stable, acquire participant guards in
canonical identity order, and durably pin each exact interpretation and accepted
WAL/manifest frontier. The point when all selected guards are held supplies the
common cut; earlier pins remain unchanged until that point. Publish the complete
snapshot descriptor before releasing those guards. An interrupted acquisition
is pending work with an exact acquisition identity and a paged cleanup/recovery
ledger, never a partially consistent snapshot. A scoped cut cannot add an object
later under the same basis. A catalog-wide cut fixes name and definition lookup
for later statements, including absence. Current authorization is checked again
on every read and disclosure.

This can temporarily block writes to the selected participants while acquiring
the cut. It does not add a durable realm-wide root CAS to every independent
Table/process mutation. A catalog-wide cut is more expensive than an independent
source vector; expose that cost and preserve both meanings. Guard acquisition,
pin creation and cleanup must page their work and retain restart progress.

**Private work and statement outcomes.** A transaction has stable scoped identity,
an immutable begin basis, ordered statement identities and an exact commit-attempt
binding. Connection loss does not replace any of them. Statements read their own
private changes over the retained basis. Their rows and matched/changed counts
are provisional and carry transaction attribution; statement completion is not a
commit receipt. Savepoints restore workspace changes, staged intents and statement
position, but do not forget read/conflict dependencies already observed. Returned
rows cannot be retracted: readers receive explicit rollback/abort attribution,
and cursors invalidated by rollback cannot continue as if their basis survived.
Nested transactions reject; savepoints are the supported nested scope.

The first profile admits DML and existing supported constraints. DDL inside a
transaction rejects without an implicit commit. Concurrent autocommit DDL/name
replacement invalidates the affected transaction's exact interpretation or name
basis; it never retargets accepted statements. Transactional DDL and additional
constraint profiles require explicit participant preparation and visibility
rules before admission.

**Preparation, decision and visibility.** Freeze the commit attempt before any
participant prepares. Acquire all read/write participant guards in canonical
order, validate the retained logical/schema/name expectations, and recheck the
original caller's current privileges under the native authority fence. Each
written participant durably prepares verified immutable successor data, its
original outcome, expected predecessor and common transaction/attempt identity.
Prepared data is unavailable to ordinary readers; it also prevents a later
writer from bypassing that unresolved predecessor. Read-only participants remain
guarded through the decision. Preparation records and their object references
must be recoverable before the coordinator can decide commit.

One durable, fenced decision chooses commit or abort for that exact attempt and
complete participant set. Commit is the publication linearization point. Every
participant reader resolves a prepared successor through that same decision;
writing participant heads one by one is not the visibility protocol. A committed
participant must be reconstructible from its prepared objects and common receipt
even if its local finalization has not run. Finalization and release of barriers
are recoverable maintenance, not new acceptance decisions. Independent writes
remain on their existing partition authority, subject to unresolved participant
barriers; neither bulk staging nor the coordinator creates a second write owner.

Former coordinators and participants cannot decide or publish after replacement.
Recovery uses the original attempt, prepared references and authority generation.
It may complete missing preparation or record abort only while no commit decision
exists. Cancellation, deadline expiry and a lost response request settlement;
they do not establish abort. Commit/abort races return the one recorded decision.
An acknowledged abort prevents publication but can leave private objects for
explicit cleanup. An acknowledged commit remains committed after caller/session
loss, including loss of the commit reply.

**Outbox and consumer composition.** The first Table domain can atomically publish
typed outbox records alongside its Table changes. A dispatcher may claim an
intent only after verifying the common committed decision. Native message/effect
admission, delivery and external outcomes remain separate recorded operations;
reuse their original identities and current authorization when recovering a lost
dispatch reply. Replay dispatches nothing. Storing a consumer checkpoint in the
same Table domain can join that commit; native input acknowledgement cannot join
until its own participant contract is implemented. Unknown external outcomes
remain connector policy and never become a safe retry merely because an outbox
record exists.

**Bounds and qualification.** Bound resident pages, active transactions,
per-operation work, workspace/spill bytes, retained pins and conflict/guard
metadata through explicit quotas. Durable participant directories and pending
cleanup page independently of resident cache size. Quota refusal or storage
failure cannot discard an admitted attempt, its prepared state or original
decision. Retention defaults to unlimited; physical cleanup requires closure of
all relevant work and retained bases, not merely a disconnected session.
Milestone 5 must exercise write skew/phantoms, absent-key and collation-sensitive
predicates, keyless rows, savepoint dependencies, concurrent DDL, interrupted cut
acquisition, each preparation/decision/finalization crash boundary, revocation,
commit/abort races and outbox recovery. These are required future histories, not
executed evidence for this foundation decision.

## Baseline, bottleneck diagnosis and scope

The [neutral index contract](../../contracts/INDEX_LIFECYCLE_V1.md) supplies stable
index identities and immutable definitions before dependent formats. It binds
source/column identities, declared comparison/collation semantics, constraint
dependencies, build generations and exact coverage to the existing
snapshot/publication model. Declaration, maintenance progress and conditional
coverage publication have distinct types and validation. The
[indexing owner](11-indexing-and-access-paths.md) still delivers secondary access
paths, online lifecycle and planner eligibility; this foundation adds no
executable index syntax or catalog operation.

This diagnosis describes the reopened `a0a8a3ed` baseline. The direct owner and
consumer cutover in the current implementation review replace that data path;
the original diagnosis remains the reason for the work.

The Table catalog already owned stable object/column identities (`CatalogId`,
`DefinitionId`, `ColumnId`), immutable definitions, `CREATE`/`ALTER`/`DROP`, DML
outcomes and native authorization bindings. KV and Documents have resource/service
APIs but no common named SQL publication lifecycle. Named relational definitions
and captured/maintained execution have typed Zig owners with explicit activation.
Dependencies, policy and progress remain spread across their owning interfaces.

That implementation funneled relational and catalog mutations
through the actor mailbox and native turn protocol (`send_input -> open_view ->
read_resource_blocks -> commit_turn`), where each turn is capped at `4 × 256B`
metadata keys and `16 × 64KiB` (`128 KiB` total) resource blocks. Because of
these tiny actor-turn bounds, higher-level table and publication owners
(`TableWrite`, `TableStatement`, `TableAlter`, `TableCleanup`, `Publication`,
`RelationalCapture`, `RelationalMaintenance`) had to invent multi-turn resumable
staging state machines (`STC1`, `STW1`, `STG1`, `STX1`) just to move rows or
evolve schemas.

The shared contract establishes these boundaries; milestone 3 delivers their
executable lifecycle integration:

- **Data-plane operations** validate against the catalog and `policy_epoch`,
  commit idempotent operation records and batch payloads directly through the
  storage/catalog boundary (prepared for the [four-tier storage hierarchy](02-storage-and-query-performance.md)),
  and return typed operation outcomes without cycling through actor mailbox turns.
- **Actor turns (`Station` processes)** remain the mechanism for stateful
  workflow orchestration, message-driven behaviors and external effect coordination.
- Server YAML remains operational configuration; data declarations and
  administrative changes use their owning public operations. A new manifest, CLI
  command or UI form must not become a separate source of authority.

## Delivery sequence

1. **Inventory lifecycle contracts.** For Tables, KV, Documents and named
   computations, define stable object/definition identities, names, logical
   types, physical codecs and collations, dependencies, policy references,
   admission, publication, inspection, alteration and retirement. Distinguish
   supported operations, offline compilation and missing execution.
2. **Define neutral operations and commit evidence.** Specify expected
   definition/head, idempotent operation identity, frozen content, accepted
   outcomes and bounded progress. Define direct point/batch/DDL admission apart
   from actor-frame limits. Separate temporary session state from accepted work;
   a timeout cannot establish rejection. Generate schemas and independent
   positive/negative fixtures from owning types, following #112's v1 cutover.
3. **Resolve atomic domains and consistent snapshot roots.** Close #125/#111's
   identity hierarchy, publication linearization, isolation, rollback/uncertainty,
   DDL visibility and read/predicate-conflict decisions before dependent formats.
   Bind exact interpretation, manifests and committed WAL frontiers, including
   unflushed state. Separate independent source vectors from atomic cuts and
   descriptors from durable pins. Specify the multi-object extension delivered
   by milestone 5 without widening native turns implicitly.
4. **Define dependencies, provisioning and computation observations.** Preserve
   current scoped authorization, explicit dependency registration/RESTRICT and
   unlimited-retention defaults. Specify named KV/Document initialization,
   partial provisioning and recovery; bind computation results to exact source
   data and definition revisions. Define unavailable, incomplete, denied and
   stale observations; reading definitions or inspection starts no work.
5. **Land the foundation with explicit implementation owners.** Implement shared
   types, metadata transitions and generated fixtures through their owning
   packages. Assign storage/native persistence to milestone 2 and complete
   installed lifecycle paths to milestone 3. Board projections use public owners
   and their existing UI/capability review boundaries. Publish only actually
   implemented semantics in current references; proposals stay in this plan.

## Completion evidence

- Neutral fixtures and owning types agree on object/definition identity,
  expected heads, operation identity, permissions, outcome and snapshot evidence.
- Specify permitted and forbidden histories, including read/predicate conflicts,
  name/schema replacement, unflushed data and independent versus atomic cuts.
  Record the selected domain and isolation decisions before persistent formats.
- Verify existing metadata operations preserve dependency and access boundaries;
  generated declarations and missing/foreign-definition rejection stay coherent.
- #111/#119/#120/#125 have concrete contracts and the installed caller/recovery
  obligations below are assigned to milestone 3. Do not mark this milestone
  complete until its own contract/implementation evidence exists, or close #108
  before its transferred executable outcomes are qualified.

The original public-caller completion criteria are preserved under
[installed lifecycle integration](03-live-storage-and-sql-cutover.md#installed-lifecycle-integration).
A contract fixture is not that end-to-end evidence.

### Original executable acceptance tracking

The matrix below preserves the original obligations transferred to
[milestone 3](03-live-storage-and-sql-cutover.md#installed-lifecycle-integration).
The [final acceptance review](#final-lifecycle-acceptance-review--2026-10-26)
records the delivered scope and the separate remaining qualification owners.
This matrix alone establishes no completed implementation or proof.

The implementation review uses the following matrix. Descriptor validation and
contract fixtures are a foundation, not closure of the public caller gates.

| Gate                                             | Work owner       | Required executable evidence                                                                                        |
| ------------------------------------------------ | ---------------- | ------------------------------------------------------------------------------------------------------------------- |
| Stable identities and exact retry binding        | #125, #111       | Lost-reply recovery, altered-content rejection and rename/drop/recreate without retargeting                         |
| One durable Table acceptance authority           | #111, #112       | Point and bulk operations, complete CRUD/DDL, atomic visibility, incompatible-artifact rejection                    |
| Durable snapshots including unflushed data       | #125, #127       | Retained object/WAL coverage, interrupted acquisition, restart and GC/compaction races                              |
| Named usable resources                           | #119, #126       | Real KV/Document provisioning, initialization, reads/writes, partial failure and recovery                           |
| Dependency and policy evidence                   | #111, #119, #120 | Current rights, redacted blockers, explicit RESTRICT and paged collections beyond cache                             |
| Actual computation completion and freshness      | #120             | Verified output/source binding, row-change detection and inspection without execution                               |
| Admitted codec/collation semantics               | #118, #128       | Independent SQL/storage equivalence and unsupported-profile rejection                                               |
| Installed qualification and current explanations | #122, #123, #124 | Real local artifacts, WAL-only recovery, controlled flushing, caller/fault proofs and accurate public documentation |

The [neutral data contract](../../contracts/DATA_LIFECYCLE_V1.md) defines the
initial single-owner acceptance and snapshot descriptors. Runtime implementation
and qualification remain required for every row above. Shared issues retain
their broader scope after a milestone-specific gate passes.

- An application can create a Table, inspect its definition, write/query rows,
  alter the schema and recover the original accepted change after losing a reply
  without routing bulk row data through multi-turn actor mailbox loops.
- Named KV and Document objects expose explicit interpretation, initialization
  state, current rights and lifecycle outcomes through the qualified typed path.
- Repeating an inspection or loading a definition starts no work. Applying a
  competing change rejects the stale expectation; recreating a name never
  retargets an earlier operation or dependent definition.
- Independent caller fixtures agree on definitions, outcomes and permission
  failures. Test revocation, interrupted provisioning/publication, missing
  dependencies and object/dependency counts beyond resident caches.
- Snapshot/transaction fixtures distinguish consistent from independent cuts,
  include accepted unflushed data, and establish the selected isolation profile
  under concurrent data/schema changes without promising unsupported atomicity.
- The handbook states each object's executable lifecycle and demonstrates how
  to distinguish defined, published, pending, complete and unavailable evidence.
  These are review questions; the implementation must define exact status types.

## Boundaries and follow-on work

This milestone does not itself deliver the installed lifecycle, transaction
sessions, automatic scheduling, historical SQL, branches or a universal health
boolean. [Local storage and `.tseg` segments](02-storage-and-query-performance.md)
replace the underlying B-tree page store;
[provider/writer qualification](21-storage-providers-and-concurrency.md) delivers
partitioned concurrency;
[managed computations](12-sql-and-dataflows.md) add WAL-driven activation and
service-owned maintenance; [historical catalogs](10-standards-and-catalogs.md)
extend the same identities and interpretation model. The kernel stays generic.
Definitions and reads never grant rights or dispatch external effects.
