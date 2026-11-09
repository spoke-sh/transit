# Application module build implementation plan

[Milestone 12](12-application-modules-compilation-and-testing.md) · **Status: Planned** · Review proposal

Deliver the first usable source-to-SQL build path: an application composes typed
modules through `build.transit`, checks the composition offline, and produces
deterministic SQL that an ordinary Transit client can execute with the source
tree absent. Make this the next application-language slice. The remaining
browser/application integration in [#430](https://github.com/spoke-sh/transit/issues/430)
then consumes that compiler boundary.

The first implementation PR covers the source/build contracts, recursive module
composition, locked dependencies, a bounded working catalog, canonical SQL
emission and `transit build` for an explicitly supported Table workload. It is a
vertical subset of M12 P0, P1 and P3. Subsequent slices add the abstractions,
runtime encapsulation, migration synthesis and test language required to finish
M12. This plan does not change the milestone's status or close #430.

## Source basis and work to reuse

Reviewed Transit `b04e2be4f674e8498cea409007ecb6c72150f4b3`, which includes
[PR #435](https://github.com/spoke-sh/transit/pull/435), and the clean Platform
checkout at `7da5b30c6d3790d3c3c9bb4e3542e466e6094ac7`. Platform now has seven
baseline migrations and 3,513 lines. Preserve the older three-file fixtures as
their own regression corpus; record the new baseline's exact bytes, checksums,
declarations and unsupported constructs separately during implementation.

M12's original gap assessment predates the merged foundation in several places:

| Area | Current source | Consequence for this slice |
| --- | --- | --- |
| File framing | [SqlScript](../../packages/zig/transit-fuze/src/SqlScript.zig) and [MigrationRunner](../../packages/zig/transit-sql-service/src/MigrationRunner.zig) already preserve compound `CREATE DATAFLOW ... FROM QUEUE` bodies, including nested blocks, conditionals and CASE expressions. | Extend the shared framer for module/build and other compound declarations; do not introduce another semicolon splitter. `FROM COMMAND`, procedures, functions, tests and FOR blocks need coverage. Framing does not make these forms executable. |
| Bounds | [SqlInput](../../packages/zig/transit-fuze/src/SqlInput.zig) permits 64 KiB source files independently of finite SQL's 4,096-byte statement limit. Migration source validation uses this scanner. Both migration owners still permit 64 steps per version. | Separate source compilation budgets from output-owner and migration transport budgets. The proposed 1 MiB migration file and 256-step limits remain unfinished M12 work. |
| Ordered programs | [ApplicationProgram](../../packages/zig/transit-fuze/src/ApplicationProgram.zig) supplies owned syntax, spans, typed resource binding, protected values and retained instruction codecs. | Reuse its admitted semantics; do not equate them with general whole-program capability analysis or support for the expanded Platform baseline. |
| Runtime installation | [ManagedSql](../../packages/zig/transit-sql/src/ManagedSql.zig) and [MIGRATION_V1](../../contracts/MIGRATION_V1.md) expose finite Table dataflows. Queue programs are not installed through those SQL owners. | An executable target must refuse Queue application output, whole-program deadlines and other unsupported forms. Native component support alone cannot enable an output capability. |
| Compiler ownership | [SqlCheck](../../packages/zig/transit-fuze/src/SqlCheck.zig) handles Table CHECK predicates; [SqlBinding](../../packages/zig/transit-fuze/src/SqlBinding.zig) holds diagnostic context. Catalog already depends on Fuze. | Add correctly scoped compiler modules instead of repurposing these files as a whole-application compiler or making Fuze depend on Catalog. |

PR #435's merge establishes availability of its code, not completion of its
outstanding validation. Recheck the affected baseline owners before relying on
them. Its incomplete runtime qualification remains attributable to that work.

## First slice and review boundary

The acceptance application has a root build, an independently buildable child
package, a pinned repository package, a typed module parameter and two explicit
instances of a reusable Table module. The instances use distinct, caller-chosen
object names in one already configured SQL namespace. Source paths and aliases
do not determine those bindings. The generated program creates Tables, writes
known rows and reads complete typed results through existing statement owners.

The first supported runtime subset is Table CREATE with supported types and
constraints, bounded INSERT/UPDATE/DELETE, and finite SELECT. Enumerate the exact
shared compiler variants in the contract and tests; this is not a promise to
support every form of those verbs. Existing schema metadata, when needed, is an
explicit input. Reject unresolved bindings and syntax outside the target's
implemented subset before publishing output.

Source modules support typed value, type and module parameters, exports,
constructors and nested composition. Include a terminating recursive constructor
and hygienic repeated instantiation in the proof; a file concatenator is not a
completion of this slice. Import cycles are errors, separately from bounded
constructor recursion.

Source-private helpers remain inaccessible to importing modules. Runtime objects
in this initial subset must be explicitly exposed for ordinary caller-authorized
SQL access. Reject requests for runtime-private storage or privileged procedure
expansion until M12's catalog ownership/enforcement contract exists. Importing a
module or possessing generated SQL grants no privileges.

`transit build` has default/named targets, check-only compilation and frozen
offline resolution. Dependency fetching/updating is an explicit tooling action;
build evaluation never fetches implicitly. The exact CLI options and source
syntax are settled in the first contract commit, before adapters are added.
`build.transit` uses the same module language as its imports; the lockfile records
resolved content, not a second configuration language.

## Contracts and package boundaries

Define an application-source/build v1 contract alongside the existing contracts,
and extend [TRANSIT_CLI_V1](../../contracts/TRANSIT_CLI_V1.md) and the
[grammar owner](../../contracts/sql/README.md). Distinguish source, build and
test roots from executable statement roots. Runtime entry points must reject
source-only forms. Preserve the existing `transit-app` interface compiler.

The proposed shared library is `packages/zig/transit-compiler`, with its own
manifest, public module, README and checks. It owns graph composition, evaluation,
the working catalog and emission, using public Fuze/Catalog/SQL compiler APIs.
Fuze keeps pure syntax, types and expression lowering; Catalog keeps durable
identity, definition and dependency semantics. Neither gains a Station dependency.
Factor pure owner adapters where necessary rather than instantiating a live
service to compile offline. Source I/O, explicit repository fetching, cache
storage and output publication belong to the CLI/tooling layer. The future test
runner consumes the same library and emitter.

Specify these contracts before implementation:

- **Identity:** distinguish source/package content, source symbols, module
  instances, output targets, catalog objects and definition revisions. Bind a
  stateful instance explicitly. Existing objects require an explicit prior
  basis; new objects are allocated by ordinary runtime owners. Compilation
  neither allocates durable IDs nor hashes filesystem paths into them.
- **Resolution:** lock repository, exact revision, package subdirectory, verified
  content digest and transitive dependency closure. Define the hashed file tree,
  path normalization and permitted file kinds. Reject undeclared reads, path
  escapes, import cycles, mismatched digests and conflicting versions assigned to
  one stateful instance. Local overrides are explicit and enter provenance/cache
  identity. Do not execute repository hooks or package scripts to resolve source.
- **Ordering:** declaration dependencies determine a stable order with an
  explicit tie-breaker. Preserve declared mutation/verification order; do not
  reorder effectful statements merely because imports were sorted.
- **Completion:** build success means complete checked output for the selected
  capability profile. Check-only runs the same validation and emission checks
  without publishing artifacts. Diagnostic-only partial analysis never produces
  a successful executable target or silently omits unsupported declarations.
- **Diagnostics:** use [DIAGNOSTICS_V1](../../contracts/DIAGNOSTICS_V1.md), including
  definition/call sites, module instance, rule, limit and correction context.
  Its one-based lines/byte-columns and zero-based byte offsets take precedence
  over the milestone's informal coordinate wording. Preserve redaction.

Start with proposed budgets of 1 MiB per source file, 16 MiB aggregate source,
256 modules, 64 import/constructor depth, 100,000 evaluation steps, 64 MiB
compiler-owned allocated memory and 8 MiB emitted SQL per target. These are
reviewable compiler quotas, not measured performance guarantees. Account retained
source/graph/output separately from reusable scanner scratch, including allocator
backing capacity. Per-statement limits come from the selected runtime owner and
may be much smaller. No oversized atomic statement may be split to fit a limit.

A build has no live catalog, credentials, clock, randomness or application-effect
access. Runtime settings and secret references remain references wherever the
selected target supports them. Source maps and provenance contain no executable
semantics required to run the SQL.

## Implementation sequence and logical commits

| Commit | Work and owners | Required completion evidence |
| --- | --- | --- |
| 1. Specify the source/build profile | Define grammar roots, module interfaces, target capabilities, lock/provenance formats, budgets, diagnostics and CLI behavior. Freeze a small positive corpus and the new Platform source inventory. | Reviewed source examples and expected outcomes cover the complete first-slice journey; every unsupported construct has an owning boundary. Old fixtures remain unchanged. |
| 2. Extend shared source framing | Generalize Fuze's scanner/framer for source blocks, contextual keywords, matching END suffixes and exact spans. Add a compiler-file budget independently of interactive SQL and migration input limits. | Independent boundary fixtures above 50 KiB and 64 KiB, including nested comments/quotes, IF/ELSIF, CASE, FOR, ON FAILURE and malformed tails. Ordinary BEGIN/COMMIT still frame separately. UTF-8 diagnostics and exact-limit/over-limit cases pass. |
| 3. Implement resolved package graphs | Add explicit fetch/lock tooling and an offline resolver over supplied source buffers. Handle root/child builds, repository subdirectories, transitive locks and local overrides. | Cold explicit fetch followed by network-disabled rebuild; missing/stale locks, digest changes, undeclared files and dependency cycles reject. No shell recursion or implicit lock updates. |
| 4. Bind and evaluate typed modules | Implement interfaces, type/value/module arguments, exports, constructors, hygienic scopes and explicit instance bindings in the shared compiler. | Repeated instances, higher-order composition and terminating recursion work. Wrong interfaces, private imports, conflicting instances, capture and every budget exhaustion fail at attributable source sites. |
| 5. Check the supported working catalog | Stage declarations and bind dependent statements using existing schema, literal, constraint and query semantics. Keep proposed definitions separate from accepted objects and live grants. | Cross-file type/name/constraint failures reject; supported programs bind without a server. Private runtime storage, Queue/COMMAND programs, unsupported profiles and missing target capabilities reject without output. |
| 6. Emit and verify canonical SQL | Format the checked expansion with shared typed rules, then independently reparse/rebind it through ordinary compiler owners. Compare logical schemas, typed plans and operation order under the same explicit basis. | Hand-expanded and generated programs agree; identifier quoting, literals, NULL/cell-state and collation behavior survive. Output bytes are deterministic. Reparse success without semantic equivalence is a failure. |
| 7. Expose build targets and artifacts | Wire `transit build`, check-only and named targets into the CLI. Add cache identity/invalidation and bounded atomic output publication. | Compiler/contract/source/dependency/option/binding changes invalidate affected entries. Interrupted or failed builds leave no artifact marked complete; an older successful output remains distinguishable. JSON/human diagnostics share owner evidence. |
| 8. Qualify the caller journey and document it | Execute emitted SQL through the public SQL client/console with source packages absent. Publish supported syntax, limits and commands with the public owners. | Complete typed results and command counts match a hand-expanded oracle; revoked rights fail at execution. Path relocation keeps bindings stable. Real failure/recovery and allocation tests pass before PR submission. |

The contract commit must also decide whether any shared diagnostic or persisted
format changes are incompatible. Apply the existing current-v1 hard cutover only
where required, regenerate all affected consumers together, and retain rejection
of foreign definitions. A new source feature alone is not a reason to rewrite
unrelated native formats.

## Acceptance and validation

The first PR is complete only when all of these caller-visible checks execute:

1. Build the same composition from the root and child project, with an external
   package and an explicit local override. Rebuild with networking disabled and
   verify identical SQL for identical inputs. Compare cold/cached output and
   provenance; a cache hit is not the oracle for correctness.
2. Run generated SQL on a fresh instance through ordinary clients after removing
   source/package access. Inspect schemas, authoritative command counts, rows
   and verified terminal completion. Compare against independently hand-expanded
   SQL under equivalent explicit bindings, normalizing only runtime-allocated
   identities that are expected to differ between fresh installations.
3. Move source files/change import aliases without changing explicit bindings;
   confirm the same runtime declarations. Instantiate the same module twice with
   different bindings; confirm isolation. Conflicting version/instance mappings
   refuse before output publication.
4. Compile against explicit schema inputs while the test caller has runtime
   permission, revoke that permission, then execute and observe denial. Neither source exports nor
   build provenance bypass current authorization. Build evaluation itself makes
   no database or application-effect calls.
5. Exercise failed writes and lost replies using the existing statement and
   migration recovery owners. Recover the original saved SQL/operation after
   source and compiler inputs change; never rebuild or replay SQL as fresh work
   to resolve uncertainty. Explicitly authored migrations stay within their
   current file/step limits in this slice.
6. Exhaust each graph/evaluation/memory/output budget and interrupt output/cache
   publication. Assert bounded owned memory, cleanup and absence of a falsely
   complete artifact. Unsupported Platform declarations must fail with locations;
   the complete seven-file baseline is not a positive execution test yet.

Register new checks with [the task inventory](../../tests/runner/suite.json),
the relevant Just tasks and [fast checks](../../tests/runner/checks.json).
The final implementation requires the repository baseline gates:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

Run the affected compiler/package and independent grammar/emission checks,
`just check contracts`, dependent caller checks, `just test server-sql-types`
and the console latency gate in the pinned `ci-experience` shell. Run affected
committed-HEAD clean lanes, expected to include `core`, `storage-query`,
`installation-ui` and `interfaces-sql`; include `launchers` for executable
packaging changes. A shared-definition cutover expands this to all affected
bindings/SDK/browser consumers. SQL scalar/wire changes also require the full
[SQL interface validation loop](../../tasks/README.md#sql-interface-validation).
Finalize this matrix from the actual diff, not from a list of intended files.

Keep latency measurement separate from heavy concurrent builds. Record commands,
source revision, outcomes and proof limits before opening/updating the PR.
The M12 targets of sub-500 ms checking, sub-two-second full test/replay and over
35% duplication reduction are later measurements against a frozen workload;
they are not exit claims for this slice.

## Following slices under Milestone 12

| Slice | Deliverable and prerequisite |
| --- | --- |
| Module abstractions and full static checks, M12 P1–P3 | Expand PROFILE, pure FUNCTION and GUARD through the same graph/emitter. Add whole-program type, five-state, capability/operation settlement, secret-flow and activation-order checks. Protected wrappers such as BEARER remain protected values, not blanket declassification. Every early exit, failure path and loop needs analysis. Add PROCEDURE only after runtime module ownership and current-caller enforcement survive SQL lowering; preserve one enclosing transaction and forbid external effects inside it. |
| Migration capacity and evolution, M12 P0/P4 | Implement 1 MiB migration files and 256 steps across client, wire, planner, retained ledger and result envelopes after auditing aggregate/escaped message and record bounds. Then add explicit-basis catalog diffing, additive changes and conditional replacement with drain/pin/idle semantics. Refuse ambiguous/destructive transformations. Reuse DirectMigration and original receipts; never rewrite applied SQL or silently split a version. |
| Declarative testing, M12 P5 | Add `transit test` and test grammar over the production graph/emitter. Start with the supported Table fixture, then use real runtime owners for command/Queue execution as they qualify. Test clocks, identities, sink/observation mocks and crash schedules stay runner-owned. Unknown effects remain unknown; simulation does not establish remote idempotency or physical durability. |
| Expanded Platform qualification, M12 P6 and #430 | Convert the frozen seven-file application into the six domain modules, replacing cross-module storage writes with exported procedures/views. Add runtime capabilities only after their ordinary SQL owners qualify. Execute generated SQL without source access, verify explicit-basis migrations and compare all domain outcomes. Finish ingress, response handoff, browser authority, deadlines and installation/publication through #430 and their owning milestones. |

The test runner can begin once the first emitter and supported execution fixture
land; it need not wait for all replacement policies. Full Platform qualification
depends on both M12's toolchain and the remaining runtime work. Neither path
substitutes for the other.

## Proposed review decisions

- Approve one first implementation PR for the bounded recursive build path and
  its ordinary-SQL execution proof, with the logical commits above.
- Keep private runtime storage/procedures, full Platform execution, migration
  synthesis and `transit test` in the explicit following slices.
- Use M12 as the sequencing owner; retain #430 for unfinished runtime integration
  and preserve the earlier foundation's source-attributed evidence.

The [public application model](../handbook/reference/applications.md#planned-source-language-and-build-model)
and [compiler analysis](../handbook/internals/query-engine.md#planned-source-to-sql-compilation)
remain the architectural owners. Promote each implemented interface there and to
its exact contract as it lands.
