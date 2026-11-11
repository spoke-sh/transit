# Nominal values, typed Table exports and exhaustive source matching

[Milestone 12](12-application-modules-compilation-and-testing.md#next-language-slice) · **Status: Implemented — qualification in progress**

The implementation follows merged planning PR #442. The executable source
contract now owns the delivered syntax and restrictions; this document retains
the reviewed scope. Compiler and correspondence checks are executing against the
implementation, while the complete required qualification remains in progress.
This status is not a clean-lane or runtime pass.

Let an application distinguish two resource kinds even when their IDs have the
same scalar representation, pass a Table through a checked module interface,
and select a variant without forgetting a case. Deliver these capabilities
through the existing offline compiler, ordinary emitted Table SQL and real
`transit test` cases. Include a small Lean preservation specification with
independent implementation comparisons in the same implementation PR.

This is the first executable part of M12's typed-target design case. Selection
is **compile-time specialization** in this slice. It does not implement a command
that branches on a live request, read database rows into build evaluation, or
claim that a nominal ID proves the existence or readiness of a resource.

## Source basis and consumer problem

Reviewed Transit main at `5df71dc89`, including merged
[PR #441](https://github.com/spoke-sh/transit/pull/441). The
[previous plan](application-source-grammar-implementation.md) still records
qualification in progress: the PR disclosed unfinished clean lanes and latency
validation. Merging it does not turn those checks into passes. Preserve that
record and resolve any relevant outstanding failures before qualifying this
implementation; this planning change establishes no new runtime evidence.

The consumer review uses the local Platform checkout at `97f69c71a`, under
`apps/platform/`. Its `ingress/endpoints.transit` selects between two kinds using
a text tag, a UUID and a revision, then repeats different lookups and readiness
checks. Its domain build files export views and reference-only Table keys.
Those programs are an explicitly proposed consumer contract, not an executable
baseline for the current Transit source compiler. Do not copy their private
source, provider wiring or business policy into Transit fixtures.

The synthetic acceptance application will instead select between `Machine` and
`Site`, both with a raw ID of `7`, and insert into the correctly bound public
Table. The wrong nominal ID, wrong exported Table or omitted match arm must fail
before an artifact is published. This isolates a useful language guarantee from
the later command, authorization, observation and effect machinery.

| Existing owner | Implication for this slice |
| --- | --- |
| [Source contract](../../contracts/APPLICATION_SOURCE_V1.md), [source grammar](../../contracts/application-source/README.md) | Extend the current source language and its independent oracle together. Source forms remain separate from ordinary SQL and interface/UI entry points. |
| [Syntax](../../packages/zig/transit-compiler/src/Syntax.zig), [Graph](../../packages/zig/transit-compiler/src/Graph.zig) | Parameters currently cover three scalar kinds, identifiers, scalar types and module constructors. Public imports do not yet expose nominal types or instantiated resource exports. |
| [Compiler](../../packages/zig/transit-compiler/src/Compiler.zig), [WorkingCatalog](../../packages/zig/transit-compiler/src/WorkingCatalog.zig) | Evaluation emits SQL while checking proposed schemas. Scalar emission alone loses nominal distinctions; introduce a checked representation before that erasure. |
| [Table source profile](../../contracts/APPLICATION_SOURCE_V1.md#executable-target) | Ordinary Table DDL/DML and single-Table queries are available. Runtime-private Tables, foreign-key resolution, procedures and command workflows remain outside this compiler profile. |
| [Table test runner](../../packages/zig/transit-test/README.md), [CLI proofs](../../tests/interfaces/cli/application_test.py) | Reuse isolated real database owners, complete typed results and authoritative command counts. Do not add a second evaluator or mock database. |
| [Existing Lean checks](../../tests/query/sql/rewrites.py), [verification limits](../handbook/reference/verification.md) | Reuse pinned tools, exact theorem inventories and axiom auditing. Add source-specific semantics and correspondence tests; existing SQL theorems do not prove this compiler. |

## Review boundary

Deliver together:

- Nominal source domains over the existing `BIGINT`, `TEXT` and `BOOLEAN`
  compile-time scalars, with explicit construction and stable logical identity.
- Public type exports, exact nominal parameter/interface checking, finite closed
  variants and exhaustive compile-time `MATCH` with hygienic payload binders.
- Named module-instance results containing typed **public Table** exports;
  Table arguments retain their explicit binding and annotated schema.
- Checked nominal operands for the admitted Table operations, before scalar SQL
  emission, plus independent binding/SQL/outcome comparisons.
- Source grammar, formatter, structured diagnostics, bounds, CLI fixtures,
  selected Lean laws and public documentation for the delivered profile.

Defer runtime variant values/dispatch, stored sum types, UUID source constructors,
refinement predicates, optional/one/many query operators, generic recursive data
types, functions/guards/procedures, private storage, reference-only foreign-key
exports, effects, continuations, state machines and migration synthesis.
Do not represent a reference-only export as a readable/writable Table handle to
make a consumer compile. Those have different contracts.

This intentionally narrows the full typed-target case to capabilities the Table
backend can execute now. The broader case still requires typed runtime inputs,
cardinality, current authority, exact revision/evidence validation and reference
exports that preserve native foreign keys.

## Language and identity decisions

Freeze the following forms in `APPLICATION_SOURCE_V1` and the ANTLR corpus before
implementing their parser. The spellings here are **proposed**, not runnable
syntax in the merged compiler:

```text
CREATE PUBLIC DOMAIN MachineId AS BIGINT IDENTITY 'example.machine-id';
CREATE PUBLIC DOMAIN SiteId AS BIGINT IDENTITY 'example.site-id';
CREATE PUBLIC VARIANT Target AS (
  Machine(id MachineId),
  Site(id SiteId)
);
```

Use qualified constructor expressions such as
`targets.Target.Machine(ids.MachineId(7))`. Extend qualified source references
deliberately; the current two-component name representation is insufficient for
an imported type's constructor. Source keywords remain contextual and existing
SQL identifier rules remain unchanged.

### Nominal domains

Separate a domain's explicit logical identity from its public source spelling
and definition digest. The identity is 1–128 UTF-8 bytes, compared exactly without
case folding or Unicode normalization; the definition fixes its base type.
Imports and re-exports preserve the original
declaration. Reject two independent declarations claiming the same identity,
even if their base types match; shared use imports the one declaration. Reject
conflicting definitions across dependency versions. Moving a file or changing an
import alias must preserve nominal compatibility when the explicit identity and
definition are unchanged. Input/provenance digests can still change.

These are source type identities, not newly allocated catalog IDs, authority
objects or proof of installed schema compatibility. Explicit Table bindings keep
their existing meaning. Do not infer identities from file paths, traversal
ordinals, physical scalar types or hash equality alone.

Construction accepts a base-typed compile-time value and produces that domain's
value. It asserts a declared source type, not resource existence, permission,
freshness or a refinement. No implicit raw-to-domain or domain-to-domain
conversion, arithmetic, ordering or general unwrapping is admitted. Equality
requires the same domain and definition. Reject a nominal argument passed to a
raw scalar parameter; callers cannot erase it and silently rebrand it.

`TYPE` operands may carry an exported nominal domain into a Table column.
Domain annotations initially require non-null columns; defaults and CHECK
expressions involving those columns reject until their typed construction and
predicate rules are specified. Preserve ordinary
physical types, collations, key constraints and runtime values; do not invent a
new storage codec or add nominal tags to native scalar encodings. Existing
unannotated SQL retains its documented NULL/five-state behavior.

### Closed variants and MATCH

A variant has a finite, nonempty set of uniquely named constructors with named,
ordered payload fields. Start with raw scalars and nominal domains as payloads;
recursive/nested variants, polymorphic variants and wildcard cases reject.
Use the resolved declaration and definition as variant identity, preserving
import aliases as references to that declaration. A variant is a compile-time
value; passing one into a SQL literal/type/identifier position rejects.

`MATCH value WHEN Type.Constructor(payload_names) THEN ... END MATCH;` must name
every constructor exactly once with the correct arity. Bind payloads lexically;
reject duplicate binders and prevent capture of module parameters/imports.
Typecheck every arm for each reached specialization, including an arm not
selected by the concrete constructor. Use symbolic payload types, not invented
values; recursive calls are checked against signatures without evaluating an
unselected recursion. Use isolated proposed-catalog branches;
only the selected arm contributes declarations, statements and test actions to
the enclosing composition. Every admitted arm must be valid from the same
incoming catalog. Selected-arm outputs alone are available afterward.

Charge all arm checking to deterministic work/memory budgets. Recursion uses
the existing depth/work limits. Unused module bodies retain the current
all-body structural checks; this slice does not promise unrestricted generic
whole-program type inference. Preserve existing `IF` stage rules rather than
silently extending this stronger MATCH check to all older source constructs.

### Typed public Table exports

Extend `USE constructor(arguments) AS instance;` to bind an immutable instance
result. Inside that constructor, `EXPORT TABLE $table_name AS rows;` exposes
only an already declared PUBLIC Table belonging to that instance. Existing
`USE` without a result binding remains valid. Exporting a missing Table, another
instance's Table or a conflicting export name rejects. Re-exporting the same
handle forwards its original identity and cannot instantiate another Table.

The `instance.rows` value carries the explicit Table name/binding, definition
fingerprint, ordered columns, keys/nullability/collations and nominal annotations.
It is neither a string nor an allocated runtime Table ID. Introduce Table
parameter signatures, for example `rows TABLE(id MachineId PRIMARY KEY)`;
compare the complete declared schema and nominal annotations exactly in this
slice. No structural width subtyping or read/write effect inference is implied.
Higher-order module interfaces compare these signatures too.

A Table operand lowers only in a Table-name position. It cannot be used as a
scalar, type, column name or ordinary `IDENTIFIER` value. Keep identifiers for
declaring explicit instances; use Table handles for checked composition between
them. Handle equality/forwarding preserves the original binding. Duplicate
instantiation still fails even when two exports have different source aliases.

Every exported Table is already public to ordinary runtime authorization. This
adds source interface checking, not runtime encapsulation or a capability grant.
No source import or valid signature bypasses current catalog permissions.

## Checked core and SQL lowering

Add small owning modules inside `transit-compiler` for interned source types,
typed values/resource bindings and checked statement operands. These are
implementation modules, not another package, persisted IR, resolver or execution
engine. Keep resolved source spans and definition/call attribution through each
stage. Do not add empty effect sets or placeholder transition nodes.

The proposed sequence is:

```text
source AST -> resolved declarations -> checked specialization/operands
           -> erased ordinary Table SQL -> independent ordinary SQL rebind
```

Retain a source annotation layer alongside the existing proposed Table schema.
Check nominal operands against resolved target columns **before** writing SQL
bytes. Checking only the constructor's parameter types is insufficient: a module
could otherwise insert a Site ID into a Machine column with the same base type.
All accesses to an annotated Table, including literal names and `NAME` arguments,
must consult that same layer; name spelling is not an escape hatch.

For nominal columns, admit direct projection, equality/inequality between the
same nominal type, and direct INSERT/UPDATE assignments of that type. DELETE
and SELECT can use those predicates combined with existing Boolean operators.
Reject raw literals in nominal positions, mixed-domain comparisons, arithmetic,
casts, aggregates and functions that discard a nominal distinction. Other
columns retain their ordinary supported operations. Expected runtime rows in
`ASSERT ROWS` remain schema-bound base values: observations are not source
constructors and cannot flow back into compilation.

Bind column identity and operand roles using the parsed templates and owning
Fuze plans. Do not implement a second SQL type system or use SQL-text heuristics
to guess target columns. If a required role is unavailable, extend a bounded
owner API or reject that combination explicitly. Check positional/named INSERT,
UPDATE targets, qualified/aliased columns and predicate operands so each admitted
spelling preserves the same rule. No unchecked fallback after scalar erasure.

Emission strips domain/variant/module/export forms, quotes the bound Table name
and emits the chosen scalar operands. Match specialization preserves statement
order and emits no runtime branch. The generated SQL is complete without source
files, type metadata, ANTLR, Lean or a privileged executor. Independent ordinary
SQL rebind still compares ordered schema/plan fingerprints; a separate typed
comparison must catch swapped domain identities that scalar fingerprints cannot.

The guarantee is that this source compiler refuses inconsistent typed programs.
Direct SQL still accepts its ordinary scalar types, and external rows are not
implicitly trusted as nominal values. Runtime domain enforcement and validation
of dynamic input require a future SQL/catalog contract and are not supplied by
erasing annotations or by a provenance sidecar.

Keep current native definition and artifact formats unless the implementation
identifies an incompatible persisted semantic change. Include the new type,
variant and export bindings in deterministic compilation/provenance digests;
maintain existing executable/source/native identities and cache verification.
If an artifact schema must change incompatibly, apply the owning current-v1
cutover with explicit rejection fixtures, never a fallback decoder or v2 label.

## Formal evidence and independent comparisons

Place the source semantics in a proposed
`contracts/application-source/TypedTarget.lean`, with a dedicated bounded
verification driver and task. Reuse the repository's pinned Lean tool and axiom
audit discipline without coupling new source laws to the SQL rewrite inventory.

Specify two evaluators over a small, explicit typed-target language: source
constructor/MATCH evaluation and an ordered, bound Table-action interpretation
after specialization. Require named theorems for:

1. **Nominal substitution:** replacing a parameter with a value of its declared
   type preserves typing, including distinct domains with equal base values.
2. **Exhaustive selection:** a well-typed closed variant and complete unique arm
   set select exactly one arm with correctly typed, capture-free payload binding.
3. **Specialization preservation:** evaluation and lowering agree on the ordered
   bound Table actions and base values for the admitted fragment.

State premises explicitly: checked environments/signatures, unique explicit
Table bindings, supported scalar encoding, successful bounded evaluation and
the modeled fragment. Do not assume the preservation conclusion as a premise or
define both evaluators as aliases of the same function. Runtime authorization,
SQL parsing/storage correctness, allocation failures and concurrent histories
are outside these theorems. Record their implementation correspondence limits.

Require exact theorem-name coverage, complete kernel checking, printed axiom
sets, no `sorry`/`sorryAx`, no unreviewed axioms and no warnings. Fail on a missing
theorem, failed invocation or incomplete output. Exercise deliberate omitted
proof and admitted-proof controls so a verifier that merely exits zero cannot
pass. Keep such controls outside the production specification.

Extend the independent ANTLR corpus and private compiler projection to compare
types, nominal identities, Table bindings, constructors and all match arms. Use
hand-authored expected actions and a bounded independent evaluator; do not derive
the expected domain from the production emitter. Compare that model, Lean's
evaluated finite examples, Zig's checked actions and actual emitted-SQL outcomes.
Include mutants that swap domains/tables with identical physical schemas, omit
an arm, change a payload, duplicate an action or discard a result.

TLA+ is reserved for the next admitted temporal behavior: competing admissions,
atomic claim/enqueue/handoff, revision fencing and interruption/replay. This
slice introduces no such transition and no new TLC result. Its typed bindings
and explicit branch semantics are inputs to that later abstraction, whose finite
safety/liveness assumptions and native trace correspondence must land with the
transition implementation. Neither Lean nor shared model/SQL generation proves
the entire compiler or Platform application.

## Implementation sequence and logical commits

| Commit | Deliverable | Gate |
| --- | --- | --- |
| 1. Specify the typed-target profile | Source contract, identity/erasure rules, proposed grammar and independently authored positive/negative expectations | Every new form has a static meaning, lowering and explicit runtime limit; review includes the same-scalar wrong-domain case. |
| 2. Add typed declarations and values | Syntax/Graph/type owner, public domain/variant exports, constructor expressions, stable identity checks and diagnostics | Exact import/interface checks, conflicting identities, allocation cleanup and bounded type graphs. |
| 3. Add typed Table instance exports | Bound USE results, export schemas, Table parameters, annotated proposed catalog and source operand checks | Same-schema wrong-domain Table and raw-name bypasses reject; alias/path changes preserve explicit bindings. |
| 4. Specialize exhaustive matches | All-arm checking, hygienic substitution, isolated catalog branches, SQL emission and formatter updates | Missing/duplicate/wrong arms fail; ordered SQL and equivalent existing programs survive round-trips and ordinary rebind. |
| 5. Prove and execute the fragment | Lean laws/driver, independent typed comparisons, real build/test fixtures and negative controls | Exact proof inventory and finite correspondence pass; both target kinds execute through ordinary SQL with complete outcomes. |
| 6. Integrate and publish | Tasks, dependency selection, inventories, public references and source-attributed qualification | Final committed-source required checks pass; limits and outstanding runtime work remain explicit. |

Do not introduce implementation/test commits in this planning PR. Keep the
implementation in one reviewable PR with the logical commits above.

## Acceptance journeys

| Journey | Required evidence |
| --- | --- |
| Compose both kinds | Child and parent builds use the same exported types/Tables; Machine(7) and Site(7) produce the independently expected ordered SQL, rows and counts in separate isolated cases. |
| Refuse mistakes | Wrong ID domain, Table schema/domain, constructor payload, missing/duplicate arm, raw-literal bypass and invalid SQL operand position fail at a located documented stage with no complete artifact. |
| Check unselected arms | An unselected wrong-domain call or malformed SQL arm fails; checking that arm emits no SQL, test action or leaked proposed Table. |
| Preserve identity | Import alias/file relocation, module forwarding and frozen local/repository resolution preserve explicit domain/Table bindings; conflicting dependency definitions and duplicate instances reject. |
| Preserve SQL behavior | Hand-expanded SQL and emitted SQL agree on schemas, rows, command counts and existing constraint refusals. Run generated SQL through the ordinary caller with source/provenance unavailable. |
| Preserve runtime authority | Compile successfully, then deny or revoke Table access before execution; the ordinary SQL owner refuses. Typed imports do not override permissions. Do not add a source SUBJECT/grant-control language for this fixture. |
| Preserve stages and bounds | Full grammar/formatter round-trips, correct byte locations, deterministic type/arm/export limits under existing budgets, allocation-failure cleanup and no complete output after failure. |
| Establish scoped proof evidence | Named Lean laws, audited premises/axioms, exact finite comparison coverage and intended negative controls; no missing cases, subprocess errors or partial results count as passes. |

Reuse the 1 MiB/file, 16 MiB source, 64-level, 100,000-work, 64 MiB compiler and
8 MiB SQL limits. Cap variant constructors, fields per constructor and exports
per instance at 64 each, consistent with the existing parameter limit; Table
signatures also retain the owning Table schema's limits. Charge interned
types, branch catalogs and retained checked operands to the same memory owner.
Use reusable scratch for branch/statement preparation; no unbounded expansion
or increased production quotas to fit a proof. Record cold build/check/test and
verification costs separately without promising a new performance target.

## Validation and documentation owners

This documentation-only plan requires the repository baseline:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

For implementation, run `application-compiler`, `application-source-grammar`,
`application-runner`, `application-build` and `application-test` through their
owning Just tasks, plus the proposed `test::application-source-types` task for
Lean and typed correspondence. Register that task and its tool prerequisites in
the suite, dependency selection, fast inventory and invariant inventory; place
the formal task in the `formal` lane. Fast inventory checks do not execute it.

Run `just check contracts`, the existing SQL/interface grammar regressions when
their shared owners change, and `sql-rewrites` if shared Lean tooling changes.
Before pushing implementation/test infrastructure, run affected committed-HEAD
clean lanes: expect `storage-query`, `installation-ui` and `formal`; include
`core`, `sdks-conformance` or other dependent lanes when the actual diff selects
their owners. Do not infer selection from a task's name or treat a task listing
as a completed lane.

Include `server-sql-types` and the pinned `ci-experience` console latency gate
for the changed CLI build/test paths. Run the latency measurement after this
task's heavy builds; preserve budgets and leave unrelated user work running.
SQL scalar/wire/ABI changes are outside the intended scope and would require
their owning validation loop and contract decision. A failure or incomplete
required gate prevents qualification; a prior merged PR is not a substitute.

Publish delivered syntax and limits in the source contract, its grammar README,
the compiler README and the application reference. Update the compiler account
with actual checked representations, lowering assumptions and proof boundaries.
Keep private test projection formats out of public runtime contracts. Record
commands, source/tool/artifact identities, raw evidence, completed outcomes and
limits in the qualification ledger. This plan records requirements, not passes.

M12 remains **In Progress**. After this slice, select dynamic typed query results
and reference-only exports before claiming the full two-kind command case; then
introduce ordered guards and atomic admission/continuation transitions with
their runtime owners and TLA+/native trace gates. The broader application runtime
continues under [tracker #430](https://github.com/spoke-sh/transit/issues/430).
