# 12. Compiler and runtime integration

[Roadmap](README.md) · **Status:** In Progress

Let applications compiled by transitc execute, migrate and test through ordinary
Transit operations, preserving current authority, stable definitions and accepted
work. Compiler delivery is tracked in the
[transitc roadmap](https://github.com/spoke-sh/transitc/blob/main/docs/roadmap/README.md).
This milestone retains the upstream contracts and cross-repository acceptance
boundary. Moving the plan does not complete the original milestone.

## Compiler plan handoff

On 2026-11-20 the compiler backlog was extracted from Transit
[`4e47372a2739444d30058934dd0bb8bd703ef65c`](https://github.com/spoke-sh/transit/tree/4e47372a2739444d30058934dd0bb8bd703ef65c)
and expanded in transitc. The
[original milestone](https://github.com/spoke-sh/transit/blob/4e47372a2739444d30058934dd0bb8bd703ef65c/docs/roadmap/12-application-modules-compilation-and-testing.md)
retains the complete D1–D6 decisions, P0–P6 journeys and original workload targets.
The [completion implementation plan](application-modules-completion.md) retains
its source-specific review units, approved slices and evidence; its compiler
execution sequence is superseded by the new owner.

| Transferred scope | Authoritative delivery plan |
| --- | --- |
| P0–P3 source grammar, typed core, higher-order helpers and SQL emission | [transitc 5: Typed composition and executable SQL](https://github.com/spoke-sh/transitc/blob/main/docs/roadmap/05-typed-composition-and-sql.md) |
| P1/P3/P6 recursive packages, locks, CLI, diagnostics and source formatting | [transitc 6: Reproducible workspaces and developer tooling](https://github.com/spoke-sh/transitc/blob/main/docs/roadmap/06-workspaces-and-developer-tooling.md) |
| P4/D5 offline diffing, immutable proposals and replacement emission | [transitc 7: Migration synthesis and definition evolution](https://github.com/spoke-sh/transitc/blob/main/docs/roadmap/07-migrations-and-definition-evolution.md) |
| P1–P3 module interfaces, profiles, effects, capabilities, secrets and transitions | [transitc 8: Protected workflows and runtime integration](https://github.com/spoke-sh/transitc/blob/main/docs/roadmap/08-protected-workflows.md) |
| P5/D6 source tests, orchestration, deterministic controls and replay schedules | [transitc 9: Deterministic tests and replay](https://github.com/spoke-sh/transitc/blob/main/docs/roadmap/09-deterministic-tests-and-replay.md) |
| P6 complete application, independent/formal evidence and performance targets | [transitc 10: Whole-application and performance qualification](https://github.com/spoke-sh/transitc/blob/main/docs/roadmap/10-application-qualification.md) |

Source grammar, compiler, workspace adapters and CLI are owned there. Transit
supplies shared SQL/protocol/memory types and the
[native compiled-case test contract](../../contracts/TEST_HOST_V1.md). It has no
compiler snapshot or reverse build dependency. Current usage belongs to the
[application reference](../handbook/reference/applications.md) and transitc's
handbook; this plan establishes no new supported syntax.

## Delivered scope and retained evidence

The bounded recursive compiler and Table build landed in
[PR #437](https://github.com/spoke-sh/transit/pull/437). Isolated Table tests,
nominal/variant compile-time specialization, public Queue programs, pure helpers,
concrete schema binding, restricted reference exports and explicit-basis Table
migrations subsequently extended that profile before extraction. These delivered
slices do not establish runtime-private modules, protected workflows, general
replacement or deterministic effect/replay simulation.

Preserve the original proof scopes and failures:

- [Isolated Table tests](../history/qualification/interfaces.md#isolated-application-table-tests--2026-11-10).
- [Typed targets and shared SQL framing](../history/qualification/query.md#typed-target-rebase-and-shared-sql-framing--2026-11-11).
- [Actionable diagnostics and nominal Queue programs](../history/qualification/query.md#actionable-source-diagnostics-and-nominal-queue-programs--2026-11-13).
- [Functions, ordered guards and inline procedures](../history/qualification/query.md#pure-functions-ordered-guards-and-inline-atomic-procedures--2026-11-15).
- [Explicit-basis Table migrations and returning calls](../history/qualification/query.md#explicit-basis-table-migrations-and-returning-inline-calls--2026-11-16).

Each record names its source and limits. A later merge or documentation check
does not reconcile a retained latency, cleanup, installation or recovery failure.
The original 26-command/14-workflow application inventory and performance targets
remain unqualified until the complete cross-repository experiment runs.

## Remaining Transit deliverables

| Boundary and owner | Required upstream handoff | Acceptance through ordinary operations |
| --- | --- | --- |
| Shared SQL frontend, [M10](10-standards-and-catalogs.md) types/catalogs and [M45](45-sql-grammar-and-dialect-ergonomics.md) grammar | Exact pure-package distribution; scalar/cell/cardinality and runtime variant encodings; executable SQL for each admitted source construct | Independent reparse/rebind, raw-input validation and source-absent execution preserve values, errors, identities and current rights. Unsupported forms reject. |
| Catalog authorization and [M13](13-declarative-serving-and-reactive-dataflows.md) public operations | Runtime-private module ownership, exported operation rights and reference non-escalation | Direct SQL, forged ownership, revoked grants and reference-only reads/mutations cannot bypass privacy. Source imports and inline calls grant no privilege. |
| [M5](05-transactions-and-atomic-composition.md)/[M6](06-streams-queues-and-durable-runtime.md), [M7](07-document-storage-and-station-decoupling.md) and [M14](14-sql-and-dataflows.md) | Per-kind transactions, staged migration dependencies, Queue-program receipts, managed generation and continuation contracts | Generated operations use one native commit decision and recover original accepted work; unavailable resource kinds remain unsupported in the compiler. |
| [Migration](../../contracts/MIGRATION_V1.md), [catalog definitions](../../contracts/CATALOG_DEFINITIONS_V1.md) and [M11](11-indexing-and-access-paths.md) rewrites | Conditional replacement, explicit transforms and `require_idle`, `pin_generation`, `drain_active` policies | Fresh definitions and replay agree; stale conditions, live drift, lost replies, restart and in-flight leases/operations preserve frozen interpretation and immutable history. |
| [M13](13-declarative-serving-and-reactive-dataflows.md)/[M14](14-sql-and-dataflows.md), with [M29](29-control-and-policy-plane.md)/[M30](30-published-resources-and-investigations.md) as needed | Serving profiles, protected effects, current authorization, evidence validation and lifecycle ordering | Real denials, one-use admission and bounded-capacity races preserve settlement, protected disclosure and explicit unknown outcomes. Basic publication does not wait for all of M29/M30. |
| [Test host](../../contracts/TEST_HOST_V1.md) and [transit-test](../../packages/zig/transit-test/README.md) | Versioned typed subject/grant, clock, mock and interruption controls implemented over native owners | Isolated deterministic schedules, protocol mismatch/malformed/partial-result rejection, bounded memory/storage/time, cancellation and joined cleanup; no deployable SQL test controls. |

Preserve the reviewed 1 MiB executable-statement and 2 MiB migration-file limits,
separate from the 4,096-byte editor bound. The proposed 256 migration steps remain
a separately measured extension to the current 64-step profile, including wire,
receipt and recovery budgets. Changing a constant does not qualify that profile.

## Delivery and compatibility gates

1. Agree the runtime representation and privacy boundary before compiler syntax
   promises those semantics. Supply a per-operation contract, definition identity,
   public caller, limits and positive/negative recovery evidence.
2. Qualify broader migration kinds and replacement policies incrementally. Start
   subject/grant controls with the real authority boundary; add virtual time,
   effects and replay only through the corresponding native owner.
3. Coordinate pure-package and compatible test-host pins with transitc. A matching
   v1 label is insufficient. Reject foreign definitions before execution, preserve
   the current-v1 cutover policy and keep the dependency direction acyclic.
4. Run source-absent generated SQL and native plan/apply/resume/restart journeys.
   Compare independent definitions, rows/counts, refusals, dispatches and retained
   receipts. Compilation, mocks and models cannot replace provider/durability
   qualification or authorize execution.

[M17](17-data-centric-compilation-and-specialization.md) retains runtime
specialization/AOT ownership and coordinates optional transitc targets over the
same graph. [M22](22-branches-merges-and-restore.md)/[M31](31-reviewed-data-collaboration.md)
reuse neutral definition diffs; [M24](24-formal-semantics-and-correspondence.md)
and M45 extend evidence and dialect coverage. [M32](32-board-reimplementation.md)
inspects shared catalog/module lineage read-only. These handoffs neither add a
second execution authority nor defer each delivered feature's own proof gates.
M13 retains retirement of the existing interface/UI compiler after consumer
migration; no new `transit app` command family is introduced here.

## Completion evidence

M12 remains In Progress until its upstream handoffs and the original end-to-end
journeys pass with a compatible transitc revision. Record the compiler, pure
packages, host/runtime, contract definitions, source/lock/SQL digests, workload,
fault schedules and host conditions together. Link executed results in
[qualification history](../history/qualification/README.md); update public
contracts and usage at their owning implementation change.

Closure requires recursive/offline composition, dynamic typing and protected
operations, independent source-absent SQL, immutable migration replay and all
replacement policies, deterministic failure/replay tests, selected formal/native
correspondence, and the full application/performance assessment. A moved backlog,
parser support or selected fixture pass completes none of those missing gates.
