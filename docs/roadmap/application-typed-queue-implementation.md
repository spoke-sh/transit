# Typed public Queue programs: next implementation slice

[Milestone 12](12-application-modules-compilation-and-testing.md) · **Status: Proposed for review** · 2026-11-12

Let an application carry a source domain such as `MachineId` from a Queue input,
through a Table lookup and ordered program, into atomic Table and Stream outputs.
Reject substituting a `SiteId`, a raw integer or the wrong resource even when
the physical SQL types agree. Keep the output independently executable through
the existing public-data SQL owners.

This is the proposed first part of increment 2 in the
[remaining implementation sequence](application-remaining-implementation.md#delivery-sequence).
It extends the merged public Queue build/test slice with typed program operands
and exact resource composition. It does **not** complete increment 2: general
FUNCTION/GUARD/PROCEDURE declarations, runtime variants, refinements and richer
cardinality interfaces remain subsequent work. Establishing operand identity
before those abstractions gives their later expansion a checked foundation.

This document is a plan. Its examples and acceptance criteria describe proposed
support; the [source contract](../../contracts/APPLICATION_SOURCE_V1.md) remains
the owner of current behavior. Milestone 12 stays **In Progress**.

## Source basis and existing owners

The worktree starts at `6552747cf58a81cab0c60ad5c39e8e1568e9a007`, the merge of
[PR #450](https://github.com/spoke-sh/transit/pull/450). That change implements
public Queue source builds and isolated tests. Its merge does not by itself
establish full qualification. The PR records completed local gates and pending
qualification at submission; preserve those source-specific results and failures.
Before implementing this slice, reconcile the final CI artifacts and remaining
gates instead of inheriting a blanket pass or the previous submission exception.

| Owner at this basis | Implemented behavior | Extension needed here |
| --- | --- | --- |
| [SourceTypes](../../packages/zig/transit-compiler/src/SourceTypes.zig) | Nominal scalar identities; exact Table/Stream/Queue signatures and exports; domain-aware binding hashes | Reuse these identities for log schemas and program expressions; retain kind and exact resource binding |
| [TypedOperands](../../packages/zig/transit-compiler/src/TypedOperands.zig) | Table column annotations, same-domain assignments/predicates, checked operands before scalar erasure | Share annotation rules with logs; keep literal names and IDENTIFIER arguments subject to the same checks |
| [ResourceOperands](../../packages/zig/transit-compiler/src/ResourceOperands.zig) | Checks hole kinds; rejects nominal log types/values and symbolic log values; returns an empty operand projection | Bind actual log columns, predicates and values before erasure; produce meaningful checked evidence |
| [ProgramCheck](../../packages/zig/transit-compiler/src/ProgramCheck.zig) | Binds ordered public-data programs through Fuze and compares instructions/resource schemas; rejects every nominal dependency | Check source annotations across the existing instruction tree while retaining ordinary Fuze binding |
| [Compiler](../../packages/zig/transit-compiler/src/Compiler.zig), [WorkingCatalog](../../packages/zig/transit-compiler/src/WorkingCatalog.zig) | Typed expansion, proposed resources, independent SQL rebind and atomic product publication | Retain source-site/type associations through log/program checking; preserve the independent scalar verification pass |
| [ApplicationProgramTypes](../../packages/zig/transit-fuze/src/ApplicationProgramTypes.zig) | Physical types, lexical scopes, nullable reads, resource uses and host requirements | Remains the runtime semantic owner; no second physical type system or execution engine |
| [Source verification](../../tests/query/application_source/README.md), [test runner](../../packages/zig/transit-test/README.md) | Independent grammar/type comparisons and real isolated SQL execution | Extend the checked projection, corpus and installed fixtures for the new domain paths |

The [ordered-program contract](../../contracts/APPLICATION_PROGRAM_V1.md#definition-and-compilation)
already specifies nullable zero-row reads, failure on multiple rows, TRUE-only
guards, lexical lookup precedence and atomic rollback. This slice consumes those
semantics. It does not add a new cardinality operator, transaction coordinator,
program scheduler or persistent typed IR.

## Proposed scope and decisions

### Source types remain separate from runtime authority

Admit the existing BIGINT, TEXT and BOOLEAN source domains on non-null Stream
and Queue fields, using existing TYPE holes and exact resource signatures.
Retain the current restrictions on defaults, CHECK expressions and unsupported
semantic descriptors involving nominal fields. Table behavior remains unchanged.

A Queue field declared as `MachineId` supplies a source annotation when a program
reads that field. It does not authenticate a sender, prove that the ID exists,
or install a runtime domain. Ordinary SQL still sees its scalar type. A lookup
and explicit runtime guard establish existence when the application requires it;
current native policy establishes permission. Document and test this boundary.

The proposed catalog continues to own explicit object names and immutable schema
bindings. Paths, aliases and compiler ordinals do not become durable identities.
Imports and PUBLIC exports confer no permissions. Builds stay offline and emit
publication, authorization and activation as separate statements.

### Close every admitted operand path before removing a rejection

| Path | Proposed accepted profile | Required refusal |
| --- | --- | --- |
| Log declarations and exports | Non-null domain columns, exact kind/schema/domain signatures, existing export forwarding | Conflicting domain identity, wrong kind, changed schema or unsupported nominal column options |
| Standalone PRODUCE/ENQUEUE | Concrete source domain values in matching destination columns; explicit column lists and positional rows use the same mapping | Raw or foreign-domain values in nominal columns; nominal-to-raw erasure; unchecked omitted fields |
| Finite CONSUME | Direct nominal projections and same-domain equality/inequality predicates; assertions observe physical values | Nominal arithmetic, ordering, casts, derived expressions or aggregate erasure |
| Queue input and LET | Field projection and aliases retain domain, record shape and nullability | Dropping annotations through aliases, row projections or literal/IDENTIFIER resource names |
| One-record SELECT | Exact Table binding; selected fields retain domain; zero rows produce a nullable record and multiple rows refuse | Treating absence as a default or silently adding LIMIT 1 to hide cardinality failure |
| REQUIRE, IF and CASE | Same-domain equality/inequality, null tests, Boolean conditions and same-domain CASE results; a NULL arm preserves the other arm's domain and nullable state | Cross-domain comparisons/results, implicit construction, casts, arithmetic or function-based unwrapping |
| Atomic INSERT and log append | Exact destination field mapping; nominal domains agree before ordinary runtime preparation | Raw-to-domain or cross-domain assignment; mutation outside/nested atomic blocks |
| Failure continuation | Original input retains its annotations; failure metadata keeps its ordinary type | References to body/branch locals or inference of a domain from a failure string |

Check both runtime branches and every failure handler, including branches that
look constant. Preserve the current distinction between syntax checking in all
source bodies and type checking of reached source specializations. Unselected
compile-time MATCH arms retain their existing symbolic rules; symbolic program
declarations and controls remain rejected in this slice. Do not skip an arm to
admit a program or manufacture a value to evaluate it.

Concrete nominal constructor arguments may enter existing `$value` holes in
program expressions. Their exact source types must survive expansion until the
program checker consumes them. IDENTIFIER and resource holes remain valid only
in their declared positions. Program local names and labels remain ordinary
lexical names; this introduces no textual macro facility.

Ordinary non-nominal expressions retain Fuze's supported behavior, including
host-requirement checks. Calls consuming nominal values reject unless an explicit
rule above admits them. In particular, hashing, JSON construction and text casts
cannot silently remove a domain. Time/random helpers do not become pure merely
because a source checker accepts their physical result type.

Conditions require an ordinary Boolean; a Boolean-backed domain does not
implicitly unwrap. The Queue acquisition WHERE predicate receives the same
annotation checks and must still lower through the existing native predicate
owner. Expression type acceptance alone cannot enable unsupported acquisition
predicates or host calls.

### Preserve optional reads, order and failure boundaries

The checked source representation records a scalar's domain and nullable state,
record fields, and the existing zero-or-one read contract. Field access on an
absent record remains NULL. Do not claim general five-state or many-row program
values where the installed owner does not provide them. Unsupported combinations
reject explicitly; missing/type-error/conflict cases retain their existing owner
behavior rather than being converted into ordinary values.

Keep runtime validation of nullable values at required write boundaries.
A source annotation does not prove a prior REQUIRE ran or that a read returned
a row. Preserve lexical binding precedence over bare SELECT column names, scope
exit, instruction order, first-boundary input ACK, later checkpoints and verified
abort before failure-handler entry. No guard folding, instruction reordering,
common-subexpression elimination or atomic-boundary changes are in scope.

### Keep source evidence and executable SQL verification distinct

Extend the compiler's in-memory checked projection with program node/source
sites, domain identities, resource/column associations and ordered reads/writes.
Use the existing Fuze program AST and physical binder; a compiler-owned annotation
pass adds source-only obligations. Factor reusable pure traversal/lookup APIs
where necessary so the source pass follows the same lexical rules. Keep source
Graph references out of Fuze's retained/runtime types.

The emitted SQL cannot reconstruct erased nominal identities. Therefore:

1. Check source bindings and annotations against the expanded AST before erasure.
2. Retain an independent verification projection for the admitted nominal fragment.
3. Reparse SQL into a fresh ordinary catalog and compare ordered physical program,
   schema, dependency-use and atomic-boundary projections.
4. Compare generated execution with independently authored SQL and expected rows.

Do not treat a matching scalar fingerprint as proof that domain checking occurred.
Do not rely on equal token widths to associate an operand with its source type;
track expanded spans and node associations explicitly, including negative values,
escaped strings, quoted resource names and repeated holes. Retained projections
must not point into reset scratch arenas.

No native wire/storage or accepted program-codec change is intended. Audit that
claim before implementation. If a required change alters persisted semantics or
an ABI, scope it explicitly in the owning contract and follow the current-v1 hard-cutover
policy, including generated consumers and rejection evidence. Do not add a v2 or
a hidden compatibility path. Compiler/source identity must invalidate affected
build products even when erased SQL bytes remain equal.

## End-to-end fixture and acceptance

Add a public synthetic typed Queue fixture alongside the
[existing untyped Queue fixture](../../tests/fixtures/application-queue-programs/README.md)
and [compile-time typed-target fixture](../../tests/fixtures/application-typed-targets/README.md).
Retain both existing fixtures and their independent oracles.

The new fixture declares `RequestId`, `MachineId` and `SiteId`, with deliberately
overlapping scalar values. An input Queue carries a RequestId, MachineId and public
payload. A public Machine Table supplies the referenced row. The program reads it
inside its atomic block, requires its presence, inserts an accepted row and emits
a Stream row. A later guard can refuse after the insert has been staged, proving
that neither staged state nor output survives. A same-domain CASE and LET alias
exercise propagation without new runtime dispatch semantics.

Compose the resource and program modules through exact imported signatures.
Instantiate the same modules under two explicit sets of resource/program names;
verify independent outcomes. Relocate source files and change import aliases
without changing those explicit bindings. Include child targets and a pinned
repository import in the existing offline build journey, with fresh provenance
and unchanged executable behavior.

The minimum acceptance matrix is:

| Case | Required observation |
| --- | --- |
| Valid typed input and matching row | Exactly the expected Table and Stream rows plus recorded completion; independent SQL oracle agrees |
| Missing referenced row | Recorded refusal and no partial state/output; NULL is not a substituted ID |
| Lookup with two matching rows | Cardinality refusal with no writes; use a separate non-unique lookup predicate, not duplicate primary keys |
| Refusal after staged insertion | Aborted state/output, then only the declared failure-handler outcome where present |
| Wrong domain with identical scalar representation | Build refusal at assignment, comparison, append, CASE or interface boundary before artifact publication |
| Raw, literal-name or IDENTIFIER bypass | Same domain checks as typed handles; raw SQL remains governed by its documented scalar contract |
| Branch/scope failures | Invalid unchosen runtime branch and failure-local capture reject; nullable reads and lexical-name collisions follow the shared binder |
| Lost append/commit reply and restart | Recover the original token/invocation and exact outcomes; no resubmission as new SQL or recompilation of accepted work |
| Current permission revoked after build | Ordinary publication/execution/disclosure refuses through the same native owner; build output grants no rights |
| Source-free, offline execution | Locked build is deterministic; ordinary client runs emitted SQL with source packages absent |
| Bounds and cleanup | Oversized programs, depth/work/output/memory exhaustion and allocation failure publish no complete artifact; isolated cases join all borrowers |

Use existing WORKFLOW assertions for exact recorded counters and complete Table/
Stream row assertions for data. Counters do not prove Queue emptiness or idleness,
and cancellation of an empty acquisition can add a refusal. Observe the frozen
definition and preserve the existing assertion budgets. The source runner has no
per-invocation refusal-reason assertion; use the owning native/component proof
where exact refusal attribution is needed rather than inventing source syntax.

## Logical implementation commits

1. **Specify the closed profile and independent expectations.** Update
   `APPLICATION_SOURCE_V1.md`, source grammar documentation/corpus and diagnostics
   inventory with accepted/rejected domain paths and exact stage rules. Define
   checked projections and the synthetic oracle. Existing grammar may already
   express the forms; change productions only when a real syntax gap is identified.
   Contract-first work must label unimplemented support until its code lands.
2. **Check nominal log schemas and operands.** Extend shared annotation/catalog
   handling and ResourceOperands for declarations, exports, append column mapping
   and finite reads. Cover literal/IDENTIFIER access and allocation failures.
   No path can depend only on hole-kind checking.
3. **Propagate domains through ordered programs.** Add the compiler-owned typed
   annotation pass over the existing AST; preserve lexical scopes, nullable
   records, branch joins and field assignments. Keep Fuze physical checking and
   installed host capability checks. Replace `UnsupportedNominalProgram` only
   after all admitted expression/instruction paths are checked.
4. **Bind evidence to emission and prove the selected fragment.** Extend Step
   evidence and independent verification without changing installed artifacts.
   Add scoped Lean laws for domain-preserving substitution/projection and
   order-preserving erasure of the admitted expression/action fragment. Extend
   independent finite comparisons across source annotations, production checked
   nodes and ordinary SQL; include controls that erase or swap a domain and
   reorder guarded actions. Audit premises and axioms explicitly.
5. **Execute the complete application journey.** Extend compiler/source-type
   fixtures and real application build/test journeys with the matrix above,
   independent SQL, offline/relocation cases, current-rights denial and original
   recovery. Reuse production owners and existing fault hooks; no test interpreter.
6. **Promote supported behavior and qualify the committed result.** Update the
   application/CLI/package references and internals where behavior changes.
   Reconcile stale source-emission exclusions in the managed-program references
   with the existing public source profile. Record actual evidence and limitations
   in qualification history, then link it from this plan and the milestone.

These are logical commits within one complete executable slice, not permission
to publish a half-checked nominal path. The formal claims are limited to their
stated fragment and premises; they do not prove arbitrary source programs, the
runtime or external ID validity. Existing native recovery checks remain required.
No new temporal state machine is introduced, so this slice adds no new TLA+ claim.

## Validation and completion gates

For this **plan-only** change, run the baseline checks below and the documentation
source-link check. Runtime suites are not required and a documentation pass
establishes no implementation result.

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
nix develop --command python3 -B tests/runner/docs.py
```

For implementation, use the existing
[application source tasks](../../tasks/README.md#application-source-checks):

| Area | Required checks |
| --- | --- |
| Compiler, grammar and annotation evidence | `just test application-compiler`, `just test application-source-grammar`, `just test application-source-types`; full corpus, formatter, negative controls and selected Lean proofs |
| Real build and test execution | `just test application-runner`, `just test application-build`, `just test application-test`, `just test application-test-host`; exact counts/rows, recovery, denial and joined cleanup |
| Shared contracts or Fuze interfaces | `just check contracts` and affected package/caller checks; retain ordinary untyped program behavior and frozen-definition checks |
| CLI/SQL build and execution | `just test console-latency-gate` and `just test server-sql-types` using the pinned `ci-experience` shell; complete unchanged performance profile |
| Committed implementation before push | Affected clean `storage-query`, `formal`, `installation-ui` and `core` lanes selected from the actual diff and suite inventory; add dependent lanes if shared contracts expand |

Keep the existing 4,096-byte executable statement limit, thirteen dependencies,
single input partition, compiler budgets and test deadlines. Do not split a
program's atomic declaration to fit a limit or weaken performance budgets.
Allocate statement scratch and retained evidence separately under the existing
shared memory budget; no per-row arena construction or unbounded annotation maps.

Re-run affected gates on the final contents. Finish validation before pushing
implementation or opening/updating its PR, as required by the repository rules.
Record exact source/tool/artifact identities, commands, failed attempts and later
results. Planned cases, installation, skipped suites and partial reports are not
passes. The previous PR's immediate-submission instruction does not carry over
to a future implementation PR.

Completion means the full declared operand profile passes the acceptance matrix,
ordinary generated SQL needs no source sidecar, public owners explain its limits,
and final qualification is attributable. Remaining increment-2 work is then
explicit: helper declarations and signatures, broader cardinality/refinements,
runtime variants and symbolic program composition. Runtime module protection,
protected workflows, migration synthesis and replacement retain their later
dependency gates in the remaining implementation plan.
