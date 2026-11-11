# Application source grammar and typed-core contract implementation plan

[Milestone 12](12-application-modules-compilation-and-testing.md#next-language-slice) · **Status: Implemented; qualification in progress**

The reviewed scope below is implemented by the dedicated source grammar,
structural Table templates, compiler-package formatter and independent
AST/product comparison. It adds no domain/effect syntax or new formal theorem.
The implementation starts from merged planning PR #440 at `66fcb5931`.
The acceptance commands below remain requirements, not passing evidence until
their completed runs are recorded in the qualification ledger.

Give application authors an independently checked definition of the language
already accepted by `transit build` and `transit test`, and give subsequent
language work a precise compilation contract. Deliver the source ANTLR grammar,
production-parser correspondence, bounded source round-trips and typed-core
contract in one implementation PR with the logical commits below.

This is the next bounded part of M12 P0/P1 after the Table build and test slices.
It does not implement domain-type syntax, effectful commands, capability transfer,
workflow execution or migration synthesis. Those constructs remain subsequent
slices governed by the core contract established here.

## Source basis and existing owners

Reviewed merged main at `28d91dfda`, including [#437](https://github.com/spoke-sh/transit/pull/437),
[#438](https://github.com/spoke-sh/transit/pull/438) and the language/grammar
orientation in [#439](https://github.com/spoke-sh/transit/pull/439). These are
source observations, not new executed qualification. Recheck the baseline before
implementation if main advances.

| Owner | Existing behavior and implication for this slice |
| --- | --- |
| [Application source contract](../../contracts/APPLICATION_SOURCE_V1.md) | Defines the bounded module/build/test language and explicitly records the missing ANTLR reference. Extend this owner; do not use the interface/UI contract as a source-language specification. |
| [Syntax](../../packages/zig/transit-compiler/src/Syntax.zig) | Public source AST and parser cover imports, dependencies, interfaces, modules, targets, expressions, conditionals, tests and assertions. SQL bodies and expected rows retain token slices; the parser is not a whole-program semantic checker. |
| [Graph](../../packages/zig/transit-compiler/src/Graph.zig), [Compiler](../../packages/zig/transit-compiler/src/Compiler.zig), [WorkingCatalog](../../packages/zig/transit-compiler/src/WorkingCatalog.zig), [Test](../../packages/zig/transit-compiler/src/Test.zig) | Resolve/evaluate the graph, substitute typed operands, prepare Table statements, construct test plans and independently reparse emitted SQL. Preserve these production owners and their limits. |
| [SqlInput](../../packages/zig/transit-fuze/src/SqlInput.zig), [SqlScript](../../packages/zig/transit-fuze/src/SqlScript.zig) | Shared byte-based scanning and compound framing precede source parsing. Changes can affect console/migration/runtime consumers and expand required regression gates. |
| [SQL grammar](../../contracts/sql/TransitExtensions.g4), [independent SQL adapter](../../tests/query/sql/reference.py) | Reusable syntax, pinned ANTLR generation, strict errors and ambiguity detection exist. SQL has broader syntax than the executable source profile. Reuse rules without importing broader runtime support by implication. |
| [Application interface grammar](../../contracts/application/Application.g4), [its proof](../../tests/interfaces/installation/application_grammar.py) | Cover interface/UI declarations and model round-trips, not modules/builds/tests. Preserve their separate grammar, task and scope. |
| [Build proof](../../tests/interfaces/cli/application_build.py), [Table test proof](../../tests/interfaces/cli/application_test.py) | Existing CLI, frozen resolution, emitted-SQL and runtime regression oracles. Reuse their synthetic fixtures and complete outcomes; do not recreate the runner or resolver. |

## Review boundary

Include:

- A dedicated `contracts/application-source/TransitSource.g4`, README and
  independently authored positive/negative corpus for the delivered profile.
- Explicit source lexical rules, precedence, block boundaries, typed SQL holes,
  build/test stage rules and source-location conventions.
- A private Zig verification executable calling the real compiler package, an
  independent ANTLR adapter, and comparisons against hand-authored expectations.
- Source syntax fixes needed to satisfy the reviewed contract, including full
  syntax checking of admitted embedded Table templates. Keep graph/type/runtime
  failures distinct from syntax failures.
- A bounded canonical source round-trip facility in the compiler package,
  exercised by the private driver. This is not a new public CLI command.
- A compilation/core contract describing current typed stages and the explicit
  obligations that future domain types, effects and transitions must satisfy.
- Task/inventory integration, existing build/test regressions, current public
  grammar documentation and attributed qualification evidence.

Do not add `PROFILE`, `FUNCTION`, `GUARD`, `PROCEDURE`, nominal-type, variant,
refinement, state-machine or temporal-property syntax in this slice. Do not add
an ANTLR runtime dependency, a second compiler/resolver, a semantic sidecar needed
to execute SQL, provider mocks, new deployment authority or a source formatter
CLI. The broader three synthetic design cases in M12 inform the core contract;
they are not executable application acceptance cases for this slice.

## Grammar and stage decisions

### One source root, distinct validation stages

Use one source-file grammar for ordinary modules, `build.transit` and test files.
File suffixes do not select semantics. Target kind and reachability retain their
current compiler checks: TEST reached from a build, nested TEST, ASSERT outside a
case and ordinary SQL directly in a test target remain compilation refusals.

Classify every fixture by the earliest required rejection layer:

| Layer | What it decides |
| --- | --- |
| Encoding/framing | Valid UTF-8, complete literals/comments/blocks and bounded source input |
| Source/template syntax | Complete imports/declarations/expressions and structurally valid admitted Table SQL and assertion rows; full input consumed |
| Graph/type/target checks | Name/interface resolution, operand types, target/case placement, supported runtime profile, schema binding and bounded evaluation |
| Native execution | Current authorization, constraint outcomes, durable acceptance and complete result observation; exercised only through existing real test owners |

Do not require ANTLR to duplicate name resolution, policy, quotas or Table
semantics. A syntactically valid program can fail the later layers. Conversely,
a lexer/parser recovery diagnostic cannot be reported as successful parsing.
Reference grammar acceptance alone never enables a runtime form.

### Lexical and expression profile

Write the exact rules before implementing the reference adapter. Preserve
case-insensitive ASCII source names, quoted SQL identifiers, doubled string
quotes, nested comments, inert holes inside strings/comments/quoted identifiers,
optional empty top-level statements and the current declaration/body terminators.
Source names and SQL identifiers have different admissible forms; adding source
keywords must not accidentally reserve previously valid SQL names.

The observed compile-time precedence, from tightest to loosest, is unary minus
and NOT; multiplication; addition/subtraction; comparisons; AND; OR. Binary
operators associate left. This is the source evaluator's grammar, not a claim
about SQL expression precedence. Cover parenthesized expressions, chained
comparisons that later fail typing, signed-int64 extrema and checked overflow.
The current evaluator evaluates both operands of AND/OR; this slice must not
silently introduce short-circuiting or change observable evaluation failures.

Record discrepancies between the written contract, parser and intended grammar
in a reviewed corpus matrix. Fix documented parser defects with explicit negative
cases; do not normalize away disagreements or copy production output into the
expected results. Any intentional change to a valid program's interpretation
requires an explicit current-v1 contract decision and regression migration.

### Embedded SQL and typed holes

Reuse the SQL reference through ANTLR grammar imports and narrowly scoped source
rules for `CREATE PUBLIC TABLE`, identifier/type/value holes and test wrappers.
Keep the ordinary SQL root unchanged. If shared productions must be factored,
make that mechanical change separately and run all dependent SQL grammar checks.
ANTLR imports can override rules and affect token precedence, so compare both
roots after composition; the [pinned upstream grammar-import rules](https://github.com/antlr/antlr4/blob/4.13.2/doc/grammars.md#grammar-imports)
describe that mechanism, not Transit correctness.

Fully parse the admitted CREATE TABLE, INSERT, UPDATE, DELETE and SELECT templates,
including SQL literals/types admitted by the existing Table owners. Do not narrow
raw Table types to the three compile-time TYPE-argument values. Keep source
`$name` operands distinct from runtime positional `$1` parameters; module operands
cannot enter SQL and type operands cannot become identifiers. Binding determines
a hole's kind and permitted position; the grammar must preserve its location.

No wildcard SQL body, regex replacement or arbitrary successful token bucket may
stand in for embedded SQL validation. The production side needs a bounded
syntax-only template check/representation using shared Fuze lexical/type-syntax
owners where possible; authoritative schema, value and plan validation remains
with `WorkingCatalog` and the ordinary statement owners after expansion. Do not
manufacture dummy database values or catalog bindings to make syntax checks pass.

Proposed explicit rule: structural syntax is checked in every source body,
including unused modules and unselected IF branches; name resolution, evaluation
and runtime capability admission retain their documented stage. The present
token-framing path can postpone malformed SQL until expansion. Closing that gap
is an intentional earlier refusal, must be documented and tested, and cannot
change the SQL emitted for previously valid supported programs. Unsupported SQL
outside the closed source profile remains a located refusal, including when
otherwise hidden in an unused body; record that compatibility consequence.

Assertion SQL is one statement without an internal terminator. Expected rows
have a complete row/literal grammar; schema binding, exact canonical typed bytes,
row multiplicity and terminal coverage remain owned by the existing test compiler
and runner. Parenthesis balancing alone is not assertion syntax validation.

## Independent comparison and round-trips

Place the new driver/adapter under `tests/query/application_source/`, with its
owner README. The Zig executable imports `transit_compiler` through the build
dependency, never sibling source files. It projects actual `Syntax.File`, graph
results and compiled products into bounded test records; it must not implement
another source parser or evaluator. Register it through the existing build checks
and fixture-module conventions.

The Python adapter derives its tree only from ANTLR and independent fixture
expectations. Compare declaration kind/visibility, ordered parameters, imports,
dependency values, names, expression structure, calls, branches, test setup,
assertion kind and exact counts/refusals, plus embedded template structure and
typed-hole sites. Preserve SQL literal/quoted-identifier bytes and use exact
integer representations; JSON floating-point conversion is not an oracle.

Source coordinates are zero-based UTF-8 byte offsets with exclusive ends and
one-based lines/byte columns. Convert ANTLR character offsets explicitly; cover
multibyte strings/comments, CRLF, doubled quotes and end-of-file errors. Compare
the specified failure location/category, not ANTLR's human error wording with
Transit's structured diagnostic message. Grammar/tool failures remain distinct
from expected program refusals.

Add a bounded source formatter over the production AST/template representation.
It may normalize keyword case/spacing and omit comments, but preserves source
literal values, embedded SQL literal/quoted-identifier bytes, bindings, statement
order and precedence with explicit parentheses.
Require source -> AST -> canonical source -> AST equality modulo source spans,
formatter idempotence and unchanged compiled SQL/ordered fingerprints/logical test
plans. Source digests, locations and source-derived case identities can change;
compare their documented derivation separately, retaining every case, setup,
action and expectation. Do not normalize away changes to runtime bindings or
outcomes.
Check definition/call-site attribution separately for each source version; a
formatting change is not permitted to change durable object bindings.

Generate a deterministic bounded set of nesting, expression and lexical variants
in addition to hand-authored fixtures. Retain seed/case identity on failure.
Corrupt expected ASTs, remove a case/result, alter a literal, swap precedence and
change a hole kind as harness negative controls. Each must fail for its intended
comparison, not a subprocess or parser-generation error. Do not claim exhaustive
grammar or compiler verification from this finite corpus.

## Typed-core contract delivered by this slice

Extend the existing source contract's compilation model and the
[compiler analysis](../handbook/internals/query-engine.md#planned-source-to-sql-compilation),
keeping implemented and proposed records separate. The current chain is source
AST -> resolved graph -> bounded typed evaluation -> ordered SQL/test products ->
independent SQL rebind. The comparison format is private test infrastructure,
not a new persisted public IR, native protocol or runtime authority.

Specify the extension obligations now, without adding placeholder runtime nodes:

| Core information | Contract obligation for subsequent slices |
| --- | --- |
| Object, definition and domain identity | Stable instance bindings independent of files/aliases; nominal IDs/revisions/evidence cannot be substituted merely because their physical scalars match |
| Types, cardinality and cell states | Explicit one/optional/many results; distinct NULL/missing/error/conflict; selected refinement validation and exhaustive variants; logical types remain separate from codecs/collations |
| Query/command/module interfaces | Checked input/output signatures and behavioral obligations; hygienic specialization cannot widen effects or grant access |
| Ordered guards and effects | Preserve refusal order, read/write dependencies, atomic boundaries, time/random inputs and disclosure; pure helpers cannot hide external effects |
| Capabilities and protected values | Explicit ownership/settlement and information-flow obligations; static witnesses cannot replace live policy or durable fencing |
| Transitions and observations | State before/after, original operation identity and exact observation basis; desired state, external evidence, progress and unknown outcomes remain distinct |
| Proof and execution basis | Name the property, abstraction, assumptions, bounds and artifact identities; separate checked syntax, checked types, executed outcomes, model results and proved theorems |

For each obligation, identify its future static check, owning runtime validation
or proof requirement and emitted-SQL representation. Missing information is
unsupported, not an empty effect set or presumed proof. Keep the current native
definition, lock/cache formats and recorded outcomes unchanged unless a concrete
incompatible contract change requires the current-v1 cutover; never add fallback
decoders or reinterpret old artifacts.

No new TLA+ theorem, Lean proof or temporal-model result is claimed in this slice.
Document the bridge: later transition/effect constructs supply explicit temporal
abstractions and native trace projections; later core/lowering transformations
supply selected Lean preservation obligations. Their first execution belongs
with those constructs, as M12 already requires, rather than waiting for M23.
This slice supplies the syntax and stage correspondence needed to state those
claims precisely. Existing formal suites remain regression owners if shared
semantics or tooling changes.

## Implementation sequence and logical commits

| Commit | Scope | Gate before continuing |
| --- | --- | --- |
| 1. Specify source syntax and core stages | Update the source contract, support/stage matrix, lexical/precedence rules, earlier-refusal decision and typed-core obligations. Author independent corpus expectations. | Every form has a syntax owner and a separate semantic/execution classification; all changes from observed behavior are explicit. |
| 2. Add the independent ANTLR grammar | Add the source root and SQL-template/assertion productions using the pinned tools; isolate any mechanical shared-grammar factoring. | Full-input strict parsing, warnings-as-errors and no reported corpus ambiguities; existing SQL and interface/UI grammar behavior preserved. |
| 3. Close production syntax gaps and expose comparison | Add bounded template syntax validation and a private Zig AST/product driver through the owning compiler package. Preserve compiler allocation/diagnostic ownership. | Independent AST/location agreement, early malformed-body refusal, unchanged valid output, wrong-stage rejection and allocation/budget cleanup. |
| 4. Add source round-trips and differential controls | Add the package formatter and independent Python comparison driver, deterministic variants and deliberately wrong oracle controls. | AST round-trips, formatter idempotence, byte-accurate locations and unchanged emitted SQL/test semantics; no missing or duplicate case can pass. |
| 5. Integrate tasks and qualify consumers | Register the source-grammar task, dependency selection, inventories and real build/test regressions. | Committed-HEAD affected clean lanes and required baseline/latency gates pass; installed callers need no ANTLR/Python verifier. |
| 6. Publish supported grammar coverage | Update public source/grammar/compiler references and qualification history; link evidence and remaining typed-language work. | Claims match executed scope; M12 stays In Progress and the broader synthetic workflows remain proposed. |

## Acceptance and validation

| Journey | Required evidence |
| --- | --- |
| Delivered source coverage | Every import/dependency/interface/module/target/expression/conditional/test/assertion production has independent positive and negative cases, including child and higher-order compositions |
| Embedded SQL and stage boundaries | Malformed templates/expected rows fail even in unused bodies; unsupported forms and `$1` remain refusals; valid syntax with bad names/types/target placement fails at the documented later layer; runtime SQL rejects source-only declarations |
| Grammar independence | Strict ANTLR parsing and real Zig ASTs agree with hand-authored expectations; exact corpus inventory and intended negative controls pass; no expected result is copied from the compiler |
| Deterministic round-trips | Canonical source parses identically, formats idempotently and compiles to equivalent ordered SQL/logical test products; source-derived provenance/case identities change only as documented, while bindings, literals, actions and expectations remain equivalent |
| Bounds and diagnostics | Existing 1 MiB/file, aggregate source, nesting, work, memory and SQL-output limits remain enforced; at/over-bound and allocation-failure cases produce no complete artifact; Unicode/CRLF coordinates remain correct |
| Consumer preservation | Existing real `transit build`/`transit test` fixtures retain SQL, typed results, command counts and refusals under frozen offline resolution; verification tooling is absent from the installed runtime dependency closure |

The delivered task is `just test::application-source-grammar`.
It builds the private Zig driver, generates ANTLR with the pinned SQL tools
and runs the independent adapter through `tests/runner/launch.py`. Generated
parsers and raw evidence stay in a unique ignored
`.cache/verification/application-source-grammar/` run directory. Bound subprocess
time/output and corpus expansion, record grammar/corpus/tool/binary/revision
identities, and fail on incomplete coverage. Measure verification cost separately
from ordinary compiler latency; do not raise production budgets to fit a proof.

Register the task in `tasks/test.just`, `build/checks.zig`, the suite and affected
dependency-selection groups, diagnostic grammar inventory and invariant catalog.
Use the `storage-query` lane alongside `application-compiler`, with its pinned
tool prerequisite explicit. Keep fast checks limited to appropriate inventory
and driver controls; they do not execute the differential grammar proof.

Run the baseline for the implementation PR:

```sh
nix develop --command just check fast
nix develop .#docs --command just transit-docs::install
nix develop .#docs --command just transit-docs::check
```

Inside the pinned environment run the new source-grammar task, existing
`application-compiler`, `application-build`, `application-test`, `sql-grammar`
and `application-grammar` checks, and `just check contracts` for the affected
source/diagnostic contracts. Run `just test::sql` and affected DDL/DML proofs if
SQL grammar productions or shared parser owners change. These are planned gates,
not results of writing this plan.

Before pushing implementation/test-infrastructure changes, run affected
`just ci clean --lane NAME` checks against committed HEAD. Expect `storage-query`
for the compiler/new task and `installation-ui` for CLI consumer regressions.
Shared SQL reference changes also select `sdks-conformance`, which owns the SQL
reference/production proof; shared build registration can expand selection to
`core`. Follow the actual dependency graph and include `interfaces-sql` or other
lanes when their owners change. Do not infer lane ownership from task names.

Because the intended implementation changes source parsing on the CLI build/test
path, include `server-sql-types` and the required `console-latency-gate` in the
pinned `ci-experience` shell. Measure the gate without this task's own concurrent
heavy builds; leave unrelated user work untouched. Record contention/failure
truthfully rather than relaxing deadlines. Runtime SQL scalar or adapter changes
would additionally require the SQL interface validation loop and are outside the
intended scope.

The original planning PR required the documentation baseline only. The
implementation requires all affected gates above. Record actual implementation
evidence in the qualification ledger, not as a passing checkbox in this plan.

## Following slice

After syntax/core qualification, select the typed-target case for nominal
references, variants, exhaustive matching and typed resource exports. Add its
grammar, semantics, SQL lowering and a small preservation obligation together.
Then admit one-use continuation and capacity transitions as their ordinary
transaction/effect owners qualify, with TLA+ interleavings and native trace
replay. Full application compilation, effect simulation and migration synthesis
retain their separate M12 gates.
