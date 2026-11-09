# Downstream declarative application language

**Status: Implementation in progress, 2026-11-09.**

Tracking issue: [Transit #430](https://github.com/spoke-sh/transit/issues/430).
The [ordered program contract](../../contracts/APPLICATION_PROGRAM_V1.md)
records the compiler boundary and required execution semantics.

Let a downstream consumer build and run its server application as an ordered
SQL migration history: declare data and policy, install named computations,
authorize effects and publish browser operations. Requests invoke the installed
program; they do not rerun migrations. Platform's GitHub sign-in and surface
publication are the first complete acceptance journey.

This supporting plan coordinates existing milestones; it adds no milestone or
completion claim. Implementation is proceeding in logical commits toward one
PR for the complete application runtime. The initial compiler work adds bounded
source framing, ordered program trees and static schema/protected-value checks.
Those local compiler interfaces do not establish installed Queue execution.
The remaining runtime and qualification gates below still apply.

The state foundations now include typed KV rows with retained field constraints and
per-key conditional revisions through the shared direct client and transaction
workspace. Disk recovery, lost replies and stale revisions have focused storage
coverage. Native browser declarations bind exact schemas to canonical resource
identities; browser handlers still need to use them. Versioned SQL row Document
policies now belong to immutable definitions, with a native revision adapter for
the common transaction's retained read guards. Managed Queue execution and the
remaining integration below are still required to qualify the consumer.

Retained program environments and native data-operation adapters now preserve
instruction identity, lexical scope, exact KV revisions and single-record read
coverage. Typed application declarations publish through the catalog's owned
records, with an immutable executor role, native dependency readiness checks and
fenced controls. Input predicates compile to the existing Queue acquisition
format. These are implementation foundations; they do not yet install the
complete three-file application.

The invocation input owner now attaches work before acquisition, retains exact
Queue claim receipts and protects initial environments with native read guards.
Service and invocation progress fences compose on native requests. Saved suspend
and retire controls fence the original pending invocation before updating its
head. The typed invocation runner now composes Table/KV/Stream instructions,
original input ACK and guarded checkpoints through native serializable
transactions. Signed component coverage includes mixed commit/abort, failure
handler termination and cancellation cleanup. The database service now has
bounded original discovery and coordinator-fenced execution for single-partition
input Queues. Effect/response settlement and the remaining installation/browser
phases are unfinished; this
does not qualify the downstream journey.

The protected-value boundary now has a distinct native `CAPABILITY` handle,
exact Queue record encoding, owned/borrowed lifetimes and recursive rejection at
ordinary SQL value, display, comparison and JSON/Arrow export boundaries. The
HTTP reservation component checks original Queue record ownership, current
authority on cached access, purpose-specific redemption and observed handoff
commit evidence. It bounds active request memory, preserves accepted values on
capacity refusal and erases protected bytes on expiry/loss. These component
checks do not yet establish the live native verifier, HTTP source/sink execution
or browser authority cutover; those remain part of the complete PR.

## Reviewed inputs and desired experience

Transit baseline: `6f92f32f44d7b26d9c2028e8b7229fd9ad81085d`.
Consumer baseline: Platform `e79691c9972084965bf4a777e7cca6939b6ad815`, with a
clean working tree at inspection. Its [application guide][consumer-app] and
[sign-in contract][consumer-contract] explicitly select these files as intended
migration input despite unsupported constructs:

| Input | Intent | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| [0001-identity.sql][identity] | Versioned provider policy, canonical identities/bindings, challenge/session KV, two Queues and receipt Stream | 3,730 | `7fe7ed84e4f059d5b3736addc820b40717956405a0b70099295bc909810d4380` |
| [0002-github-signin.sql][signin] | Two connections, HTTP source, two sinks, six managed operations, authorization and activation | 15,175 | `ea11396e5061cb07e5921432bc3bf025c72e807f5b89f7af5f3dd105a4c4d15a` |
| [0003-publication.sql][publication] | Surface catalog, seed data and explicit public snapshot/watch projection | 2,432 | `a56b92ad7f57addafd5c4999a43cda7be574504516de8ebc3325111c6623902e` |

The consumer separately pins published source `91362a4877ea4f2ad808d163bf9185c18482d5ac`
and an older source build. Neither pin is this worktree's validation result.
Its [recorded image investigation][consumer-proof] reports rejection of the
new baseline. This review inspected source; it did not rerun that investigation.

The desired language is SQL with typed procedural dataflow composition. It is
not a request to choose a host SDK language. Zig owns native implementation;
Platform retains its static React client. SQL must expose the actual policy,
state transitions, effect edges and responses. A SQL declaration that merely
selects today's fixed OAuth handler does not deliver that experience.

The user journey to qualify is:

1. Supply public installation settings, protected secret references and separately
   provisioned native roles through bootstrap.
2. Plan all three exact files without mutation, network dispatch or activation;
   inspect dependencies, required rights, budgets and source-located diagnostics.
3. Apply the reviewed plan through `transit migrate`, then verify its retained
   receipts and exact definitions. Authorization and activation stay separate.
4. Start accepting HTTP only after required consumers and sinks are ready. Run
   login, callback, session, logout and provider discovery through the program.
5. Read the surface publication and follow its source-watermark watch. Inspect
   original work, blocked reasons and unresolved effects through public owners.
6. Restart and recover without repeating a code exchange, losing revocation or
   changing accepted work to a newer definition. Evolve through a later migration.

## Current capabilities and gaps

Specific contracts and source take precedence over stale summary inventories.
For example, the grammar-surface inventory still calls KV/Document publication
planned, while the dedicated references and `Session.Prepared.migrationPolicy`
include direct KV/Document operations. Reconcile these descriptions when their
owners change; do not use a broad inventory row as proof that all support is absent.

| Consumer construct | Existing foundation at the reviewed revision | Work needed for this application |
| --- | --- | --- |
| Ordered migration history | [MIGRATION_V1](../../contracts/MIGRATION_V1.md), ordinary statement-owner dispatch, immutable checksums, exact step recovery and finite-dataflow staged dependencies | Block-aware parsing, bounded program inputs, installation bindings, dependency planning and recovery for every new owner |
| TABLE and versioned DOCUMENT | Direct Table operations and [Document DDL/DML](../handbook/reference/sql/create-document.md) | Exact row revisions, declaration-bound policy reads/guards, `SETTING` expressions and canonical browser binding semantics |
| `KV (ROW (...))`, `GET`, conditional `PUT` | [Direct KV SQL](../handbook/reference/sql/create-kv.md); scalar `KVDdl.Spec`; workload expectations `any`, `absent`, `present` | Structured values, field updates, authoritative `_revision`, conditional revision writes and bounded expression operands |
| Queue/Stream schema and workload verbs | [Stream/Queue owners](../handbook/reference/streams.md), native mixed transactions and predicate-aware acquisition merged in #428 | Protected capability slots, managed consumption/checkpointing, route coverage, response handoff and ordinary SQL lowering into mixed decisions |
| `BEGIN ATOMIC` | [Typed common transactions](../../contracts/DIRECT_TABLE_V1.md#transactional-stream-and-queue-work) compose Table/KV state, log appends and exact ACK/progress | Program-step boundaries and continuation/response authority under that decision; Document read guards; SQL BEGIN currently selects Tables and rejects Documents |
| CONNECTION / HTTP REQUEST SOURCE / SINK | [SOURCE_V1](../../contracts/SOURCE_V1.md) declares outbound HTTP-to-Stream sources; native HTTP transports and recorded effect owners exist | Inbound HTTP-to-Queue source is a distinct mode; executable sinks, protected responses and lifecycle controls are missing |
| Queue `DATAFLOW ... AS BEGIN` | [DATAFLOW_V1](../../contracts/DATAFLOW_V1.md) installs finite one-Table recomputation | Typed block compilation, durable ordered continuations, managed Queue ownership, failures and effect/response steps |
| Browser authority and routes | [BROWSER_V1](../../contracts/BROWSER_V1.md) already has a cohosted listener, typed declarations, durable challenges/sessions, provider exchange and watches | Make declared composition authoritative; preserve typed administration and security rules without a second state store or fixed orchestration path |
| `CREATE PUBLICATION`, authorize/activate | Existing typed publication preparation, real Table snapshots and `transit.published.v1` watches | SQL lifecycle and migration planning over the same publication owner, including explicit publisher-role resolution |
| `SECRET`, crypto, HTTP/JSON helpers | Browser and connector primitives exist in native code | Purpose-bound protected types, permitted transformations, current guards, lifetime/loss rules and rejection of ordinary serialization |
| `AUTHORIZE ... AS ROLE` | Current dataflow controls and native scoped authorization | Explicit executor/role binding for new owners; invocation, state mutation, external dispatch and publication remain distinct rights |

Concrete source anchors for the first implementation slices:

- [Migration SourceFile validation](../../packages/zig/transit-sql-protocol/src/Migration.zig)
  permits the wire's 64 KiB ceiling but also calls Fuze's 4,096-byte statement
  validator on the entire file. [MigrationRunner.splitStatements](../../packages/zig/transit-sql-service/src/MigrationRunner.zig)
  repeats validation and tracks parentheses, not `BEGIN`/`END`, `IF` or `CASE`.
  Raising one limit or splitting at each semicolon cannot install these bodies.
- [ManagedSql](../../packages/zig/transit-sql/src/ManagedSql.zig) requires
  `CREATE DATAFLOW name INTO output AS SELECT`; its controls end after the name.
  It does not accept Queue blocks or `AS ROLE`.
- [SourceSql](../../packages/zig/transit-sql/src/SourceSql.zig) expects
  `FROM HTTP CONNECTION ... INTO STREAM`, not inbound `FROM HTTP REQUEST`.
- [KVDdl](../../packages/zig/transit-fuze/src/KVDdl.zig) admits int64, boolean,
  UTF-8 and binary values; [KVWorkloadSql](../../packages/zig/transit-fuze/src/KVWorkloadSql.zig)
  has no revision expectation or record-field update.
- [BrowserRuntime](../../packages/zig/transit-serving-http/src/BrowserRuntime.zig),
  [BrowserRequest](../../packages/zig/transit-serving-http/src/BrowserRequest.zig),
  [BrowserProviders](../../packages/zig/transit-serving-http/src/BrowserProviders.zig),
  [BrowserSnapshot](../../packages/zig/transit-serving-http/src/BrowserSnapshot.zig)
  and [BrowserWatch](../../packages/zig/transit-serving-http/src/BrowserWatch.zig)
  are reusable implementation owners, not missing features to rebuild.

## Contract decisions to review first

These are recommended resolutions and explicit implementation gates. The
consumer files establish desired behavior, not an already sound or finalized
grammar. Any necessary syntax change must be reconciled with Platform's source
and contract; never silently skip or rewrite an applied migration.

| Decision | Proposed resolution and required evidence |
| --- | --- |
| Computation lifetime | Keep finite relational recomputation and ordered Queue programs distinct in the shared typed computation model. An invocation freezes input, program definition, policy observations and step identities. No automatic snapshot recomputation can recover a lost ordered invocation. |
| Type and expression semantics | Define scalar versus zero/one/many-row `LET` results, missing KV keys, nullable fields, `_revision`, record updates, exact integer conversions and helper bounds. `REQUIRE` succeeds only on TRUE. Specify safe field access and Boolean evaluation so a missing record cannot become an accidental success or untyped host error. |
| Atomic boundaries | Each block commits its exact state/log changes plus continuation/checkpoint and any response handoff through the common transaction owner. Do not keep a database transaction open across HTTP. Add an enforceable Document policy read guard before using `signin_policy` in a decision; a preliminary read is insufficient. |
| Input settlement | Define which boundary ACKs each source lease, how later continuation work is discovered, and how permanent refusal settles. For callback admission, claim + exchange enqueue + receipt + source ACK + handoff must share one decision. For earlier blocks that have more work to do, persist the continuation before releasing the input. |
| Canonical browser state | `native_binding` binds exact typed objects to the existing browser authority and enforces schema/transition invariants under native authorization. Typed browser inspection/restriction and declared execution see the same records. Ordinary writes cannot forge sessions or bypass binding restrictions. No shadow BRC1 store or dual-write bridge. |
| Protected values | Distinguish a durable non-authorizing handle from the transient protected bytes it references. A Queue may retain a purpose/owner/expiry binding, never credential bytes or a generally redeemable bearer value. Reject SELECT/export/cast/log/capture leakage and unauthorized redemption; allow only explicitly typed sink/response use. |
| Time and randomness | Entropy and trusted time enter through native observations. Freeze non-secret step observations under original identity; protected random material stays transient. If its loss prevents continuation, record the original unresolved outcome and require a new login. Never regenerate a session token or replay a transaction to hide an uncertain decision. |
| Effects and guards | Bind one original effect per step. Only a fresh accepted dispatch decision may send; replay observes. Check current definition, authority, secret and lifetime guards at dispatch and disclosure. A Queue retry budget is not an effect deduplication protocol. Profile exchange must respect the same remaining five-second lifetime as token exchange. |
| Response ownership | Handoff transfers exactly one response owner with its durable decision. Buffer responses until the producing transaction commits; reauthorize immediately before disclosure. Socket loss, restart or capability expiry cannot reverse committed state or permit a second effect/session. Define failure when no response owner remains. |
| Failure semantics | Every operation needs a typed default refusal/terminal path, not only `complete_github_signin`'s explicit handler. Distinguish pre-claim refusal, unknown claim/commit, known provider refusal and unknown remote outcome. Resolve pending decisions before executing `ON FAILURE`; a handler cannot overwrite a committed success. |
| Routing and activation | Validate route labels and consumer dependencies before ingress activation. Define ambiguity/missing-consumer behavior; do not depend on a competing-consumer race. Shared predicate acquisition is reusable, but does not itself provide installed subscription ownership. |
| Paging, publication and retention | Provider listing must consume the original `after` cursor and preserve current page semantics. Reuse publication encoders, invalid-session rejection and watermark behavior. The seven-day receipt Stream policy does not expire unresolved effects, canonical sessions or required recovery evidence. |

`NATIVE_SESSION_CURRENT`, `NATIVE_IDENTITY_ALLOWED` and `NATIVE_BINDING_ACTIVE`
must be narrow authoritative predicates over those bound stores and native
rights. Their names must not conceal another GitHub workflow. Exact issuer,
client and provider subject determine identity; login creates no grants.

## Implementation sequence

Each slice is independently reviewable. Contract definitions and rejection
controls precede persistent/runtime changes. Package ownership below is proposed
within existing boundaries, not a mandate to add a new package for every slice.

### P0 — Freeze the consumer contract and conformance inventory

Owners: protocol, SQL, browser and application migration maintainers.

- Inventory every declaration, statement and helper in the three files with
  source locations, exact definitions, required privileges and budgets. Record
  current acceptance separately from runtime qualification.
- Resolve the decision table above in the owning contracts: DATAFLOW, MIGRATION,
  BROWSER, SOURCE, direct transactions, serving and effect/secret boundaries.
  Add neutral types before exposing text or host bindings. Preserve one current
  v1 definition; coordinate incompatible record, wire and generated-schema changes.
- Freeze the exact-input fixture and a synthetic configuration that never
  contains real secrets. Reconcile any accepted language changes with Platform
  before treating a revised fixture as the target.

Exit: reviewed semantics, explicit unsupported profiles and an executable test
inventory. A parser inventory is not an application pass.

### P1 — Compile complete programs and build reviewable migration plans

Owners: Fuze lexer/parser, `transit-sql`, `transit-sql-protocol`,
`transit-sql-service` and `transit-sql-client`; depends on P0.

- Separate file, statement, compiled-program, nesting and execution budgets.
  Preserve finite-query limits while admitting bounded larger declarations
  through the owning protocol. Reject excess input before partial publication.
- Parse compound bodies structurally, preserving strings/comments, `END IF`,
  `CASE`, internal semicolons and exact source locations. Treat a whole CREATE
  DATAFLOW body as one installation step; its runtime steps use a separate
  stable identity space.
- Lower bindings, expressions, guards and control flow to shared typed plans.
  Validate protected-value flows, exact object dependencies and operator support;
  do not interpret SQL strings dynamically inside a worker.
- Extend staged planning to data objects, connections, sinks, programs and
  publications declared earlier in the history. Freeze public `SETTING` values,
  role identities and secret references into the reviewed plan. Apply/resume
  rejects changed bindings and follows accepted producer receipts.

Exit: the complete input can be parsed and a dependency/authority plan inspected
without effects. Apply remains explicitly unsupported for owners not yet wired.
Include malformed nested blocks, limit boundaries, missing bindings, wrong
types, attempted secret disclosure and forward/replaced dependency negatives.

### P2 — Supply guarded data and canonical browser bindings

Owners: `transit-catalog`, `transit-storage`, Fuze data types and browser
administration; depends on P0 and typed declarations from P1.

- Add typed structured KV values and exact conditional revision operations;
  reuse the direct partition's bounded batches and original-operation recovery.
- Bind identity, binding, challenge and session objects to one browser authority.
  Implement declared Document policy observations and guards through a supported
  common decision boundary; do not quietly substitute a Table or a stale check.
- Enforce native schema/identity/transition constraints and current role rights.
  Support authoritative absent reads, revision conflicts and exact identity
  insertion/assertion under concurrency.

Exit: concurrent claims have one winner; conflicts publish no partial state;
same-definition restart preserves identity, sessions and revocation. Typed and
SQL access agree. Negative tests reject forged canonical records and bootstrap
bindings. Retained populations exceed resident caches without fixed user arrays.

### P3 — Execute managed Queue programs and transactional continuations

Owners: managed computation service above the direct database APIs, shared
transaction and Queue owners; depends on P1/P2.

- Install immutable programs with separate publication, authorization and
  activation. Reuse the qualified Queue predicate/lease owner for route selection.
- Persist original input, definition, step, observations, transaction references,
  continuation and terminal disposition in bounded, paged native records.
  Event-driven wakeups are hints; retained discovery recovers missed wakeups.
- Commit mixed state/appends/receipts/checkpoints and exact lease settlement
  together. Recover the original transaction before choosing a new branch.
  Fence replaced workers and suspended/retired definitions at decision time.
- Execute typed refusals and bounded failure continuations without a client
  poller, private workflow ledger or Station actor admission for SQL/database work.

Exit: an installed generic Queue-to-state/Stream program recovers across every
decision boundary. Duplicate delivery, revocation, stale leases, changed
definitions, quota pressure and suspension cannot duplicate outputs or strand
accepted work without inspectable progress. Existing finite dataflows still pass.

### P4 — Add protected ingress, sink effects and response handoff

Owners: `transit-serving-http`, shared effect owners, secret resolution and
program runtime; depends on P2/P3 and P0's capability contract.

- Implement inbound HTTP source publication over native listener placement,
  exact Host/Origin/proxy checks and bounded admission. Keep outbound SOURCE
  ingestion a distinct typed mode. Do not expose backing SQL rights to callers.
- Implement protected request/credential values, restricted transformations and
  authenticated handoff. Persist only allowed references/commitments; wipe
  transient buffers on release. Define crash and deadline outcomes explicitly.
- Publish and authorize sinks separately. Bind dispatch to the original effect,
  current secret/policy and remaining deadline. Reuse native HTTP/TLS machinery;
  replay cannot send or resolve missing protected outcomes into a new attempt.
- Implement post-commit response intents, fixed redirects, cookie operations,
  guarded disclosure and failure mapping through the existing browser wire owner.

Exit: independent peers observe at most one token dispatch per original claim,
including lost dispatch/response evidence. Unknown stays unresolved; no secret
appears through ordinary rows, diagnostics or captures. Policy rotation,
capability theft/loss, duplicate credentials and late responses fail closed.

### P5 — Install browser publications and complete lifecycle inspection

Owners: catalog/browser publication, SQL service, shared client and migration
runner; depends on P1/P2, with final application readiness depending on P3/P4.

- Lower CREATE/AUTHORIZE/ACTIVATE PUBLICATION to existing typed projection
  preparation and conditional publication. Bind source definitions, audience,
  publisher role, routes and budgets; publication creates no grants.
- Supply explicit SQL lifecycle/inspection for source, sink and program owners,
  and a read-only view of definitions, dependencies, desired controls, current
  activation, original work, blocked/refused/unresolved outcomes and completion.
  Reuse public read operations for Board; add no hidden mutation authority.
- Extend migration owner receipts, resume and verify for these declarations and
  controls. Check final definitions/settings/control drift across versions.
  Keep migration completion, active consumers and a completed user request distinct.
- Gate ingress on ready dependencies, with consumers installed first as the
  consumer source requests. Test interrupted activation without admitting work
  into an unserviceable program.

Exit: all three files apply and verify on fresh state; lost migration replies
resume original work. Public snapshots/watches preserve complete cuts, lossless
values, current rights and no rescans for unchanged watermarks.

### P6 — Qualify the complete journey and cut over consumers

Owners: runtime/interface tests, release/distribution and Platform adoption;
depends on P1–P5.

- Run the actual three-file program through real listeners against an
  independent synthetic GitHub peer. Verify behavior by changing a declared
  policy/program in a later migration and observing the changed behavior and
  old-work attribution; a fixed-handler wrapper cannot satisfy this test.
- Retain existing browser provider/transport regression coverage. GitHub is this
  plan's first declared provider; Google/Facebook declared programs are follow-up
  work, not an excuse to remove currently supported native behavior.
- Replace fixed GitHub orchestration at the coordinated cutover. Migrate affected
  typed admin, fixtures, examples and consumers together; no legacy decoding
  fallback or second route/state owner. Incompatible histories reject and retain
  their matching recovery artifacts; no automatic reset or assumed importer.
- Publish the exact supported interfaces, limitations and evidence. Qualify the
  matching promoted runtime/admin/client artifacts, then hand Platform the
  revision, definition, digest, commands and proof record.
- Platform removes replaced provider/publication construction from `operate.py`,
  supplies only required placement/settings/secrets/role bootstrap, repins and
  reruns its independent tests. Production consent, cloud routing and retained
  production transition remain separately reviewed deployment work.

Exit: Platform's application executes from its reviewed migration history on the
qualified artifact. A merged PR, local compiler pass or finite projection alone
does not close the tracking issue.

## Acceptance and verification

| Boundary | Required executable evidence |
| --- | --- |
| Installation | Exact files and bindings; no planning I/O; complete block parsing; ordered staged dependencies; changed checksum/target/settings refusal; interrupted apply/resume/verify with original receipts |
| Application behavior | Login → one-use challenge → callback claim → two effects → stable identity/session → session read/logout; provider paging; surface snapshot/watch; declared policy/program change alters behavior |
| Atomicity and recovery | Crash/lost replies around claim, enqueue, ACK, handoff, effect dispatch, final state transaction and response; one outcome per original identity, no partial publication and no failure handler overwriting success |
| Authority | Concurrent/cross-browser/expired callbacks; wrong Host/Origin/proxy; duplicate state/code/cookies; unbound sign-in without grants; forbidden bootstrap binding; current secret/provider/session/binding/native-grant revocation at dispatch and buffered disclosure |
| Protected material | No token/code/cookie/PKCE leak through SQL, captures, logs, receipts or errors; cross-purpose/cross-owner handle redemption denied; restart loss retains unresolved original work |
| Publication | Supplied invalid session rejected even on public reads; complete empty/multi-page results; exact definitions; source replacement/withdrawal; wide values; idle revocation; slow watchers and unchanged-watermark scan counts |
| Resources and evolution | Bounded active work, compilation, memory and control capacity with durable history larger than cache; lease loss and shutdown; explicit retention; old-definition rejection and same-definition restart |

During implementation use existing task owners in
[the suite inventory](../../tests/runner/suite.json): `migrate-lifecycle`,
`managed-tables`, `source-declarations`, `declarative-browser`,
`direct-state-transaction`, `direct-mixed-transaction`, `sql-log-declarations`
and `sql-transactions`, plus the affected parser/package checks. Add the missing
program, capability and crash schedules to their owning suites; task names above
do not imply those new cases already exist.

Before each implementation PR, run the repository's required fast and handbook
gates. Contract changes additionally require `just check contracts` and dependent
callers; SQL/server/startup changes require `console-latency-gate` in the pinned
`ci-experience` shell and `server-sql-types`. Changed wire/scalar adapters require
the SQL interface loop. Run affected committed-HEAD clean lanes (including the
owning storage/query, interface, connector and caller lanes) before pushing.
Board/browser changes require their checks/proofs. Record exact commands,
revision, bounds and outcomes; a missing or skipped proof is not a pass.

Initial planning validation: `nix develop --command python3 -B tests/runner/docs.py`
passed (11,888 local links across 737 files); whitespace checks passed. Runtime
suites and the pre-PR fast/handbook gates were not run for this local planning
deliverable. Implementation validation is recorded separately; the final PR must
still qualify the complete changes against committed HEAD.

## Roadmap and tracking boundaries

| Owner | Contribution to this plan |
| --- | --- |
| [M5 transactions](05-transactions-and-atomic-composition.md) / [M6 streams, queues and runtime](06-streams-queues-and-durable-runtime.md) | Common decision, lease settlement and continuation recovery; reuse delivered mixed participant work |
| [M7 Documents](07-document-storage-and-station-decoupling.md) | Exact policy revision/read-guard integration; no requirement to finish every Document format |
| [M8 gateway](08-gateway-architecture-and-protocol-ingress.md) / [M9 clients](09-client-foundation-and-language-apis.md) | Cohosted ingress, shared operation/results and public caller surfaces |
| [M12 managed computations](12-sql-and-dataflows.md) | Primary coordination for installed programs, sources/sinks, lifecycle and migration integration |
| [M27 control and policy](27-control-and-policy-plane.md) | Protected credentials, canonical identity/session policy and separate execution/dispatch rights |
| [M28 publication](28-published-resources-and-investigations.md) | SQL projection publication and current-authority snapshot/watch disclosure |
| [M34 programming model](34-programming-model.md) / [M43 grammar](43-sql-grammar-and-dialect-ergonomics.md) | Shared typed language semantics and later host-language composition; broad SDK expansion is not an initial prerequisite |

[Platform #120](https://github.com/spoke-sh/platform/issues/120) owns downstream
delivery and adoption. [Transit #284](https://github.com/spoke-sh/transit/issues/284)
is the earlier browser runtime tracker: its historical missing-runtime assessment
must not be reused as a current gap claim. [Transit #31](https://github.com/spoke-sh/transit/issues/31)
owns the broader multi-model/dataflow direction; [#9](https://github.com/spoke-sh/transit/issues/9)
owns installed worker workflows. This plan focuses on the concrete declarative
program and its cross-owner contract gaps. It does not require general incremental
DBSP, distributed transactions, an OAuth refresh vault, every SDK, or new cloud
infrastructure before the selected single-authority application can qualify.

[consumer-app]: https://github.com/spoke-sh/platform/blob/e79691c9972084965bf4a777e7cca6939b6ad815/transit/README.md
[consumer-contract]: https://github.com/spoke-sh/platform/blob/e79691c9972084965bf4a777e7cca6939b6ad815/contracts/github-signin-application-v1.md
[consumer-proof]: https://github.com/spoke-sh/platform/blob/e79691c9972084965bf4a777e7cca6939b6ad815/docs/qualification/native-dataflow-migrations.md
[identity]: https://github.com/spoke-sh/platform/blob/e79691c9972084965bf4a777e7cca6939b6ad815/transit/migrations/0001-identity.sql
[signin]: https://github.com/spoke-sh/platform/blob/e79691c9972084965bf4a777e7cca6939b6ad815/transit/migrations/0002-github-signin.sql
[publication]: https://github.com/spoke-sh/platform/blob/e79691c9972084965bf4a777e7cca6939b6ad815/transit/migrations/0003-publication.sql
